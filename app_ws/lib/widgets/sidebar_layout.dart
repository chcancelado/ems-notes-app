import 'package:flutter/material.dart';

import '../features/chatbot/chatbot_page.dart';
import '../services/agency_service.dart';

enum SidebarDestination {
  home,
  newSession,
  sessions,
  sharedSessions,
  agency,
  account,
  chatbot,
}

class SidebarLayout extends StatefulWidget {
  const SidebarLayout({
    super.key,
    required this.title,
    required this.body,
    required this.activeDestination,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = false,
    this.onNavigateAway,
    this.onBackRequested,
    this.onLogout,
    this.sessionNavLabel,
  });

  final String title;
  final Widget body;
  final SidebarDestination activeDestination;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final Future<bool> Function()? onNavigateAway;
  final Future<bool> Function()? onBackRequested;
  final Future<void> Function()? onLogout;
  final String? sessionNavLabel;

  @override
  State<SidebarLayout> createState() => _SidebarLayoutState();
}

class _SidebarLayoutState extends State<SidebarLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _greetingName;

  @override
  void initState() {
    super.initState();
    _loadGreeting();
  }

  Future<void> _loadGreeting() async {
    try {
      final member = await AgencyService().fetchCurrentMember();
      if (mounted) {
        final first = member?.firstName?.trim() ?? '';
        final last = member?.lastName?.trim() ?? '';
        final nameParts = [if (first.isNotEmpty) first, if (last.isNotEmpty) last];
        setState(() {
          _greetingName = nameParts.isNotEmpty ? nameParts.join(' ') : member?.email;
        });
      }
    } catch (_) {
      // ignore greeting failures
    }
  }

  Future<bool> _canLeave() async {
    if (widget.onBackRequested != null) {
      return await widget.onBackRequested!();
    }
    if (widget.onNavigateAway != null) {
      return await widget.onNavigateAway!();
    }
    return true;
  }

  Future<void> _handleDestinationTap(SidebarDestination destination) async {
    final navigator = Navigator.of(context);
    if (destination == widget.activeDestination) {
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        navigator.pop();
      }
      return;
    }
    if (widget.onNavigateAway != null) {
      final canLeave = await widget.onNavigateAway!();
      if (!canLeave) {
        return;
      }
    }
    if (!mounted) return;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      navigator.pop();
    }
    navigator.pushReplacementNamed(_routeFor(destination));
  }

  Future<void> _handleHelpTap() async {
    final navigator = Navigator.of(context);
    final canLeave = await _canLeave();
    if (!canLeave || !mounted) return;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      navigator.pop();
    }
    navigator.pushReplacementNamed('/help');
  }

  Widget _footerBar(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: _handleHelpTap,
          icon: const Icon(Icons.help_outline),
          label: const Text('Help'),
        ),
      ),
    );
  }

  String _routeFor(SidebarDestination destination) {
    switch (destination) {
      case SidebarDestination.home:
        return '/home';
      case SidebarDestination.newSession:
        return '/sessions/new';
      case SidebarDestination.sessions:
        return '/sessions';
      case SidebarDestination.sharedSessions:
        return '/sessions/shared';
      case SidebarDestination.agency:
        return '/agency';
      case SidebarDestination.account:
        return '/account';
      case SidebarDestination.chatbot:
        return '/chatbot';
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canLeave = await _canLeave();
        if (canLeave && mounted) {
          navigator.maybePop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool useDrawer = constraints.maxWidth < 900;
          final navLabel = widget.sessionNavLabel ?? 'Start New Session';
          final sidebar = _SidebarNavigation(
            active: widget.activeDestination,
            onSelected: _handleDestinationTap,
            onLogout: widget.onLogout != null ? _handleLogout : null,
            newSessionLabel: navLabel,
            greeting: _greetingName,
            onProfileTap: () => _handleDestinationTap(SidebarDestination.account),
          );

          final theme = Theme.of(context);
          List<Widget>? actions = widget.actions;
          if (useDrawer && widget.showBackButton) {
            actions = [
              ...(actions ?? []),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ];
          }

          final foregroundColor =
              theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
          final appBar = AppBar(
            toolbarHeight: 88,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: Text(
              widget.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            actions: actions,
            leading: widget.showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final canLeave = await _canLeave();
                      if (!canLeave) return;
                      if (!mounted) return;
                      if (navigator.canPop()) {
                        navigator.maybePop();
                      } else {
                        navigator.pushReplacementNamed('/home');
                      }
                    },
                  )
                : useDrawer
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  )
                : null,
          );

          return Scaffold(
            key: _scaffoldKey,
            appBar: appBar,
            drawer: useDrawer ? Drawer(child: SafeArea(child: sidebar)) : null,
            body: useDrawer
                ? SafeArea(
                    child: _BodyWithFooter(
                      body: widget.body,
                      footerBuilder: _footerBar,
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 260,
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: SafeArea(child: sidebar),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: SafeArea(
                          child: _BodyWithFooter(
                            body: widget.body,
                            footerBuilder: _footerBar,
                          ),
                        ),
                      ),
                    ],
                  ),
            floatingActionButton: widget.activeDestination != SidebarDestination.chatbot
                ? FloatingActionButton(
                    onPressed: () => ChatbotDialog.show(context),
                    tooltip: 'AI Assistant',
                    child: const Icon(Icons.smart_toy),
                  )
                : null,
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    if (widget.onLogout == null) return;
    final navigator = Navigator.of(context);
    final canLeave = await _canLeave();
    if (!canLeave) return;
    if (!mounted) return;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      navigator.pop();
    }
    await widget.onLogout!();
  }
}

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    required this.active,
    required this.onSelected,
    this.onLogout,
    required this.newSessionLabel,
    this.greeting,
    this.onProfileTap,
  });

  final SidebarDestination active;
  final ValueChanged<SidebarDestination> onSelected;
  final Future<void> Function()? onLogout;
  final String newSessionLabel;
  final String? greeting;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavTile(
        icon: Icons.home_outlined,
        label: 'Home',
        selected: active == SidebarDestination.home,
        onTap: () => onSelected(SidebarDestination.home),
      ),
      _NavTile(
        icon: Icons.add_circle_outline,
        label: newSessionLabel,
        selected: active == SidebarDestination.newSession,
        onTap: () => onSelected(SidebarDestination.newSession),
      ),
      _NavTile(
        icon: Icons.history,
        label: 'My Sessions',
        selected: active == SidebarDestination.sessions,
        onTap: () => onSelected(SidebarDestination.sessions),
      ),
      _NavTile(
        icon: Icons.share,
        label: 'Shared With Me',
        selected: active == SidebarDestination.sharedSessions,
        onTap: () => onSelected(SidebarDestination.sharedSessions),
      ),
      _NavTile(
        icon: Icons.group,
        label: 'My Agency',
        selected: active == SidebarDestination.agency,
        onTap: () => onSelected(SidebarDestination.agency),
      ),
    ];

    final List<Widget> menuItems = [
      ...items,
      if (onLogout != null)
        _NavTile(
          icon: Icons.logout,
          label: 'Log Out',
          selected: false,
          onTap: () => onLogout?.call(),
        ),
    ];

    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
            children: menuItems,
          ),
        ),
        if (greeting != null && greeting!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onProfileTap,
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary
                            .withValues(alpha: 0.1),
                        child: Icon(
                          Icons.person_outline,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          greeting!,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BodyWithFooter extends StatelessWidget {
  const _BodyWithFooter({
    required this.body,
    required this.footerBuilder,
  });

  final Widget body;
  final Widget Function(BuildContext) footerBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: body),
        footerBuilder(context),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
