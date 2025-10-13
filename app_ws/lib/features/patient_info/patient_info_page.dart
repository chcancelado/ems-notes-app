import 'dart:async';

import 'package:flutter/material.dart';
import 'patient_info_controller.dart';
import '../../services/session_service.dart';

class PatientInfoPage extends StatefulWidget {
  const PatientInfoPage({super.key});

  @override
  State<PatientInfoPage> createState() => _PatientInfoPageState();
}

class _PatientInfoPageState extends State<PatientInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = PatientInfoController();
  String _name = '';
  String _age = '';
  String _chiefComplaint = '';
  bool _isSaving = false;
  Timer? _reminderTimer;
  Duration _timeLeft = const Duration(minutes: 5);
  bool _timerStarted = false;

  void _startReminderTimer() {
    if (_timerStarted) return;
    _timerStarted = true;
    _timeLeft = const Duration(minutes: 5);
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_timeLeft.inSeconds <= 1) {
          t.cancel();
          _showReminder();
        } else {
          _timeLeft = Duration(seconds: _timeLeft.inSeconds - 1);
        }
      });
    });
  }

  void _showReminder() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reminder'),
        content: const Text('Re-check patient vitals (5 minutes since session start).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePatientInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsedAge = int.tryParse(_age);
    if (parsedAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numeric age.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _controller.savePatientInfo(
        name: _name,
        age: parsedAge,
        chiefComplaint: _chiefComplaint,
      );

      // create an in-memory session and add to sessionService
      final sid = DateTime.now().millisecondsSinceEpoch.toString();
      sessionService.addSession(Session(id: sid, patientName: _name));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient information saved.')));

      // navigate to report for this session
      Navigator.of(context).pushReplacementNamed('/report', arguments: sid);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save patient info: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Information')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Patient Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (!_timerStarted) _startReminderTimer();
                  _name = value;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter patient name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (!_timerStarted) _startReminderTimer();
                  _age = value;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter age';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Age must be a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Chief Complaint',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  if (!_timerStarted) _startReminderTimer();
                  _chiefComplaint = value;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter chief complaint';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_timerStarted) ...[
                Text('Reminder in: ${_formatDuration(_timeLeft)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _savePatientInfo,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Patient Information'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }
}
