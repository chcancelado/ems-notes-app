import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMS Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Supabase.instance.client.auth.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('Start a New Session', style: TextStyle(fontSize: 18)),
              ),
              onPressed: () => Navigator.of(context).pushNamed('/patient-info'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.history, size: 24),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('View Session History', style: TextStyle(fontSize: 18)),
              ),
              onPressed: () => Navigator.of(context).pushNamed('/sessions'),
            ),
            const Spacer(),
            Center(child: Text('Quick actions and recent sessions appear here', style: Theme.of(context).textTheme.bodyLarge)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
