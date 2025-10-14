import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/session_service.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  final _formKey = GlobalKey<FormState>();
  final _allergiesController = TextEditingController();
  final _medsController = TextEditingController();
  final _familyController = TextEditingController();
  String? _sessionId;
  bool _isSaving = false;

  ValueListenable<Duration?>? _timeLeftListenable;
  VoidCallback? _timeListener;
  void _attachTimer(String sessionId) {
    if (_timeLeftListenable != null && _timeListener != null) {
      _timeLeftListenable!.removeListener(_timeListener!);
    }
    _timeLeftListenable = sessionService.watchSessionTimeLeft(sessionId);
    _timeListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _timeLeftListenable!.addListener(_timeListener!);
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _medsController.dispose();
    _familyController.dispose();
    if (_timeLeftListenable != null && _timeListener != null) {
      _timeLeftListenable!.removeListener(_timeListener!);
    }
    _timeLeftListenable = null;
    _timeListener = null;
    super.dispose();
  }

  Future<void> _saveChart() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active session')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      sessionService.setSessionChart(_sessionId!, {
        'allergies': _allergiesController.text.trim(),
        'medications': _medsController.text.trim(),
        'familyHistory': _familyController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chart saved to session')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // pick up session id and start countdown when visible
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _sessionId != args) {
      _sessionId = args;
      final chart = sessionService.getSessionChart(_sessionId!);
      _allergiesController.text = chart['allergies'] as String? ?? '';
      _medsController.text = chart['medications'] as String? ?? '';
      _familyController.text = chart['familyHistory'] as String? ?? '';
      _attachTimer(_sessionId!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Chart')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_sessionId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Session: $_sessionId'),
                          Text(
                            'Time left: ${sessionService.formatDurationShort(_timeLeftListenable?.value)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(labelText: 'Allergies', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _medsController,
                decoration: const InputDecoration(labelText: 'Medications', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _familyController,
                decoration: const InputDecoration(labelText: 'Family History', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChart,
                child: _isSaving ? const CircularProgressIndicator() : const Text('Save Chart'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

