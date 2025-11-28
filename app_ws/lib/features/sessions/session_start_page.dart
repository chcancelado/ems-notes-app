import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../models/session_models.dart';
import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
import '../../widgets/app_input_decorations.dart';
import '../../widgets/first_aid_dialog.dart';
import '../../widgets/form_styles.dart';
import '../../widgets/patient_summary_dialog.dart';
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
  bool _isEditing = false;
  bool _initialized = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _fromSharedSessions = false;
  bool _isGettingLocation = false;
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
    _isEditing = args?['isEditing'] as bool? ?? false;
    _fromSharedSessions = args?['fromSharedSessions'] as bool? ?? false;
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

  SidebarDestination get _activeDestination {
    if (_isEditing) {
      return _fromSharedSessions
          ? SidebarDestination.sharedSessions
          : SidebarDestination.sessions;
    }
    return SidebarDestination.newSession;
  }

  String get _sessionsRoute =>
      _fromSharedSessions ? '/sessions/shared' : '/sessions';

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickIncidentDate() async {
    final now = DateTime.now();
    final picked = await _showDropdownDatePicker(
      initialDate: _incidentDate ?? now,
      minYear: now.year - 1,
      maxYear: now.year + 1,
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

  Future<DateTime?> _showDropdownDatePicker({
    required DateTime initialDate,
    required int minYear,
    required int maxYear,
  }) {
    int selectedYear = initialDate.year.clamp(minYear, maxYear);
    int selectedMonth = initialDate.month;
    int selectedDay = initialDate.day;

    void clampDay() {
      final daysInMonth = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
      if (selectedDay > daysInMonth) {
        selectedDay = daysInMonth;
      }
    }

    clampDay();

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Date'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedMonth,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Jan')),
                            DropdownMenuItem(value: 2, child: Text('Feb')),
                            DropdownMenuItem(value: 3, child: Text('Mar')),
                            DropdownMenuItem(value: 4, child: Text('Apr')),
                            DropdownMenuItem(value: 5, child: Text('May')),
                            DropdownMenuItem(value: 6, child: Text('Jun')),
                            DropdownMenuItem(value: 7, child: Text('Jul')),
                            DropdownMenuItem(value: 8, child: Text('Aug')),
                            DropdownMenuItem(value: 9, child: Text('Sep')),
                            DropdownMenuItem(value: 10, child: Text('Oct')),
                            DropdownMenuItem(value: 11, child: Text('Nov')),
                            DropdownMenuItem(value: 12, child: Text('Dec')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setStateDialog(() {
                              selectedMonth = value;
                              clampDay();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedDay,
                          items: List.generate(
                            DateUtils.getDaysInMonth(
                              selectedYear,
                              selectedMonth,
                            ),
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setStateDialog(() {
                              selectedDay = value;
                              clampDay();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedYear,
                          items: List.generate(
                            (maxYear - minYear) + 1,
                            (index) => DropdownMenuItem(
                              value: minYear + index,
                              child: Text('${minYear + index}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setStateDialog(() {
                              selectedYear = value;
                              clampDay();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      DateTime(selectedYear, selectedMonth, selectedDay),
                    );
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleFieldChange() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable them.'),
          ),
        );
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied.'),
            ),
          );
          setState(() {
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied. Please enable them in settings.',
            ),
          ),
        );
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Reverse geocode to get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final addressParts = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((part) => part != null && part.isNotEmpty);

        final address = addressParts.join(', ');

        setState(() {
          _addressController.text = address;
          _hasUnsavedChanges = true;
          _isGettingLocation = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location retrieved successfully!'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get location: $e'),
        ),
      );
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _showFirstAid() async {
    if (_selectedIncidentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an incident type to view first aid.'),
        ),
      );
      return;
    }
    await showFirstAidDialog(context, _selectedIncidentType);
  }

  Future<void> _showPatientSummary() async {
    final session = _sessionId == null
        ? sessionService.latestSession
        : sessionService.findSessionById(_sessionId!);

    DateTime? arrivalDateTime;
    if (_incidentDate != null && _arrivalTime != null) {
      arrivalDateTime = DateTime(
        _incidentDate!.year,
        _incidentDate!.month,
        _incidentDate!.day,
        _arrivalTime!.hour,
        _arrivalTime!.minute,
      );
    }

    final incidentDraft = <String, dynamic>{};
    if (_incidentDate != null) {
      incidentDraft['incident_date'] = _incidentDate;
    }
    if (arrivalDateTime != null) {
      incidentDraft['arrival_at'] = arrivalDateTime;
    }
    final address = _addressController.text.trim();
    if (address.isNotEmpty) {
      incidentDraft['address'] = address;
    }
    if (_selectedIncidentType.isNotEmpty) {
      incidentDraft['type'] = _selectedIncidentType;
    }

    await showPatientSummaryDialog(
      context,
      session: session,
      incidentDraft: incidentDraft.isEmpty ? null : incidentDraft,
    );
  }

  PatientInfo? _getCurrentPatientInfo() {
    if (_sessionId == null) return null;
    final session = sessionService.findSessionById(_sessionId!);
    return session?.patientInfoModel;
  }

  List<VitalsEntry>? _getCurrentVitals() {
    if (_sessionId == null) return null;
    final session = sessionService.findSessionById(_sessionId!);
    final vitals = session?.vitals ?? [];
    if (vitals.isEmpty) return null;
    return vitals.map((v) => VitalsEntry.fromSupabaseRow(v)).toList();
  }

  IncidentInfo? _getCurrentIncidentInfo() {
    // Build from current form values
    if (_incidentDate == null) return null;
    
    // Convert TimeOfDay to DateTime if available
    DateTime? arrivalDateTime;
    if (_arrivalTime != null) {
      arrivalDateTime = DateTime(
        _incidentDate!.year,
        _incidentDate!.month,
        _incidentDate!.day,
        _arrivalTime!.hour,
        _arrivalTime!.minute,
      );
    }
    
    return IncidentInfo(
      incidentDate: _incidentDate!,
      arrivalAt: arrivalDateTime,
      address: _addressController.text,
      type: _selectedIncidentType,
    );
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
      final wasDirty = _hasUnsavedChanges;
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
      if (_isEditing) {
        Navigator.of(context).pushReplacementNamed(
          _sessionsRoute,
          arguments: wasDirty
              ? {
                  'snackbarMessage': 'Incident information updated.',
                  'sharedOnly': _fromSharedSessions,
                }
              : null,
        );
      } else {
        Navigator.of(context).pushReplacementNamed(
          '/patient-info',
          arguments: {'sessionId': _sessionId, 'isEditing': _isEditing},
        );
      }
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
    if (_isEditing) {
      Navigator.of(context).pushReplacementNamed(
        _sessionsRoute,
        arguments: {'sharedOnly': _fromSharedSessions},
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incidentOptions = [..._incidentTypes];
    if (_selectedIncidentType.isNotEmpty &&
        !incidentOptions.contains(_selectedIncidentType)) {
      incidentOptions.insert(0, _selectedIncidentType);
    }
    final fallbackArrival = _arrivalTime ?? TimeOfDay.now();
    final arrivalLabel = fallbackArrival.format(context);

    final incidentLabel = _incidentDate == null
        ? 'Select incident date'
        : '${_incidentDate!.month}/${_incidentDate!.day}/${_incidentDate!.year}';

    return SidebarLayout(
      title: _isEditing ? 'Edit Incident Information' : 'Start New Session',
      sessionNavLabel: _isEditing ? null : 'Start New Session',
      activeDestination: _activeDestination,
      currentPatientInfo: _getCurrentPatientInfo(),
      currentVitals: _getCurrentVitals(),
      currentIncidentInfo: _getCurrentIncidentInfo(),
      onNavigateAway: _confirmLeave,
      onLogout: () async {
        final navigator = Navigator.of(context);
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        navigator.pushReplacementNamed('/login');
      },
      body: Align(
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
                Center(
                  child: Text(
                    'Incident Information',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickIncidentDate,
                                  icon: const Icon(Icons.event),
                                  label: Text(incidentLabel),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickArrivalTime,
                                  icon: const Icon(Icons.schedule),
                                  label: Text(arrivalLabel),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
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
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: IconButton.filled(
                                  onPressed: _isGettingLocation
                                      ? null
                                      : _getCurrentLocation,
                                  icon: _isGettingLocation
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location),
                                  tooltip: 'Use Current Location',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedIncidentType.isEmpty
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
                          if (_isEditing)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isSaving ? null : _discard,
                                    style: FormStyles.primaryOutlinedButton(
                                      context,
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Discard Changes'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _submit,
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
                                            'Save Incident Information',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isSaving ? null : _discard,
                                    style: FormStyles.primaryOutlinedButton(
                                      context,
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Discard'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _submit,
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
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Patient Info',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
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
                                  style: FormStyles.firstAidOutlinedButton(),
                                  icon: const Icon(Icons.receipt_long),
                                  label: const Text('Summary'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showFirstAid(),
                                  style: FormStyles.firstAidElevatedButton(),
                                  icon: const Icon(Icons.health_and_safety),
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
