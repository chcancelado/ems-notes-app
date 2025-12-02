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

class VitalsPage extends StatefulWidget {
  const VitalsPage({super.key});

  @override
  State<VitalsPage> createState() => _VitalsPageState();
}

class _VitalsPageState extends State<VitalsPage> {
  static const int _defaultPulseRate = 0;
  static const int _defaultBreathingRate = 0;
  static const int _defaultSystolic = 1;
  static const int _defaultDiastolic = 1;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _pulseController = TextEditingController();
  final TextEditingController _breathingController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _spo2Controller = TextEditingController();
  final TextEditingController _glucoseController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final _repository = SupabaseSessionRepository();

  String? _sessionId;
  bool _isEditing = false;
  bool _initialized = false;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isHydrating = false;
  DateTime? _recordingStartedAt;
  DateTime? _recordingEndedAt;
  bool _fromSharedSessions = false;

  @override
  void dispose() {
    _pulseController.dispose();
    _breathingController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _spo2Controller.dispose();
    _glucoseController.dispose();
    _temperatureController.dispose();
    _notesController.dispose();
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
    _fromSharedSessions = args?['fromSharedSessions'] as bool? ?? false;
    final sessionId = args?['sessionId'] as String?;
    if (sessionId != null) {
      _sessionId = sessionId;
    } else {
      _sessionId = sessionService.latestSession?.id;
    }

    if (_sessionId != null) {
      _loadVitalsFromSupabase(_sessionId!);
    } else {
      setState(() {});
    }
  }

  Session? get _session =>
      _sessionId == null ? null : sessionService.findSessionById(_sessionId!);

  List<Map<String, dynamic>> get _vitals =>
      _session?.vitals ?? const <Map<String, dynamic>>[];

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

  Future<void> _loadVitalsFromSupabase(String sessionId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entries = await _repository.fetchVitals(sessionId);
      sessionService.replaceVitals(sessionId, entries);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vitals: $error')),
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

  void _resetForm() {
    _isHydrating = true;
    _pulseController.clear();
    _breathingController.clear();
    _systolicController.clear();
    _diastolicController.clear();
    _spo2Controller.clear();
    _glucoseController.clear();
    _temperatureController.clear();
    _notesController.clear();
    _isHydrating = false;
    setState(() {
      _hasUnsavedChanges = false;
      _recordingStartedAt = null;
      _recordingEndedAt = null;
    });
  }

  void _handleFieldChange() {
    if (_isHydrating) return;
    final hasValue = _hasAnyInput();
    if (hasValue && _recordingStartedAt == null) {
      _recordingStartedAt = DateTime.now();
    }
    if (hasValue) {
      _recordingEndedAt = DateTime.now();
    }
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  bool _hasAnyInput() {
    return [
      _pulseController,
      _breathingController,
      _systolicController,
      _diastolicController,
      _spo2Controller,
      _glucoseController,
      _temperatureController,
      _notesController,
    ].any((controller) => controller.text.trim().isNotEmpty);
  }

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) {
      return true;
    }
    return showUnsavedChangesDialog(context);
  }

  Future<void> _addVitals() async {
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active session. Start a session first.'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final pulseText = _pulseController.text.trim();
    final breathingText = _breathingController.text.trim();
    final systolicText = _systolicController.text.trim();
    final diastolicText = _diastolicController.text.trim();
    final spo2Text = _spo2Controller.text.trim();
    final glucoseText = _glucoseController.text.trim();
    final tempText = _temperatureController.text.trim();
    final notesText = _notesController.text.trim();

    final hasAnyValue = [
      pulseText,
      breathingText,
      systolicText,
      diastolicText,
      spo2Text,
      glucoseText,
      tempText,
      notesText,
    ].any((value) => value.isNotEmpty);

    if (!hasAnyValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least one vital before saving.'),
        ),
      );
      return;
    }

    final pulse = int.tryParse(pulseText) ?? _defaultPulseRate;
    final breathing = int.tryParse(breathingText) ?? _defaultBreathingRate;
    final systolic = int.tryParse(systolicText) ?? _defaultSystolic;
    final diastolic = int.tryParse(diastolicText) ?? _defaultDiastolic;
    final spo2 = int.tryParse(spo2Text);
    final glucose = int.tryParse(glucoseText);
    final temp = int.tryParse(tempText);
    final recordingStart = _recordingStartedAt ?? DateTime.now();
    final recordingEnd = _recordingEndedAt ?? recordingStart;

    try {
      final entry = await _repository.addVitals(
        sessionId: _sessionId!,
        pulseRate: pulse,
        breathingRate: breathing,
        systolic: systolic,
        diastolic: diastolic,
        spo2: spo2,
        bloodGlucose: glucose,
        temperature: temp,
        notes: notesText,
        recordingStartedAt: recordingStart.toUtc(),
        recordingEndedAt: recordingEnd.toUtc(),
      );

      sessionService.addVitalsEntry(_sessionId!, entry);
      setState(() {});
      _resetForm();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add vitals: $error')));
      }
    }
  }

  Future<void> _finishSession() async {
    final canLeave = await _confirmLeave();
    if (!canLeave || !mounted) return;
    final message = _isEditing ? 'Vitals added.' : 'New session saved.';
    Navigator.of(context).pushNamedAndRemoveUntil(
      _sessionsRoute,
      (route) => false,
      arguments: {
        'snackbarMessage': message,
        'sharedOnly': _fromSharedSessions,
      },
    );
  }

  void _navigateBackToPatientInfo() {
    Navigator.of(context).pushReplacementNamed(
      '/patient-info',
      arguments: {
        'sessionId': _sessionId,
        'isEditing': _isEditing,
        'fromSharedSessions': _fromSharedSessions,
      },
    );
  }

  Future<void> _discardEdits() async {
    final canLeave = await _confirmLeave();
    if (!canLeave || !mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      _sessionsRoute,
      (route) => false,
      arguments: {'sharedOnly': _fromSharedSessions},
    );
  }

  Future<void> _showPatientSummary() async {
    final session = _sessionId == null
        ? sessionService.latestSession
        : sessionService.findSessionById(_sessionId!);
    await showPatientSummaryDialog(context, session: session);
  }

  Future<void> _showFirstAid() async {
    final type = _session?.incidentInfo['type'];
    if (type is! String || type.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incident type not available. Return to Incident Information to set it.',
          ),
        ),
      );
      return;
    }
    await showFirstAidDialog(context, type);
  }

  String _formatTimeRange(String? startIso, String? endIso) {
    DateTime? start;
    DateTime? end;
    if (startIso != null && startIso.isNotEmpty) {
      start = DateTime.tryParse(startIso);
    }
    if (endIso != null && endIso.isNotEmpty) {
      end = DateTime.tryParse(endIso);
    }
    if (start == null) {
      return '--';
    }
    final startText = TimeOfDay.fromDateTime(start.toLocal()).format(context);
    final endText = end == null
        ? '--'
        : TimeOfDay.fromDateTime(end.toLocal()).format(context);
    return '$startText - $endText';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final theme = Theme.of(context);
    final slashStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
    );
    return SidebarLayout(
      title: _isEditing ? 'Add Vitals' : 'Start New Session',
      sessionNavLabel: _isEditing ? null : 'Start New Session',
      activeDestination: _activeDestination,
      onNavigateAway: _confirmLeave,
      onLogout: () async {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        navigator.pushReplacementNamed('/login');
      },
      body: session == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No active session found. Start a session first.'),
              ),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
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
                          'Vitals',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _numberField(
                                    controller: _pulseController,
                                    label: 'Pulse Rate',
                                    hint: '-',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _numberField(
                                    controller: _breathingController,
                                    label: 'Breathing Rate',
                                    hint: '-',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _numberField(
                                    controller: _systolicController,
                                    label: 'BP Systolic',
                                    hint: '-',
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  height: 56,
                                  alignment: Alignment.center,
                                  child: Text('/', style: slashStyle),
                                ),
                                Expanded(
                                  child: _numberField(
                                    controller: _diastolicController,
                                    label: 'BP Diastolic',
                                    hint: '-',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _numberField(
                                    controller: _spo2Controller,
                                    label: 'SpO2',
                                    hint: '-',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _numberField(
                                    controller: _temperatureController,
                                    label: 'Temperature',
                                    hint: '-',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _numberField(
                              controller: _glucoseController,
                              label: 'Blood Glucose',
                              hint: '-',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesController,
                              decoration: AppInputDecorations.filledField(
                                context,
                                label: 'Notes',
                              ),
                              style: AppInputDecorations.fieldTextStyle,
                              maxLines: 3,
                              onChanged: (_) => _handleFieldChange(),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _addVitals,
                                style:
                                    FormStyles.primaryElevatedButton(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Vitals Entry'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 16),
                      Text(
                        'Recorded Vitals',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_vitals.isEmpty)
                        const Text('No vitals recorded yet.')
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _vitals.length,
                          itemBuilder: (context, index) {
                            final entry = _vitals[index];
                            final pulseRaw = entry['pulse_rate'] as int?;
                            final breathingRaw =
                                entry['breathing_rate'] as int?;
                            final systolicRaw =
                                entry['blood_pressure_systolic'] as int?;
                            final diastolicRaw =
                                entry['blood_pressure_diastolic'] as int?;
                            final pulse =
                                (pulseRaw == null ||
                                    pulseRaw == _defaultPulseRate)
                                ? null
                                : pulseRaw;
                            final breathing =
                                (breathingRaw == null ||
                                    breathingRaw == _defaultBreathingRate)
                                ? null
                                : breathingRaw;
                            final systolic =
                                (systolicRaw == null ||
                                    systolicRaw == _defaultSystolic)
                                ? null
                                : systolicRaw;
                            final diastolic =
                                (diastolicRaw == null ||
                                    diastolicRaw == _defaultDiastolic)
                                ? null
                                : diastolicRaw;
                            final titleParts = <String>[];
                            if (pulse != null) {
                              titleParts.add('Pulse $pulse bpm');
                            }
                            if (breathing != null) {
                              titleParts.add('Resp $breathing bpm');
                            }
                            if (systolic != null || diastolic != null) {
                              final systolicText = systolic?.toString() ?? '--';
                              final diastolicText =
                                  diastolic?.toString() ?? '--';
                              titleParts.add('BP $systolicText/$diastolicText');
                            }
                            final titleText = titleParts.isEmpty
                                ? 'Vitals Entry'
                                : titleParts.join(' | ');
                            final rangeText = _formatTimeRange(
                              entry['recording_started_at'] as String?,
                              entry['recording_ended_at'] as String?,
                            );
                            final subtitleLines = [
                              if (entry['spo2'] != null)
                                'SpO2 ${entry['spo2']}%',
                              if (entry['blood_glucose'] != null)
                                'Glucose ${entry['blood_glucose']} mg/dL',
                              if (entry['temperature'] != null)
                                'Temp ${entry['temperature']} F',
                              if ((entry['notes'] as String?)?.isNotEmpty ??
                                  false)
                                'Notes: ${entry['notes']}',
                            ].where((text) => text.isNotEmpty).toList();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 160,
                                      child: Text(
                                        rangeText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            titleText,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          if (subtitleLines.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                subtitleLines.join('\n'),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                      if (_isEditing)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _discardEdits,
                                style: FormStyles.primaryOutlinedButton(context),
                                icon: const Icon(Icons.close),
                                label: const Text('Discard'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _finishSession,
                                style: FormStyles.primaryElevatedButton(context),
                                icon: const Icon(Icons.save),
                                label: const Text(
                                  'Save',
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
                                onPressed: _navigateBackToPatientInfo,
                                style:
                                    FormStyles.primaryOutlinedButton(context),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Patient Info'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _finishSession,
                                style:
                                    FormStyles.primaryElevatedButton(context),
                                icon: const Icon(Icons.save),
                                label: const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    bool showLabel = true,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: AppInputDecorations.filledField(
        context,
        label: label,
        hintText: hint,
        showLabel: showLabel,
      ),
      style: AppInputDecorations.fieldTextStyle,
      keyboardType: TextInputType.number,
      onChanged: (_) => _handleFieldChange(),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }
        final parsed = int.tryParse(value.trim());
        if (parsed == null) {
          return 'Enter a whole number';
        }
        if (parsed < 0) {
          return 'Enter a positive value';
        }
        return null;
      },
    );
  }
}
