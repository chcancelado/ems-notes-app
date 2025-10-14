import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'patient_info_controller.dart';
import '../../services/session_service.dart';
import '../../config/app_config.dart';

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
  bool _timerStarted = false;
  bool _reminderShown = false;
  String? _sessionId;
  ValueListenable<Duration?>? _timeLeftListenable;
  VoidCallback? _timeListener;

  void _startReminderTimer() {
    if (_timerStarted) return;
    final createdAt = DateTime.now();
    final sid = _sessionId ?? createdAt.millisecondsSinceEpoch.toString();
    setState(() {
      _timerStarted = true;
      _reminderShown = false;
      _sessionId = sid;
    });

    final provisionalData = {
      'name': _name,
      'age': _age.isNotEmpty ? int.tryParse(_age) : null,
      'chiefComplaint': _chiefComplaint,
      'provisional': true,
    };

    final existing = sessionService.findById(sid);
    if (existing == null) {
      sessionService.addSession(Session(
        id: sid,
        patientName: _name.isNotEmpty ? _name : 'Unknown',
        data: provisionalData,
      ));
    } else {
      sessionService.updateSessionData(sid, provisionalData);
    }

    sessionService.setSessionTimer(sid, DateTime.now().toUtc().add(reminderDuration));
    _listenToSessionTimer(sid);
  }

  void _showReminder() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
  builder: (context) => AlertDialog(
  title: const Text('Reminder'),
  content: Text('Re-check patient vitals (${reminderDuration.inSeconds}s since session start).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _listenToSessionTimer(String sessionId) {
    if (_timeLeftListenable != null && _timeListener != null) {
      _timeLeftListenable!.removeListener(_timeListener!);
    }
    _timeLeftListenable = sessionService.watchSessionTimeLeft(sessionId);
    _timeListener = () {
      if (!mounted) return;
      final remaining = _timeLeftListenable?.value;
      if (!_reminderShown && remaining != null && remaining.inSeconds <= 0) {
        _reminderShown = true;
        _showReminder();
      }
      setState(() {});
    };
    _timeLeftListenable!.addListener(_timeListener!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timeListener?.call();
    });
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

      // create an in-memory session and add to sessionService (include patient info)
      final sid = _sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
      // update or create session with finalized patient info
      final existing = sessionService.findById(sid);
      if (existing != null) {
        sessionService.updateSessionData(sid, {
          'name': _name,
          'age': parsedAge,
          'chiefComplaint': _chiefComplaint,
          'provisional': false,
        });
      } else {
        sessionService.addSession(Session(
          id: sid,
          patientName: _name,
          data: {
            'name': _name,
            'age': parsedAge,
            'chiefComplaint': _chiefComplaint,
          },
        ));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient information saved.')));
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

  /// End the current session: validate, persist patient info, mark session finalized,
  /// and navigate to the report page for this session.
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
      // persist via controller
      await _controller.savePatientInfo(
        name: _name,
        age: parsedAge,
        chiefComplaint: _chiefComplaint,
      );

      // finalize or create session, then navigate to report
      final sid = _sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final existing = sessionService.findById(sid);
      if (existing != null) {
        sessionService.updateSessionData(sid, {
          'name': _name,
          'age': parsedAge,
          'chiefComplaint': _chiefComplaint,
          'provisional': false,
        });
      } else {
        sessionService.addSession(Session(
          id: sid,
          patientName: _name,
          data: {
            'name': _name,
            'age': parsedAge,
            'chiefComplaint': _chiefComplaint,
          },
        ));
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed('/report', arguments: sid);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to end session: $error')));
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
                Text(
                  'Reminder in: ${sessionService.formatDurationShort(_timeLeftListenable?.value)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                // show quick links (Vitals and Chart) while the timer is running
                if (_sessionId != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Record Vitals',
                        icon: const Icon(Icons.monitor_heart),
                        onPressed: () {
                          Navigator.of(context).pushNamed('/vitals', arguments: _sessionId);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Open Chart',
                        icon: const Icon(Icons.folder_shared),
                        onPressed: () {
                          Navigator.of(context).pushNamed('/chart', arguments: _sessionId);
                        },
                      ),
                    ],
                  ),
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
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isEnding ? null : _endSession,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isEnding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('End Session and View Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_timeLeftListenable != null && _timeListener != null) {
      _timeLeftListenable!.removeListener(_timeListener!);
    }
    _timeLeftListenable = null;
    _timeListener = null;
    super.dispose();
  }
}
