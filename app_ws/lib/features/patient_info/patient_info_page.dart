import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
import '../../widgets/app_input_decorations.dart';
import '../../widgets/first_aid_dialog.dart';
import '../../widgets/form_styles.dart';
import '../../widgets/patient_summary_dialog.dart';
import '../../widgets/sidebar_layout.dart';
import '../../widgets/unsaved_changes_dialog.dart';

class PatientInfoPage extends StatefulWidget {
  const PatientInfoPage({super.key});

  @override
  State<PatientInfoPage> createState() => _PatientInfoPageState();
}

class _PatientInfoPageState extends State<PatientInfoPage> {
  static const String _defaultPatientName = 'No Patient Name Entered';

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
  bool _isEditing = false;
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
    _isEditing = args?['isEditing'] as bool? ?? false;
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
      final name = patientInfo['name'] as String?;
      _nameController.text =
          name != null && name.isNotEmpty && name != _defaultPatientName
          ? name
          : '';
      final dobString = patientInfo['date_of_birth'] as String?;
      if (dobString != null) {
        final parsed = DateTime.tryParse(dobString);
        if (parsed != null) {
          _dateOfBirth = parsed;
          _dobController.text = '${parsed.month}/${parsed.day}/${parsed.year}';
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
        _dobController.text = '${picked.month}/${picked.day}/${picked.year}';
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (_isSaving) return;
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active session. Start a session first.'),
        ),
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      final feetText = _heightFeetController.text.trim();
      final inchesText = _heightInchesController.text.trim();
      final feet = feetText.isEmpty ? null : int.tryParse(feetText);
      final inches = inchesText.isEmpty ? null : int.tryParse(inchesText);
      final totalHeight =
          ((feet ?? 0) * 12) + (inches ?? 0); // 0 when height not provided
      final weight = int.tryParse(_weightController.text.trim());

      final safeName = _nameController.text.trim().isEmpty
          ? 'Unknown Patient'
          : _nameController.text.trim();
      final safeDob = _dateOfBirth ?? DateTime.now();
      final heightInches = totalHeight > 0 ? totalHeight : 1;
      final weightValue = (weight ?? 0) > 0 ? weight! : 1;

      final wasDirty = _hasUnsavedChanges;
      final savedInfo = await _repository.upsertPatientInfo(
        sessionId: _sessionId!,
        name: safeName.isEmpty ? _defaultPatientName : safeName,
        dateOfBirth: safeDob,
        sex: _sex,
        heightInInches: heightInches,
        weightInPounds: weightValue,
        allergies: _allergiesController.text.trim(),
        medications: _medicationsController.text.trim(),
        medicalHistory: _medicalHistoryController.text.trim(),
        chiefComplaint: _chiefComplaintController.text.trim(),
      );

      sessionService.updatePatientInfo(_sessionId!, savedInfo);
      setState(() {
        _hasUnsavedChanges = false;
      });

      if (_isEditing) {
        Navigator.of(context).pushReplacementNamed(
          '/sessions',
          arguments: wasDirty
              ? {'snackbarMessage': 'Patient information updated.'}
              : null,
        );
      } else {
        Navigator.of(context).pushReplacementNamed(
          '/vitals',
          arguments: {'sessionId': _sessionId, 'isEditing': _isEditing},
        );
      }
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
    Navigator.of(context).pushReplacementNamed(
      '/sessions/new',
      arguments: {'sessionId': _sessionId, 'isEditing': _isEditing},
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

  Future<void> _showPatientSummary() async {
    final session = _sessionId == null
        ? sessionService.latestSession
        : sessionService.findSessionById(_sessionId!);

    final feet = int.tryParse(_heightFeetController.text.trim());
    final inches = int.tryParse(_heightInchesController.text.trim());
    int? totalHeight;
    if ((feet ?? 0) > 0 || (inches ?? 0) > 0) {
      final safeFeet = feet ?? 0;
      final safeInches = inches ?? 0;
      totalHeight = (safeFeet * 12) + safeInches;
    }

    final weight = int.tryParse(_weightController.text.trim());

    final patientDraft = <String, dynamic>{};
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      patientDraft['name'] = name;
    }
    if (_dateOfBirth != null) {
      patientDraft['date_of_birth'] = _dateOfBirth;
    }
    if (_sex.isNotEmpty) {
      patientDraft['sex'] = _sex;
    }
    if (totalHeight != null && totalHeight > 0) {
      patientDraft['height_in_inches'] = totalHeight;
    }
    if (weight != null && weight > 0) {
      patientDraft['weight_in_pounds'] = weight;
    }
    final allergies = _allergiesController.text.trim();
    if (allergies.isNotEmpty) {
      patientDraft['allergies'] = allergies;
    }
    final medications = _medicationsController.text.trim();
    if (medications.isNotEmpty) {
      patientDraft['medications'] = medications;
    }
    final history = _medicalHistoryController.text.trim();
    if (history.isNotEmpty) {
      patientDraft['medical_history'] = history;
    }
    final complaint = _chiefComplaintController.text.trim();
    if (complaint.isNotEmpty) {
      patientDraft['chief_complaint'] = complaint;
    }

    await showPatientSummaryDialog(
      context,
      session: session,
      patientDraft: patientDraft.isEmpty ? null : patientDraft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SidebarLayout(
      title: _isEditing ? 'Edit Patient Information' : 'Start New Session',
      sessionNavLabel: _isEditing
          ? 'Edit Patient Information'
          : 'Start New Session',
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
              child: Padding(
                padding: FormStyles.pagePadding,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: FormStyles.maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Text(
                                    'Patient Information',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
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
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: _pickDateOfBirth,
                                  child: AbsorbPointer(
                                    child: TextFormField(
                                      controller: _dobController,
                                      decoration:
                                          AppInputDecorations.filledField(
                                            context,
                                            label: 'Date of Birth',
                                            suffixIcon: const Icon(
                                              Icons.calendar_today,
                                            ),
                                          ),
                                      style: AppInputDecorations.fieldTextStyle,
                                      onChanged: (_) => _handleFieldChange(),
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
                                        style:
                                            AppInputDecorations.fieldTextStyle,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'F',
                                      child: Text(
                                        'Female',
                                        style:
                                            AppInputDecorations.fieldTextStyle,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'O',
                                      child: Text(
                                        'Other',
                                        style:
                                            AppInputDecorations.fieldTextStyle,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'U',
                                      child: Text(
                                        'Unknown',
                                        style:
                                            AppInputDecorations.fieldTextStyle,
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
                                              decoration:
                                                  AppInputDecorations.filledField(
                                                    context,
                                                    label: 'Height (ft)',
                                                  ),
                                              style: AppInputDecorations
                                                  .fieldTextStyle,
                                              keyboardType:
                                                  TextInputType.number,
                                              onChanged: (_) =>
                                                  _handleFieldChange(),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller:
                                                  _heightInchesController,
                                              decoration:
                                                  AppInputDecorations.filledField(
                                                    context,
                                                    label: 'Height (in)',
                                                  ),
                                              style: AppInputDecorations
                                                  .fieldTextStyle,
                                              keyboardType:
                                                  TextInputType.number,
                                              onChanged: (_) =>
                                                  _handleFieldChange(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _weightController,
                                        decoration:
                                            AppInputDecorations.filledField(
                                              context,
                                              label: 'Weight (lbs)',
                                            ),
                                        style:
                                            AppInputDecorations.fieldTextStyle,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => _handleFieldChange(),
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
                                    hintText:
                                        'Summarize relevant medical history',
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
                                ),
                                const SizedBox(height: 24),
                                if (_isEditing)
                                  ElevatedButton(
                                    onPressed: _isSaving
                                        ? null
                                        : _saveAndContinue,
                                    style: FormStyles.primaryElevatedButton(
                                      context,
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Save Patient Information',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _isSaving
                                              ? null
                                              : _goBackToIncident,
                                          style:
                                              FormStyles.primaryOutlinedButton(
                                            context,
                                          ),
                                          icon: const Icon(Icons.arrow_back),
                                          label: const Text('Incident Info'),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _isSaving
                                              ? null
                                              : _saveAndContinue,
                                          style:
                                              FormStyles.primaryElevatedButton(
                                            context,
                                          ),
                                          child: _isSaving
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Vitals',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Icon(Icons.arrow_forward),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showPatientSummary,
                                        style:
                                            FormStyles.firstAidOutlinedButton(),
                                        icon: const Icon(Icons.receipt_long),
                                        label: const Text(
                                          'Summary',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showFirstAid(),
                                        style:
                                            FormStyles.firstAidElevatedButton(),
                                        icon: const Icon(
                                          Icons.health_and_safety,
                                        ),
                                        label: const Text('First Aid'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
