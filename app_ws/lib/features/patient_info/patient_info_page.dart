import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
import '../../widgets/app_input_decorations.dart';
import '../../widgets/first_aid_dialog.dart';
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
  final TextEditingController _heightFeetController = TextEditingController();
  final TextEditingController _heightInchesController = TextEditingController();
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

  String? get _incidentType {
    if (_sessionId == null) return null;
    final session = sessionService.findSessionById(_sessionId!);
    final type = session?.incidentInfo['type'];
    if (type is String && type.isNotEmpty) {
      return type;
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
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
      final dynamic heightValue = patientInfo['height_in_inches'];
      int? heightInches;
      if (heightValue is int) {
        heightInches = heightValue;
      } else if (heightValue is double) {
        heightInches = heightValue.round();
      } else if (heightValue is String) {
        heightInches = int.tryParse(heightValue);
      }
      if (heightInches != null && heightInches > 0) {
        final feet = heightInches ~/ 12;
        final inches = heightInches % 12;
        _heightFeetController.text = feet.toString();
        _heightInchesController.text = inches.toString();
      } else {
        _heightFeetController.clear();
        _heightInchesController.clear();
      }
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

  String? _validateHeightFeet(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter feet as a number';
    }
    if (parsed < 0) {
      return 'Feet must be 0 or greater';
    }
    return null;
  }

  String? _validateHeightInches(String? value) {
    final feetText = _heightFeetController.text.trim();
    final feet = feetText.isEmpty ? 0 : int.tryParse(feetText);
    if (feet == null) {
      return 'Enter feet as a number';
    }

    final inchesText = value?.trim() ?? '';
    if (inchesText.isEmpty) {
      if (feet == 0) {
        return 'Enter height';
      }
      return null;
    }

    final inches = int.tryParse(inchesText);
    if (inches == null) {
      return 'Enter inches as a number';
    }
    if (inches < 0) {
      return 'Inches must be 0 or greater';
    }
    if (inches > 11) {
      return 'Use a value between 0 and 11';
    }
    if (feet == 0 && inches == 0) {
      return 'Enter height';
    }
    return null;
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

    final feetText = _heightFeetController.text.trim();
    final inchesText = _heightInchesController.text.trim();
    final int heightFeet =
        feetText.isEmpty ? 0 : int.parse(feetText); // validated already
    final int heightInches =
        inchesText.isEmpty ? 0 : int.parse(inchesText); // validated already
    final totalHeight = (heightFeet * 12) + heightInches;

    if (totalHeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the patient\'s height.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final weight = int.tryParse(_weightController.text.trim()) ?? 0;

    try {
      final savedInfo = await _repository.upsertPatientInfo(
        sessionId: _sessionId!,
        name: _nameController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        sex: _sex,
        heightInInches: totalHeight,
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

  Future<void> _goBackToIncident() async {
    final canLeave = await _confirmLeave();
    if (!canLeave || !mounted) return;
    if (_sessionId == null) {
      Navigator.of(context).pushReplacementNamed('/sessions/new');
      return;
    }
    Navigator.of(context).pushReplacementNamed(
      '/sessions/new',
      arguments: {'sessionId': _sessionId},
    );
  }

  Future<void> _showFirstAid() async {
    final type = _incidentType;
    if (type == null || type.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an incident type before viewing first aid.'),
        ),
      );
      return;
    }
    await showFirstAidDialog(context, type);
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showFirstAid(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: firstAidAccentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.health_and_safety),
                            label: const Text('Show First Aid'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Patient Details',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: AppInputDecorations.filledField(
                            context,
                            label: 'Name',
                          ),
                          style: AppInputDecorations.fieldTextStyle,
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
                              decoration: AppInputDecorations.filledField(
                                context,
                                label: 'Date of Birth',
                                suffixIcon: const Icon(Icons.calendar_today),
                              ),
                              style: AppInputDecorations.fieldTextStyle,
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
                          decoration: AppInputDecorations.filledField(
                            context,
                            label: 'Sex',
                          ),
                          style: AppInputDecorations.fieldTextStyle,
                          items: const [
                            DropdownMenuItem(
                              value: 'M',
                              child: Text(
                                'Male',
                                style: AppInputDecorations.fieldTextStyle,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'F',
                              child: Text(
                                'Female',
                                style: AppInputDecorations.fieldTextStyle,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'O',
                              child: Text(
                                'Other',
                                style: AppInputDecorations.fieldTextStyle,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'U',
                              child: Text(
                                'Unknown',
                                style: AppInputDecorations.fieldTextStyle,
                              ),
                            ),
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _heightFeetController,
                                      decoration: AppInputDecorations
                                          .filledField(
                                        context,
                                        label: 'Height (ft)',
                                      ),
                                      style:
                                          AppInputDecorations.fieldTextStyle,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => _handleFieldChange(),
                                      validator: _validateHeightFeet,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _heightInchesController,
                                      decoration: AppInputDecorations
                                          .filledField(
                                        context,
                                        label: 'Height (in)',
                                      ),
                                      style:
                                          AppInputDecorations.fieldTextStyle,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => _handleFieldChange(),
                                      validator: _validateHeightInches,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _weightController,
                                decoration: AppInputDecorations.filledField(
                                  context,
                                  label: 'Weight (lbs)',
                                ),
                                style: AppInputDecorations.fieldTextStyle,
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
                          decoration: AppInputDecorations.filledField(
                            context,
                            label: 'Allergies',
                            hintText: 'List known allergies',
                          ),
                          style: AppInputDecorations.fieldTextStyle,
                          maxLines: 2,
                          onChanged: (_) => _handleFieldChange(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _medicationsController,
                          decoration: AppInputDecorations.filledField(
                            context,
                            label: 'Medications',
                            hintText: 'List current medications',
                          ),
                          style: AppInputDecorations.fieldTextStyle,
                          maxLines: 2,
                          onChanged: (_) => _handleFieldChange(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _medicalHistoryController,
                          decoration: AppInputDecorations.filledField(
                            context,
                            label: 'Medical History',
                            hintText: 'Summarize relevant medical history',
                          ),
                          style: AppInputDecorations.fieldTextStyle,
                          maxLines: 3,
                          onChanged: (_) => _handleFieldChange(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _chiefComplaintController,
                          decoration: AppInputDecorations.filledField(
                            context,
                            label: 'Chief Complaint',
                          ),
                          style: AppInputDecorations.fieldTextStyle,
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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving ? null : _goBackToIncident,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_back),
                                label:
                                    const Text('Back to Incident Information'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveAndContinue,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Continue to Vitals',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward),
                                        ],
                                      ),
                              ),
                            ),
                          ],
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
