import 'package:flutter/material.dart';
import '../../services/session_service.dart';

class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = sessionService.sessions;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
      ),
      body: sessions.isEmpty
          ? Center(
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Start a new session to begin documenting patient encounters',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 32.0),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/patient-info');
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
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final elapsed = session.elapsedTime;
                final hours = elapsed.inHours;
                final minutes = elapsed.inMinutes.remainder(60);
                
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
                    subtitle: Text(
                      'Started: ${_formatDateTime(session.startedAt)}\n'
                      'Duration: ${hours}h ${minutes}m',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/report',
                        arguments: session.id,
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (sessionDate.isAtSameMomentAs(today)) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (sessionDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
