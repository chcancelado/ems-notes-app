import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
import '../../widgets/app_input_decorations.dart';
import '../../widgets/first_aid_dialog.dart';
import '../../widgets/sidebar_layout.dart';
import '../../widgets/unsaved_changes_dialog.dart';

class SessionStartPage extends StatefulWidget {
  const SessionStartPage({super.key});

  @override
  State<SessionStartPage> createState() => _SessionStartPageState();
}

class _SessionStartPageState extends State<SessionStartPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final _repository = SupabaseSessionRepository();

  DateTime? _incidentDate;
  TimeOfDay? _arrivalTime;
  String? _sessionId;
  bool _initialized = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String _selectedIncidentType = '';

  static const List<String> _incidentTypes = [
    'Abdominal Pain',
    'Allergic Reaction / Anaphylaxis',
    'Altered Mental Status',
    'Animal Bite / Snake Bite',
    'Chest Pain / Cardiac',
    'Dehydration',
    'Diabetic Emergency (Hypo/Hyperglycemia)',
    'Difficulty Breathing / Respiratory Distress',
    'Electrocution',
    'Fever / Infection / Sepsis',
    'GI Bleed',
    'Hazardous Materials Exposure',
    'Heat Exhaustion / Heat Stroke',
    'Hypothermia / Cold Exposure',
    'Nausea / Vomiting',
    'OB/GYN (Pregnancy / Childbirth)',
    'Overdose / Poisoning',
    'Psychiatric / Behavioral',
    'Seizure',
    'Stroke / CVA',
    'Syncope / Fainting',
    'Trauma',
    'Unconscious / Unresponsive',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _incidentDate = now;
    _arrivalTime = TimeOfDay.fromDateTime(now);
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
      final session = sessionService.findSessionById(sessionId);
      final incident = session?.incidentInfo ?? {};
      final incidentDate = incident['incident_date'];
      if (incidentDate is String) {
        _incidentDate = DateTime.tryParse(incidentDate) ?? _incidentDate;
      } else if (incidentDate is DateTime) {
        _incidentDate = incidentDate;
      }
      final arrival = incident['arrival_at'];
      if (arrival is String) {
        final parsed = DateTime.tryParse(arrival);
        if (parsed != null) {
          _arrivalTime = TimeOfDay.fromDateTime(parsed.toLocal());
        }
      } else if (arrival is DateTime) {
        _arrivalTime = TimeOfDay.fromDateTime(arrival.toLocal());
      } else {
        _arrivalTime = null;
      }
      final address = incident['address'] as String?;
      if (address != null && address.isNotEmpty) {
        _addressController.text = address;
      }
      final type = incident['type'] as String?;
      if (type != null && type.isNotEmpty) {
        _selectedIncidentType = type;
      }
      _hasUnsavedChanges = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickIncidentDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _incidentDate = picked;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _pickArrivalTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _arrivalTime = picked;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _handleFieldChange() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _showFirstAid() async {
    if (_selectedIncidentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an incident type to view first aid.')),
      );
      return;
    }
    await showFirstAidDialog(context, _selectedIncidentType);
  }

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) {
      return true;
    }
    return showUnsavedChangesDialog(context);
  }

  Future<void> _submit() async {
    if (_incidentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an incident date.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedIncidentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the incident type.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final arrivalDateTime = _arrivalTime == null
        ? null
        : DateTime(
            _incidentDate!.year,
            _incidentDate!.month,
            _incidentDate!.day,
            _arrivalTime!.hour,
            _arrivalTime!.minute,
          );

    try {
      if (_sessionId == null) {
        final session = await _repository.createSession(
          incidentDate: _incidentDate!,
          arrivalAt: arrivalDateTime,
          address: _addressController.text.trim(),
          type: _selectedIncidentType,
        );
        sessionService.addSession(session);
        _sessionId = session.id;
      } else {
        final incidentInfo = await _repository.updateSession(
          sessionId: _sessionId!,
          incidentDate: _incidentDate!,
          arrivalAt: arrivalDateTime,
          address: _addressController.text.trim(),
          type: _selectedIncidentType,
        );
        sessionService.updateIncidentInfo(_sessionId!, incidentInfo);
      }

      _hasUnsavedChanges = false;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/patient-info',
        arguments: {'sessionId': _sessionId},
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: $error')),
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

  Future<void> _discard() async {
    final canLeave = await _confirmLeave();
    if (!canLeave || !mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incidentOptions = [..._incidentTypes];
    if (_selectedIncidentType.isNotEmpty &&
        !incidentOptions.contains(_selectedIncidentType)) {
      incidentOptions.insert(0, _selectedIncidentType);
    }
    final arrivalLabel = _arrivalTime == null
        ? 'Select arrival time'
        : _arrivalTime!.format(context);

    final incidentLabel = _incidentDate == null
        ? 'Select incident date'
        : '${_incidentDate!.month}/${_incidentDate!.day}/${_incidentDate!.year}';

    return SidebarLayout(
      title: 'Start New Session',
      activeDestination: SidebarDestination.newSession,
      onNavigateAway: _confirmLeave,
      onLogout: () async {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      },
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
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
                    'Incident Information',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickIncidentDate,
                    icon: const Icon(Icons.event),
                    label: Text(incidentLabel),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickArrivalTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(arrivalLabel),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: AppInputDecorations.filledField(
                      context,
                      label: 'Incident Address',
                    ),
                    style: AppInputDecorations.fieldTextStyle,
                    maxLines: 2,
                    onChanged: (_) => _handleFieldChange(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the incident address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedIncidentType.isEmpty
                        ? null
                        : _selectedIncidentType,
                    decoration: AppInputDecorations.filledField(
                      context,
                      label: 'Incident Type',
                    ),
                    hint: const Text('Select an incident type'),
                    items: incidentOptions
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedIncidentType = value;
                      });
                      _handleFieldChange();
                    },
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Please select the incident type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _discard,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Discard Session'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Continue Patient Information',
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
