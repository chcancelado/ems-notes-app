import 'package:flutter/material.dart';

import '../services/agency_service.dart';

enum SidebarDestination {
  home,
  newSession,
  sessions,
  sharedSessions,
  agency,
  account,
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
        setState(() {
          _greetingName = member?.firstName;
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
    if (destination == widget.activeDestination) {
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
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
      Navigator.of(context).pop();
    }
    Navigator.of(context).pushReplacementNamed(_routeFor(destination));
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final canLeave = await _canLeave();
        return canLeave;
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
                      final canLeave = await _canLeave();
                      if (!canLeave) return;
                      if (!mounted) return;
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).maybePop();
                      } else {
                        Navigator.of(context).pushReplacementNamed('/home');
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
                ? SafeArea(child: widget.body)
                : Row(
                    children: [
                      Container(
                        width: 260,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.3),
                        child: SafeArea(child: sidebar),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: SafeArea(child: widget.body)),
                    ],
                  ),
            floatingActionButton: widget.floatingActionButton,
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    if (widget.onLogout == null) return;
    final canLeave = await _canLeave();
    if (!canLeave) return;
    if (!mounted) return;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
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
  });

  final SidebarDestination active;
  final ValueChanged<SidebarDestination> onSelected;
  final Future<void> Function()? onLogout;
  final String newSessionLabel;
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (greeting != null && greeting!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Hello, $greeting',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
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
      _NavTile(
        icon: Icons.person,
        label: 'My Account',
        selected: active == SidebarDestination.account,
        onTap: () => onSelected(SidebarDestination.account),
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

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      children: menuItems,
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
