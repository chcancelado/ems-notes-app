import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import 'patient_info_controller.dart';

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
  bool _isEnding = false;
  
  // Session and timer management
  String? _sessionId;
  Timer? _reminderTimer;
  Duration _timeRemaining = const Duration(minutes: 5);
  bool _timerStarted = false;
  bool _reminderShown = false;

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_timerStarted) return;
    
    setState(() {
      _timerStarted = true;
      _timeRemaining = const Duration(minutes: 5);
    });

    // Create a session when user starts entering patient info
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final session = Session(
      id: _sessionId!,
      patientName: _name.isNotEmpty ? _name : 'Unnamed Patient',
    );
    sessionService.addSession(session);

    // Start countdown timer
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_timeRemaining.inSeconds <= 0) {
          timer.cancel();
          if (!_reminderShown) {
            _showReminderDialog();
            _reminderShown = true;
          }
        } else {
          _timeRemaining = Duration(seconds: _timeRemaining.inSeconds - 1);
        }
      });
    });
  }

  void _showReminderDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reminder'),
        content: const Text(
          'It\'s time to check patient vitals!\n\n'
          '5 minutes have elapsed since session start.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(
                '/vitals',
                arguments: _sessionId,
              );
            },
            icon: const Icon(Icons.monitor_heart),
            label: const Text('Go to Vitals'),
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

      // Update session with patient info
      if (_sessionId != null) {
        final session = sessionService.findSessionById(_sessionId!);
        if (session != null) {
          session.setPatientInfo({
            'name': _name,
            'age': parsedAge,
            'chiefComplaint': _chiefComplaint,
          });
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient information saved.')),
      );
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

  Future<void> _endSession() async {
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
      _isEnding = true;
    });

    try {
      // Save patient info to database
      await _controller.savePatientInfo(
        name: _name,
        age: parsedAge,
        chiefComplaint: _chiefComplaint,
      );

      // Create or update session
      _sessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

      final session = sessionService.findSessionById(_sessionId!);
      if (session != null) {
        session.setPatientInfo({
          'name': _name,
          'age': parsedAge,
          'chiefComplaint': _chiefComplaint,
        });
      } else {
        final newSession = Session(
          id: _sessionId!,
          patientName: _name,
        );
        newSession.setPatientInfo({
          'name': _name,
          'age': parsedAge,
          'chiefComplaint': _chiefComplaint,
        });
        sessionService.addSession(newSession);
      }

      if (!mounted) return;

      // Navigate to report with session ID
      Navigator.of(context).pushReplacementNamed(
        '/report',
        arguments: _sessionId,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end session: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEnding = false;
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
              // Timer display
              if (_timerStarted)
                Card(
                  color: Colors.blue.shade50,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer,
                          color: _timeRemaining.inSeconds <= 60
                              ? Colors.red
                              : Colors.blue,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'Vitals reminder in: ${_formatDuration(_timeRemaining)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _timeRemaining.inSeconds <= 60
                                ? Colors.red
                                : Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Patient Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _name = value;
                  if (!_timerStarted) _startTimer();
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
                  _age = value;
                  if (!_timerStarted) _startTimer();
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
                  _chiefComplaint = value;
                  if (!_timerStarted) _startTimer();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter chief complaint';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_isSaving || _isEnding) ? null : _endSession,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.green,
                ),
                icon: _isEnding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isEnding ? 'Ending Session...' : 'End Session & View Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
