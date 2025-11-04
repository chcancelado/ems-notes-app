import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/sidebar_layout.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return SidebarLayout(
      title: 'EMS Notes',
      activeDestination: SidebarDestination.home,
      onLogout: () async {
        await Supabase.instance.client.auth.signOut();
        navigator.pushReplacementNamed('/login');
      },
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.medical_services,
                size: 80.0,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 14.0),
              Text(
                'EMS Note Taking',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Select an option to continue',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32.0),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 700;
                  final cards = [
                    _buildActionCard(
                      context,
                      title: 'Start a New Session',
                      subtitle: 'Begin documenting a new patient encounter',
                      icon: Icons.add_circle_outline,
                      gradientColors: [
                        Colors.blue.shade400,
                        Colors.blue.shade600
                      ],
                      onTap: () {
                        Navigator.of(context).pushNamed('/sessions/new');
                      },
                    ),
                    _buildActionCard(
                      context,
                      title: 'View Session History',
                      subtitle: 'Access previous patient sessions and reports',
                      icon: Icons.history,
                      gradientColors: [
                        Colors.blueGrey.shade400,
                        Colors.blueGrey.shade600
                      ],
                      onTap: () {
                        Navigator.of(context).pushNamed('/sessions');
                      },
                    ),
                  ];

                  if (isNarrow) {
                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 18),
                        cards[1],
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 320, child: cards[0]),
                      const SizedBox(width: 20),
                      SizedBox(width: 320, child: cards[1]),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  icon,
                  size: 40.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
