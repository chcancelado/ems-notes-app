import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
import '../../widgets/sidebar_layout.dart';
import '../../widgets/unsaved_changes_dialog.dart';

class VitalsPage extends StatefulWidget {
  const VitalsPage({super.key});

  @override
  State<VitalsPage> createState() => _VitalsPageState();
}

class _VitalsPageState extends State<VitalsPage> {
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
  bool _initialized = false;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isHydrating = false;

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
    });
  }

  void _handleFieldChange() {
    if (_isHydrating) return;
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

  Future<void> _addVitals() async {
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active session. Start a session first.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final entry = await _repository.addVitals(
        sessionId: _sessionId!,
        pulseRate: int.parse(_pulseController.text.trim()),
        breathingRate: int.parse(_breathingController.text.trim()),
        systolic: int.parse(_systolicController.text.trim()),
        diastolic: int.parse(_diastolicController.text.trim()),
        spo2: int.tryParse(_spo2Controller.text.trim()),
        bloodGlucose: int.tryParse(_glucoseController.text.trim()),
        temperature: int.tryParse(_temperatureController.text.trim()),
        notes: _notesController.text.trim(),
      );

      sessionService.addVitalsEntry(_sessionId!, entry);
      setState(() {});
      _resetForm();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add vitals: $error')),
        );
      }
    }
  }

  String _formatTimestamp(String? value) {
    if (value == null || value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final time =
        TimeOfDay(hour: parsed.hour, minute: parsed.minute).format(context);
    return '${parsed.month}/${parsed.day}/${parsed.year} at $time';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return SidebarLayout(
      title: 'Vitals',
      activeDestination: SidebarDestination.newSession,
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
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (session.patientName.isNotEmpty)
                            Text(
                              'Patient: ${session.patientName}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
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
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _numberField(
                                        controller: _breathingController,
                                        label: 'Breathing Rate',
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
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _numberField(
                                        controller: _diastolicController,
                                        label: 'BP Diastolic',
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
                                        required: false,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _numberField(
                                        controller: _glucoseController,
                                        label: 'Blood Glucose',
                                        required: false,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _numberField(
                                        controller: _temperatureController,
                                        label: 'Temperature',
                                        required: false,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Notes',
                                  ),
                                  maxLines: 3,
                                  onChanged: (_) => _handleFieldChange(),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _addVitals,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Vitals Entry'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Recorded Vitals',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
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
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    title: Text(
                                      'Pulse ${entry['pulse_rate']} | '
                                      'Resp ${entry['breathing_rate']} | '
                                      'BP ${entry['blood_pressure_systolic']}/${entry['blood_pressure_diastolic']}',
                                    ),
                                    subtitle: Text(
                                      [
                                        if (entry['spo2'] != null)
                                          'SpO2 ${entry['spo2']}%',
                                        if (entry['blood_glucose'] != null)
                                          'Glucose ${entry['blood_glucose']}',
                                        if (entry['temperature'] != null)
                                          'Temp ${entry['temperature']} F',
                                        if ((entry['notes'] as String?)
                                                ?.isNotEmpty ??
                                            false)
                                          'Notes: ${entry['notes']}',
                                        _formatTimestamp(
                                            entry['recorded_at'] as String?),
                                      ].where((text) => text.isNotEmpty).join('\n'),
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 24),
                          OutlinedButton(
                            onPressed: () async {
                              final canLeave = await _confirmLeave();
                              if (!canLeave) return;
                              if (!mounted) return;
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/home',
                                (route) => route.settings.name == '/home',
                              );
                            },
                            child: const Text('Finish Session'),
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
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      onChanged: (_) => _handleFieldChange(),
      validator: (value) {
        if (!required && (value == null || value.trim().isEmpty)) {
          return null;
        }
        if (value == null || value.trim().isEmpty) {
          return 'Enter $label';
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
