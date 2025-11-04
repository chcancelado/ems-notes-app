import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
import '../../widgets/sidebar_layout.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _repository = SupabaseSessionRepository();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
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

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return SidebarLayout(
      title: 'Session History',
      activeDestination: SidebarDestination.sessions,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Start a new session to begin documenting patient encounters',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Colors.grey[600],
                          ),
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

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final incident = session.incidentInfo;
                final incidentDate = DateTime.tryParse(
                  incident['incident_date'] as String? ?? '',
                );
                final incidentType = incident['type'] as String? ?? 'Incident';
                final subtitleText = [
                  if (incidentDate != null)
                    'Date: ${_formatDate(incidentDate)}',
                  'Type: $incidentType',
                ].join('\n');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        session.patientName.isNotEmpty
                            ? session.patientName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      session.patientName.isNotEmpty
                          ? session.patientName
                          : 'Unnamed Patient',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(subtitleText),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/report',
                        arguments: {'sessionId': session.id},
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
