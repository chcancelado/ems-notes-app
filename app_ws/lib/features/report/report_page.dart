import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../patient_info/patient_info_controller.dart';
import '../vitals/vitals_controller.dart';
import 'report_controller.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _controller = ReportController();
  late Future<ReportData> _reportFuture;
  final _notesController = TextEditingController();
  final _observationsController = TextEditingController();
  bool _isSaving = false;
  String? _sessionId;
  Session? _session;

  @override
  void initState() {
    super.initState();
    // Will load report after we get session ID from route args
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get session ID from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _sessionId != args) {
      _sessionId = args;
      _session = sessionService.findSessionById(_sessionId!);
      _reportFuture = _loadReport();
      
      // Load notes from session if available
      if (_session != null) {
        _notesController.text = _session!.notes;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  Future<ReportData> _loadReport() async {
    // If we have a session, use session data
    if (_session != null) {
      final patientInfo = _session!.patientInfo;
      PatientInfo? info;
      
      if (patientInfo.isNotEmpty) {
        info = PatientInfo(
          name: patientInfo['name'] as String? ?? '',
          age: patientInfo['age'] as int? ?? 0,
          chiefComplaint: patientInfo['chiefComplaint'] as String? ?? '',
          updatedAt: _session!.startedAt,
        );
      }

      // Get vitals from session
      final sessionVitals = _session!.vitals;
      final vitalsList = sessionVitals.map((v) {
        return Vitals(
          heartRate: v['heart_rate'] as int? ?? 0,
          bloodPressure: v['blood_pressure'] as String? ?? '',
          respiratoryRate: v['respiratory_rate'] as int? ?? 0,
          temperature: (v['temperature'] as num?)?.toDouble() ?? 0.0,
          timestamp: v['recorded_at'] != null 
              ? DateTime.tryParse(v['recorded_at'] as String) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();

      // Load notes from session
      _notesController.text = _session!.notes;

      return ReportData(
        patientInfo: info,
        vitalsHistory: vitalsList,
        notes: _session!.notes.isNotEmpty 
            ? ReportNotes(
                notes: _session!.notes,
                observations: '',
                updatedAt: DateTime.now(),
              )
            : null,
      );
    }

    // Fall back to loading from database if no session
    final data = await _controller.loadReport();
    _notesController.text = data.notes?.notes ?? '';
    _observationsController.text = data.notes?.observations ?? '';
    return data;
  }

  Future<void> _refresh() async {
    final data = await _controller.loadReport();
    if (!mounted) {
      return;
    }
    setState(() {
      _reportFuture = Future.value(data);
      _notesController.text = data.notes?.notes ?? '';
      _observationsController.text = data.notes?.observations ?? '';
    });
  }

  Future<void> _saveNotes() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Save to session if available
      if (_session != null) {
        _session!.setNotes(_notesController.text.trim());
      }

      // Also save to database
      await _controller.saveNotes(
        notes: _notesController.text.trim(),
        observations: _observationsController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report notes saved.')));

      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save notes: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final date = '${local.month}/${local.day}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMS Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report sharing is coming soon.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _reportFuture = _loadReport();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<ReportData>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load report data.'),
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _reportFuture = _loadReport();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No report data available yet.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session info card
                  if (_session != null) ...[
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.medical_services, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Session Report',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Session ID: ${_session!.id}'),
                            Text('Started: ${_formatTimestamp(_session!.startedAt)}'),
                            Text('Duration: ${_formatDuration(_session!.elapsedTime)}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Patient Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildPatientInfoCard(data.patientInfo),
                  const SizedBox(height: 16),
                  const Text(
                    'Vital Signs History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildVitalsHistory(data.vitalsHistory),
                  const SizedBox(height: 16),
                  if (_session != null && _session!.chart.isNotEmpty)
                    ...[
                      const Text(
                        'Medical Chart',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildChartData(_session!.chart),
                      const SizedBox(height: 16),
                    ],
                  const Text(
                    'Notes & Observations',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildNotesSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientInfoCard(PatientInfo? patientInfo) {
    if (patientInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No patient information has been saved yet.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${patientInfo.name}'),
            const SizedBox(height: 8),
            Text('Age: ${patientInfo.age}'),
            const SizedBox(height: 8),
            Text('Chief Complaint: ${patientInfo.chiefComplaint}'),
            const SizedBox(height: 8),
            Text('Last Updated: ${_formatTimestamp(patientInfo.updatedAt)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsHistory(List<Vitals> vitalsHistory) {
    if (vitalsHistory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No vitals have been recorded yet.'),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vitalsHistory.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final vitals = vitalsHistory[index];
          return ListTile(
            title: Text('HR: ${vitals.heartRate}, BP: ${vitals.bloodPressure}'),
            subtitle: Text(
              'RR: ${vitals.respiratoryRate}, Temp: ${vitals.temperature.toStringAsFixed(1)}°F',
            ),
            trailing: Text(_formatTimestamp(vitals.timestamp)),
          );
        },
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Narrative / Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observationsController,
              decoration: const InputDecoration(
                labelText: 'Observations',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveNotes,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving…' : 'Save Notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartData(Map<String, dynamic> chartData) {
    final allergies = chartData['allergies'] as String? ?? '';
    final medications = chartData['medications'] as String? ?? '';
    final familyHistory = chartData['familyHistory'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (allergies.isNotEmpty) ...[
              const Text(
                'Allergies',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(allergies),
              const SizedBox(height: 12),
            ],
            if (medications.isNotEmpty) ...[
              const Text(
                'Current Medications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(medications),
              const SizedBox(height: 12),
            ],
            if (familyHistory.isNotEmpty) ...[
              const Text(
                'Family History',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(familyHistory),
            ],
            if (allergies.isEmpty && medications.isEmpty && familyHistory.isEmpty)
              const Text(
                'No chart data recorded',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
