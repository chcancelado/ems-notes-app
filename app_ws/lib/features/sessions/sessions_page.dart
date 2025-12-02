import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
import '../../services/agency_service.dart';
import '../../widgets/first_aid_dialog.dart';
import '../../widgets/patient_summary_dialog.dart';
import '../../widgets/sidebar_layout.dart';
import '../../widgets/form_styles.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, this.showSharedOnly = false});

  final bool showSharedOnly;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _repository = SupabaseSessionRepository();
  bool _isLoading = false;
  String? _error;
  final Set<String> _deletingSessionIds = <String>{};
  bool _hasHandledSnackbar = false;
  static const List<int> _pageSizeOptions = [5, 10, 25, 100];
  int _rowsPerPage = 10;
  int _pageIndex = 0;
  String? _currentUserId;
  List<AgencyMember> _agencyMembers = const [];
  late bool _showSharedOnly;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _showSharedOnly = widget.showSharedOnly;
    _loadSessions();
    _loadAgencyMembers();
  }

  String _memberNameFor(String? userId) {
    if (userId == null) return '';
    final member = _agencyMembers.firstWhere(
      (m) => m.userId == userId,
      orElse: () => AgencyMember(userId: userId, email: ''),
    );
    final nameParts = [
      if ((member.firstName ?? '').isNotEmpty) member.firstName,
      if ((member.lastName ?? '').isNotEmpty) member.lastName,
    ].whereType<String>().toList();
    return nameParts.isEmpty ? member.email : nameParts.join(' ');
  }

  Future<void> _loadAgencyMembers() async {
    try {
      final members = await _repository.fetchAgencyMembers();
      if (mounted) {
        setState(() {
          _agencyMembers = members;
        });
      }
    } catch (_) {
      // Ignore failures here; sharing UI will handle errors when invoked.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showSharedOnly = widget.showSharedOnly;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final message = args?['snackbarMessage'] as String?;
    if (args?['sharedOnly'] is bool) {
      _showSharedOnly = args!['sharedOnly'] as bool;
    }
    if (message != null && !_hasHandledSnackbar) {
      _hasHandledSnackbar = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = await _repository.fetchSessions();
      sessionService.replaceSessions(sessions);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadSessions();
  }

  Future<void> _editIncident(Session session) async {
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      '/sessions/new',
      arguments: {
        'sessionId': session.id,
        'isEditing': true,
        'fromSharedSessions': _showSharedOnly,
      },
    );
  }

  Future<void> _editPatient(Session session) async {
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      '/patient-info',
      arguments: {
        'sessionId': session.id,
        'isEditing': true,
        'fromSharedSessions': _showSharedOnly,
      },
    );
  }

  Future<void> _addVitals(Session session) async {
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      '/vitals',
      arguments: {
        'sessionId': session.id,
        'isEditing': true,
        'fromSharedSessions': _showSharedOnly,
      },
    );
  }

  Future<void> _shareSession(Session session) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_currentUserId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You must be logged in to share.')),
      );
      return;
    }
    final alreadyShared = await _repository.fetchSharedWith(session.id);
    if (!mounted) return;
    if (_agencyMembers.isEmpty) {
      await _loadAgencyMembers();
    }
    final members = _agencyMembers
        .where((m) => m.userId != _currentUserId)
        .toList();
    if (members.isEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('No other agency members to share with.')),
      );
      return;
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Share Session'),
          content: SizedBox(
            width: 320,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final isAlreadyShared = alreadyShared.any(
                  (shared) => shared.userId == member.userId,
                );
                final nameParts = [
                  if ((member.firstName ?? '').isNotEmpty) member.firstName,
                  if ((member.lastName ?? '').isNotEmpty) member.lastName,
                ].whereType<String>().toList();
                final displayName = nameParts.isEmpty
                    ? member.email
                    : nameParts.join(' ');
                return ListTile(
                  leading: const Icon(Icons.person_add_alt),
                  title: Text(
                    isAlreadyShared
                        ? displayName
                        : displayName,
                    style: isAlreadyShared
                        ? TextStyle(color: Colors.grey.shade600)
                        : null,
                  ),
                  subtitle: isAlreadyShared ? const Text('(already shared)') : null,
                  enabled: !isAlreadyShared,
                  onTap: isAlreadyShared
                      ? null
                      : () async {
                          Navigator.of(dialogContext).pop();
                          try {
                            await _repository.shareSession(
                              sessionId: session.id,
                              shareWithUserId: member.userId,
                            );
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Shared with ${member.email}'),
                                ),
                              );
                            }
                          } catch (error) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to share: $error'),
                                ),
                              );
                            }
                          }
                        },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSharedWith(Session session) async {
    try {
      final shared = await _repository.fetchSharedWith(session.id);
      final creatorName = _memberNameFor(session.ownerId).isNotEmpty
          ? _memberNameFor(session.ownerId)
          : session.ownerId;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Shared With'),
            content: SizedBox(
              width: 320,
              child: shared.isEmpty
                  ? const Text('This session is not shared.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Creator: $creatorName${session.ownerId == _currentUserId ? ' (me)' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        const Text('Shared with:'),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: shared.length,
                            itemBuilder: (context, index) {
                              final member = shared[index];
                              final names = [
                                if ((member.firstName ?? '').isNotEmpty)
                                  member.firstName,
                                if ((member.lastName ?? '').isNotEmpty)
                                  member.lastName,
                              ].whereType<String>().toList();
                              final baseName = names.isEmpty
                                  ? member.email
                              : names.join(' ');
                          final meLabel = member.userId == _currentUserId
                              ? ' (me)'
                              : '';
                          final display = '$baseName$meLabel';
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.person),
                            title: Text(display),
                          );
                        },
                      ),
                    ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load shares: $error')));
    }
  }

  Future<void> _showFirstAid(Session session) async {
    final incidentType = (session.incidentInfo['type'] as String?) ?? '';
    if (incidentType.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an incident type before viewing first aid.'),
        ),
      );
      return;
    }
    await showFirstAidDialog(context, incidentType);
  }

  Future<void> _showSummary(Session session) async {
    Session? latest = sessionService.findSessionById(session.id) ?? session;
    try {
      final existingVitals = latest.vitals;
      if (existingVitals.isEmpty) {
        final fetched = await _repository.fetchVitals(session.id);
        sessionService.replaceVitals(session.id, fetched);
        latest = sessionService.findSessionById(session.id) ?? latest;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load vitals for summary: $error')),
        );
      }
    }
    if (!mounted) return;
    await showPatientSummaryDialog(context, session: latest);
  }

  Future<void> _deleteSession(Session session) async {
    if (_deletingSessionIds.contains(session.id)) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Session'),
              content: const Text(
                'Are you sure you want to delete this session? '
                'This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _deletingSessionIds.add(session.id);
    });

    try {
      await _repository.deleteSession(session.id);
      sessionService.removeSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete session: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingSessionIds.remove(session.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return SidebarLayout(
      title: _showSharedOnly ? 'Shared With Me' : 'My Sessions',
      activeDestination: _showSharedOnly
          ? SidebarDestination.sharedSessions
          : SidebarDestination.sessions,
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      onLogout: () async {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        navigator.pushReplacementNamed('/login');
      },
      body: StreamBuilder<List<Session>>(
        stream: sessionService.sessionsStream,
        initialData: sessionService.sessions,
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <Session>[];
          final ownSessions = sessions.where((s) => !s.sharedWithMe).toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
          final sharedSessions = sessions.where((s) => s.sharedWithMe).toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
          final totalSessions = _showSharedOnly
              ? sharedSessions.length
              : ownSessions.length;
          final totalPages = totalSessions == 0
              ? 1
              : ((totalSessions - 1) ~/ _rowsPerPage) + 1;
          final int clampedPageIndex = _pageIndex < 0
              ? 0
              : _pageIndex >= totalPages
              ? totalPages - 1
              : _pageIndex;
          final int startIndex = totalSessions == 0
              ? 0
              : clampedPageIndex * _rowsPerPage;
          final int endIndex = totalSessions == 0
              ? 0
              : (startIndex + _rowsPerPage > totalSessions
                    ? totalSessions
                    : startIndex + _rowsPerPage);
          final visibleSessions = totalSessions == 0
              ? <Session>[]
              : (_showSharedOnly
                    ? sharedSessions.sublist(startIndex, endIndex)
                    : ownSessions.sublist(startIndex, endIndex));

          if (_isLoading && sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null && sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load sessions:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 80.0,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'No Sessions Yet',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Start a new session to begin documenting patient encounters',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32.0),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/sessions/new');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Start New Session'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 16.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final theme = Theme.of(context);
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: visibleSessions.length,
                    itemBuilder: (context, index) {
                      final session = visibleSessions[index];
                      final incident = session.incidentInfo;
                      final address = (incident['address'] as String? ?? '')
                          .trim();
                      final incidentType = (incident['type'] as String? ?? '')
                          .trim();
                      final displayAddress = address.isEmpty
                          ? 'No Address Entered'
                          : address;
                      final isShared =
                          session.sharedWithMe &&
                          (_currentUserId != null &&
                              session.ownerId != _currentUserId);
                      final addressLine = isShared ? displayAddress : displayAddress;
                      final displayName = session.patientName.isNotEmpty
                          ? session.patientName
                          : 'No Patient Name Entered';
                      final isDeleting = _deletingSessionIds.contains(
                        session.id,
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Session Information
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    addressLine,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (incidentType.isNotEmpty)
                                    Text(
                                      incidentType,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayName,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDateTime(session.startedAt),
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Action Buttons Row
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: ElevatedButton.icon(
                                        style: FormStyles.firstAidElevatedButton()
                                            .copyWith(
                                          minimumSize: const WidgetStatePropertyAll(
                                            Size(0, 44),
                                          ),
                                          padding: const WidgetStatePropertyAll(
                                            EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                          ),
                                        ),
                                        onPressed: isDeleting
                                            ? null
                                            : () => _showFirstAid(session),
                                        icon: const Icon(
                                          Icons.health_and_safety,
                                          size: 20,
                                        ),
                                        label: const Text(
                                          'First Aid',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: OutlinedButton.icon(
                                        style: FormStyles.firstAidOutlinedButton()
                                            .copyWith(
                                          minimumSize: const WidgetStatePropertyAll(
                                            Size(0, 44),
                                          ),
                                          padding: const WidgetStatePropertyAll(
                                            EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                          ),
                                        ),
                                        onPressed: isDeleting
                                            ? null
                                            : () => _showSummary(session),
                                        icon: const Icon(
                                          Icons.receipt_long,
                                          size: 20,
                                        ),
                                        label: const Text('Summary'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          minimumSize: const Size(0, 44),
                                          backgroundColor: theme.colorScheme.surface,
                                          foregroundColor: theme.colorScheme.onSurface,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ),
                                        onPressed: isDeleting
                                            ? null
                                            : () => _addVitals(session),
                                        icon: const Icon(
                                          Icons.monitor_heart,
                                          size: 20,
                                        ),
                                        label: const Text(
                                          'Add Vitals',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: isDeleting
                                        ? const Center(
                                            child: SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : PopupMenuButton<String>(
                                            tooltip: 'More actions',
                                            padding: EdgeInsets.zero,
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'editIncident':
                                                  _editIncident(session);
                                                  break;
                                                case 'editPatient':
                                                  _editPatient(session);
                                                  break;
                                                case 'share':
                                                  _shareSession(session);
                                                  break;
                                                case 'sharedWith':
                                                  _showSharedWith(session);
                                                  break;
                                                case 'delete':
                                                  _deleteSession(session);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'editIncident',
                                            child: ListTile(
                                              leading: Icon(Icons.edit_note),
                                              title: Text(
                                                'Edit Incident Information',
                                              ),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'editPatient',
                                            child: ListTile(
                                              leading: Icon(Icons.healing),
                                              title: Text(
                                                'Edit Patient Information',
                                              ),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'share',
                                            child: ListTile(
                                              leading: Icon(Icons.share),
                                              title: Text('Share Session'),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'sharedWith',
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.visibility_outlined,
                                              ),
                                              title: Text('View Shared With'),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: ListTile(
                                              leading: Icon(Icons.delete),
                                              title: Text('Delete Session'),
                                            ),
                                          ),
                                        ],
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.more_vert),
                                          ),
                                        ),
                                      ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    const Text('Rows per page:'),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: DropdownButton<int>(
                          value: _rowsPerPage,
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: theme.colorScheme.surface,
                          focusColor: Colors.transparent,
                          iconEnabledColor: theme.colorScheme.primary,
                          iconDisabledColor: theme.colorScheme.primary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          items: _pageSizeOptions
                              .map(
                                (size) => DropdownMenuItem(
                                  value: size,
                                  child: Text('$size'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _rowsPerPage = value;
                              _pageIndex = 0;
                            });
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      totalSessions == 0
                          ? 'Showing 0 of 0'
                          : 'Showing ${startIndex + 1}-$endIndex of $totalSessions',
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: clampedPageIndex > 0
                          ? () {
                              setState(() {
                                _pageIndex = clampedPageIndex - 1;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed: clampedPageIndex < totalPages - 1
                          ? () {
                              setState(() {
                                _pageIndex = clampedPageIndex + 1;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
