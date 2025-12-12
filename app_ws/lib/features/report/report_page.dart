import 'package:flutter/material.dart';

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _notesController = TextEditingController();
  final _repository = SupabaseSessionRepository();

  Session? _session;
  String? _sessionId;
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final sessionId = args?['sessionId'] as String? ??
        ModalRoute.of(context)?.settings.arguments as String?;

    if (sessionId != null && sessionId != _sessionId) {
      _sessionId = sessionId;
      _loadSession(sessionId);
    } else if (_sessionId == null) {
      final latest = sessionService.latestSession;
      if (latest != null) {
        _sessionId = latest.id;
        _loadSession(latest.id);
      }
    }
  }

  Future<void> _loadSession(String id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final session = await _repository.fetchSessionDetail(id);
      if (session != null) {
        sessionService.upsertSession(session);
        setState(() {
          _session = session;
          _notesController.text = session.notes;
        });
      } else {
        setState(() {
          _session = null;
          _notesController.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load session: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _saveNotes() {
    final session = _session;
    if (session == null) return;
    session.setNotes(_notesController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes updated for this session.')),
    );
    final destination =
        session.sharedWithMe ? '/sessions/shared' : '/sessions';
    Navigator.of(context).pushNamedAndRemoveUntil(
      destination,
      (route) => route.isFirst,
      arguments: session.sharedWithMe ? {'sharedOnly': true} : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Summary'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : session == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child:
                        Text('Select a session from history to view its report.'),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        title: 'Incident Information',
                        child: _buildIncidentSummary(session),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Patient Information',
                        child: _buildPatientSummary(session),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Vitals',
                        child: _buildVitalsSummary(session),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Notes',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _notesController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText:
                                    'Enter narrative notes for this session',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _saveNotes,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Notes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildIncidentSummary(Session session) {
    final incident = session.incidentInfo;
    if (incident.isEmpty) {
      return const Text('No incident information recorded.');
    }

    final arrivalAt = incident['arrival_at'] as String?;
    final arrival = arrivalAt == null
        ? null
        : DateTime.tryParse(arrivalAt)?.toLocal();
    final incidentDate = DateTime.tryParse(
      incident['incident_date'] as String? ?? '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow('Date', _formatDate(incidentDate)),
        _summaryRow('Arrival Time', _formatTime(arrival)),
        _summaryRow('Address', incident['address'] as String? ?? ''),
        _summaryRow('Type', incident['type'] as String? ?? ''),
      ],
    );
  }

  Widget _buildPatientSummary(Session session) {
    final info = session.patientInfo;
    if (info.isEmpty) {
      return const Text('Patient information has not been entered yet.');
    }

    final dob = DateTime.tryParse(info['date_of_birth'] as String? ?? '');
    final height = info['height_in_inches'];
    final weight = info['weight_in_pounds'];
    final history = (info['medical_history'] as String?) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow('Name', info['name'] as String? ?? ''),
        _summaryRow('Date of Birth', _formatDate(dob)),
        _summaryRow('Sex', _describeSex(info['sex'] as String?)),
        _summaryRow('Height', height != null ? '$height in' : ''),
        _summaryRow('Weight', weight != null ? '$weight lbs' : ''),
        _summaryRow('Allergies', info['allergies'] as String? ?? ''),
        _summaryRow('Medications', info['medications'] as String? ?? ''),
        _summaryRow('Chief Complaint', info['chief_complaint'] as String? ?? ''),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Medical History',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(history),
        ],
      ],
    );
  }

  Widget _buildVitalsSummary(Session session) {
    final vitals = session.vitals;
    if (vitals.isEmpty) {
      return const Text('No vitals recorded for this session.');
    }

    return Column(
      children: vitals.map((entry) {
        final recordedAt = entry['recorded_at'] as String?;
        final recorded = recordedAt == null
            ? null
            : DateTime.tryParse(recordedAt)?.toLocal();
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              'Pulse ${entry['pulse_rate']} | Resp ${entry['breathing_rate']} | '
              'BP ${entry['blood_pressure_systolic']}/${entry['blood_pressure_diastolic']}',
            ),
            subtitle: Text(
              [
                if (entry['spo2'] != null) 'SpO2 ${entry['spo2']}%',
                if (entry['blood_glucose'] != null)
                  'Glucose ${entry['blood_glucose']}',
                if (entry['temperature'] != null)
                  'Temp ${entry['temperature']} F',
                if ((entry['notes'] as String?)?.isNotEmpty ?? false)
                  'Notes: ${entry['notes']}',
                _formatDateTime(recorded),
              ].where((part) => part.isNotEmpty).join('\n'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _summaryRow(String label, String value) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final time = TimeOfDay.fromDateTime(dateTime);
    return time.format(context);
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final date = _formatDate(dateTime);
    final time = _formatTime(dateTime);
    return '$date at $time';
  }

  String _describeSex(String? code) {
    switch (code) {
      case 'M':
        return 'Male';
      case 'F':
        return 'Female';
      case 'O':
        return 'Other';
      case 'U':
      default:
        return 'Unknown';
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
