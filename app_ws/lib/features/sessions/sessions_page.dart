import 'package:flutter/material.dart';
import '../../services/session_service.dart';

class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = sessionService.sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: sessions.isEmpty
            ? const Center(child: Text('No sessions yet'))
            : ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final s = sessions[index];
                  return Card(
                    child: ListTile(
                      title: Text(s.patientName.isEmpty ? 'Untitled' : s.patientName),
                      subtitle: Text('Started: ${s.startedAt}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pushNamed('/report', arguments: s.id);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
