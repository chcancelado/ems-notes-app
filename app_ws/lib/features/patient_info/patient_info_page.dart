import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
import '../../widgets/sidebar_layout.dart';
import '../../widgets/unsaved_changes_dialog.dart';

class PatientInfoPage extends StatefulWidget {
  const PatientInfoPage({super.key});

  @override
  State<PatientInfoPage> createState() => _PatientInfoPageState();
}

class _PatientInfoPageState extends State<PatientInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _chiefComplaintController =
      TextEditingController();
  final TextEditingController _medicalHistoryController =
      TextEditingController();

  final _repository = SupabaseSessionRepository();
  String? _sessionId;
  DateTime? _dateOfBirth;
  String _sex = 'U';
  bool _isSaving = false;
  bool _initialized = false;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isHydrating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _chiefComplaintController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final sessionId = args?['sessionId'] as String?;

    if (sessionId != null) {
      _sessionId = sessionId;
      _initializeFromSources(sessionId);
    } else {
      final latest = sessionService.latestSession;
      if (latest != null) {
        _sessionId = latest.id;
        _initializeFromSources(latest.id);
      }
    }
  }

  Future<void> _initializeFromSources(String sessionId) async {
    final session = sessionService.findSessionById(sessionId);
    if (session != null && session.patientInfo.isNotEmpty) {
      _applyPatientInfo(session.patientInfo);
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final remote = await _repository.fetchPatientInfo(sessionId);
      if (remote != null && remote.isNotEmpty) {
        _applyPatientInfo(remote);
        sessionService.updatePatientInfo(sessionId, remote);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load patient info: $error')),
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

  void _applyPatientInfo(Map<String, dynamic> patientInfo) {
    _isHydrating = true;
    setState(() {
      _nameController.text = (patientInfo['name'] as String?) ?? '';
      final dobString = patientInfo['date_of_birth'] as String?;
      if (dobString != null) {
        final parsed = DateTime.tryParse(dobString);
        if (parsed != null) {
          _dateOfBirth = parsed;
          _dobController.text =
              '${parsed.month}/${parsed.day}/${parsed.year}';
        }
      }
      _sex = (patientInfo['sex'] as String?) ?? 'U';
      final height = patientInfo['height_in_inches'];
      _heightController.text = height == null ? '' : '$height';
      final weight = patientInfo['weight_in_pounds'];
      _weightController.text = weight == null ? '' : '$weight';
      _allergiesController.text = (patientInfo['allergies'] as String?) ?? '';
      _medicationsController.text =
          (patientInfo['medications'] as String?) ?? '';
      _chiefComplaintController.text =
          (patientInfo['chief_complaint'] as String?) ?? '';
      _medicalHistoryController.text =
          (patientInfo['medical_history'] as String?) ?? '';
      _hasUnsavedChanges = false;
    });
    _isHydrating = false;
  }

  void _handleFieldChange() {
    if (_isHydrating) {
      return;
    }
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) {
      return true;
    }
    return showUnsavedChangesDialog(context);
  }

  Future<void> _pickDateOfBirth() async {
    final initialDate = _dateOfBirth ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text =
            '${picked.month}/${picked.day}/${picked.year}';
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active session. Start a session first.'),
        ),
      );
      return;
    }
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date of birth.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final height = int.tryParse(_heightController.text.trim()) ?? 0;
    final weight = int.tryParse(_weightController.text.trim()) ?? 0;

    try {
      final savedInfo = await _repository.upsertPatientInfo(
        sessionId: _sessionId!,
        name: _nameController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        sex: _sex,
        heightInInches: height,
        weightInPounds: weight,
        allergies: _allergiesController.text.trim(),
        medications: _medicationsController.text.trim(),
        medicalHistory: _medicalHistoryController.text.trim(),
        chiefComplaint: _chiefComplaintController.text.trim(),
      );

      sessionService.updatePatientInfo(_sessionId!, savedInfo);
      setState(() {
        _hasUnsavedChanges = false;
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/vitals',
        arguments: {'sessionId': _sessionId},
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save patient info: $error')),
        );
      }
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
    final theme = Theme.of(context);

    return SidebarLayout(
      title: 'Patient Information',
      activeDestination: SidebarDestination.newSession,
      onNavigateAway: _confirmLeave,
      onLogout: () async {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      },
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Patient Details',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                          ),
                          onChanged: (_) => _handleFieldChange(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter the patient\'s name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _pickDateOfBirth,
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: _dobController,
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth',
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              onChanged: (_) => _handleFieldChange(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Select the date of birth';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _sex,
                          decoration: const InputDecoration(
                            labelText: 'Sex',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('Male')),
                            DropdownMenuItem(value: 'F', child: Text('Female')),
                            DropdownMenuItem(value: 'O', child: Text('Other')),
                            DropdownMenuItem(value: 'U', child: Text('Unknown')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _sex = value;
                              if (!_isHydrating) {
                                _hasUnsavedChanges = true;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _heightController,
                                decoration: const InputDecoration(
                                  labelText: 'Height (inches)',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _handleFieldChange(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter height';
                                  }
                                  final parsed = int.tryParse(value);
                                  if (parsed == null || parsed <= 0) {
                                    return 'Enter a positive number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _weightController,
                                decoration: const InputDecoration(
                                  labelText: 'Weight (lbs)',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _handleFieldChange(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter weight';
                                  }
                                  final parsed = int.tryParse(value);
                                  if (parsed == null || parsed <= 0) {
                                    return 'Enter a positive number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _allergiesController,
                          decoration: const InputDecoration(
                            labelText: 'Allergies',
                            hintText: 'List known allergies',
                          ),
                          maxLines: 2,
                          onChanged: (_) => _handleFieldChange(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _medicationsController,
                          decoration: const InputDecoration(
                            labelText: 'Medications',
                            hintText: 'List current medications',
                          ),
                          maxLines: 2,
                          onChanged: (_) => _handleFieldChange(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _medicalHistoryController,
                          decoration: const InputDecoration(
                            labelText: 'Medical History',
                            hintText: 'Summarize relevant medical history',
                          ),
                          maxLines: 3,
                          onChanged: (_) => _handleFieldChange(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _chiefComplaintController,
                          decoration: const InputDecoration(
                            labelText: 'Chief Complaint',
                          ),
                          maxLines: 3,
                          onChanged: (_) => _handleFieldChange(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter the chief complaint';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveAndContinue,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Continue to Vitals'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
