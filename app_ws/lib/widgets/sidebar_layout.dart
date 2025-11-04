import 'package:flutter/material.dart';

enum SidebarDestination { home, newSession, sessions }

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

  @override
  State<SidebarLayout> createState() => _SidebarLayoutState();
}

class _SidebarLayoutState extends State<SidebarLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
          final sidebar = _SidebarNavigation(
            active: widget.activeDestination,
            onSelected: _handleDestinationTap,
            onLogout: widget.onLogout != null ? _handleLogout : null,
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
                        Navigator.of(context)
                            .pushReplacementNamed('/home');
                      }
                    },
                  )
                : useDrawer
                    ? IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      )
                    : null,
          );

          return Scaffold(
            key: _scaffoldKey,
            appBar: appBar,
            drawer: useDrawer
                ? Drawer(
                    child: SafeArea(
                      child: sidebar,
                    ),
                  )
                : null,
            body: useDrawer
                ? SafeArea(child: widget.body)
                : Row(
                    children: [
                      Container(
                        width: 260,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.3),
                        child: SafeArea(
                          child: sidebar,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: SafeArea(
                          child: widget.body,
                        ),
                      ),
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
  });

  final SidebarDestination active;
  final ValueChanged<SidebarDestination> onSelected;
  final Future<void> Function()? onLogout;

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
        label: 'Start New Session',
        selected: active == SidebarDestination.newSession,
        onTap: () => onSelected(SidebarDestination.newSession),
      ),
      _NavTile(
        icon: Icons.history,
        label: 'Session History',
        selected: active == SidebarDestination.sessions,
        onTap: () => onSelected(SidebarDestination.sessions),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
