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

  @override
  void initState() {
    super.initState();
    // Initialize the future immediately so the FutureBuilder always has a value.
    _reportFuture = _loadReport();

    // After the first frame, pick up any route arguments (session id) and refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _sessionId = args;
        // Reload report data now that we know the session id
        setState(() {
          _reportFuture = _loadReport();
        });
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  Future<ReportData> _loadReport() async {
    if (_sessionId != null) {
      final s = sessionService.findById(_sessionId!);
      if (s != null) {
        // Build a minimal PatientInfo from session data if available
        final pdata = (s.data['name'] != null && s.data['age'] != null && s.data['chiefComplaint'] != null)
            ? PatientInfo(
                name: s.data['name'] as String,
                age: s.data['age'] as int,
                chiefComplaint: s.data['chiefComplaint'] as String,
              )
            : null;

        final reportData = ReportData(patientInfo: pdata, vitalsHistory: const [], notes: null);
        // No remote notes to prefill for session-backed reports
        _notesController.text = '';
        _observationsController.text = '';
        return reportData;
      }
    }

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
}
