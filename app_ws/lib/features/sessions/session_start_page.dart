import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../services/session_service.dart';
import '../../services/supabase_session_repository.dart';
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
  final TextEditingController _typeController = TextEditingController();
  final _repository = SupabaseSessionRepository();

  DateTime? _incidentDate;
  TimeOfDay? _arrivalTime;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void dispose() {
    _addressController.dispose();
    _typeController.dispose();
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
      final session = await _repository.createSession(
        incidentDate: _incidentDate!,
        arrivalAt: arrivalDateTime,
        address: _addressController.text.trim(),
        type: _typeController.text.trim(),
      );
      sessionService.addSession(session);

      _hasUnsavedChanges = false;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/patient-info',
        arguments: {'sessionId': session.id},
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    decoration: const InputDecoration(
                      labelText: 'Incident Address',
                      border: OutlineInputBorder(),
                    ),
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
                  TextFormField(
                    controller: _typeController,
                    decoration: const InputDecoration(
                      labelText: 'Incident Type',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _handleFieldChange(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the incident type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue to Patient Information'),
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
