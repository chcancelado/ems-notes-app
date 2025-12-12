import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/agency_service.dart';
import '../../widgets/sidebar_layout.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _agencyService = AgencyService();
  AccountSummary? _account;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final summary = await _agencyService.fetchAccountSummary();
      if (mounted) {
        setState(() {
          _account = summary;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final oldPwd = oldController.text.trim();
                    final newPwd = newController.text.trim();
                    final confirmPwd = confirmController.text.trim();
                    if (oldPwd.isEmpty ||
                        newPwd.isEmpty ||
                        confirmPwd.isEmpty) {
                      setStateDialog(() {
                        errorText = 'Please fill in all fields';
                      });
                      return;
                    }
                    if (newPwd != confirmPwd) {
                      setStateDialog(() {
                        errorText = 'New passwords do not match';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final email = user?.email ?? _account?.email;
      if (email == null) {
        throw StateError('No email available for reauthentication.');
      }

      final oldPwd = oldController.text.trim();
      final newPwd = newController.text.trim();

      await client.auth.signInWithPassword(email: email, password: oldPwd);
      await client.auth.updateUser(UserAttributes(password: newPwd));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);

    return SidebarLayout(
      title: 'My Account',
      activeDestination: SidebarDestination.account,
      sessionNavLabel: 'Start New Session',
      onLogout: () async {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        navigator.pushReplacementNamed('/login');
      },
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _isLoading
                ? const CircularProgressIndicator()
                : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Failed to load account: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadAccount,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : _account == null
                ? const Text('No account data available.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_account!.firstName ?? ''} ${_account!.lastName ?? ''}'
                                .trim()
                                .isEmpty
                            ? 'No name on file'
                            : '${_account!.firstName ?? ''} ${_account!.lastName ?? ''}'
                                  .trim(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_account!.email, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Text(
                        'Agency: ${_account!.agencyCode ?? 'N/A'}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      if ((_account!.agencyName ?? '').isNotEmpty)
                        Text(
                          'Agency Name: ${_account!.agencyName}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _changePassword,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Change Password'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
