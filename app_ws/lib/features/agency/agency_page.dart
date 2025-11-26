import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/agency_service.dart';
import '../../widgets/sidebar_layout.dart';

class AgencyPage extends StatefulWidget {
  const AgencyPage({super.key});

  @override
  State<AgencyPage> createState() => _AgencyPageState();
}

class _AgencyPageState extends State<AgencyPage> {
  final _repository = AgencyService();
  late Future<List<AgencyMember>> _membersFuture;
  late Future<AccountSummary> _accountSummaryFuture;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _membersFuture = _repository.fetchMembers();
    _accountSummaryFuture = _repository.fetchAccountSummary();
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);
    return SidebarLayout(
      title: 'My Agency',
      activeDestination: SidebarDestination.agency,
      sessionNavLabel: 'Start New Session',
      onLogout: () async {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        navigator.pushReplacementNamed('/login');
      },
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<AccountSummary>(
                  future: _accountSummaryFuture,
                  builder: (context, snapshot) {
                    final agencyName = snapshot.data?.agencyName;
                    final displayName = (agencyName != null &&
                            agencyName.trim().isNotEmpty)
                        ? agencyName
                        : 'My Agency';
                    return Text(
                      displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Members',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<AgencyMember>>(
                  future: _membersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Failed to load members: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }
                    final members = snapshot.data ?? const <AgencyMember>[];
                    if (members.isEmpty) {
                      return const Text('No members found.');
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final isMe = member.userId == _currentUserId;
                        final nameParts = [
                          if ((member.firstName ?? '').isNotEmpty)
                            member.firstName,
                          if ((member.lastName ?? '').isNotEmpty)
                            member.lastName,
                        ].whereType<String>().toList();
                        final baseName = nameParts.isEmpty
                            ? member.email
                            : nameParts.join(' ');
                        final displayName = '$baseName${isMe ? ' (me)' : ''}';
                        final joinedText = member.joinedAt == null
                            ? null
                            : 'Joined: ${_formatDate(member.joinedAt!)}';
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(displayName),
                          subtitle: joinedText == null
                              ? null
                              : Text(
                                  joinedText,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[700]),
                                ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
