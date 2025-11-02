import 'package:flutter/material.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  final _formKey = GlobalKey<FormState>();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _familyHistoryController = TextEditingController();
  bool _isSaving = false;
  String? _sessionId;

  @override
  void dispose() {
    _allergiesController.dispose();
    _medicationsController.dispose();
    _familyHistoryController.dispose();
    super.dispose();
  }

  Future<void> _saveChart() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // TODO: Save chart data to session service
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chart saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save chart: $error')),
      );
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
    // Capture session ID from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _sessionId != args) {
      _sessionId = args;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Chart'),
      ),
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
                      child: Text('Chart for session: $_sessionId'),
                    ),
                  ),
                ),
              TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(
                  labelText: 'Allergies',
                  border: OutlineInputBorder(),
                  helperText: 'List any known allergies',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _medicationsController,
                decoration: const InputDecoration(
                  labelText: 'Current Medications',
                  border: OutlineInputBorder(),
                  helperText: 'List current medications and dosages',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _familyHistoryController,
                decoration: const InputDecoration(
                  labelText: 'Family History',
                  border: OutlineInputBorder(),
                  helperText: 'Relevant family medical history',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChart,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Chart'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Vitals'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
