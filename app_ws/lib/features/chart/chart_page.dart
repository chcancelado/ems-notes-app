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
  final _medicationsController = TextEditingController();
  final _familyHistoryController = TextEditingController();
  bool _isSaving = false;
  String? _sessionId;
  Session? _session;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load session and chart data if session ID is provided
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _sessionId != args) {
      _sessionId = args;
      _loadChartData(args);
    }
  }

  Future<void> _loadChartData(String sessionId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      _session = sessionService.findSessionById(sessionId);
      
      if (_session != null) {
        final chartData = _session!.chart;
        _allergiesController.text = chartData['allergies'] as String? ?? '';
        _medicationsController.text = chartData['medications'] as String? ?? '';
        _familyHistoryController.text = chartData['familyHistory'] as String? ?? '';
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load chart data: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
      // Save chart data to session
      if (_session != null) {
        _session!.setChart({
          'allergies': _allergiesController.text.trim(),
          'medications': _medicationsController.text.trim(),
          'familyHistory': _familyHistoryController.text.trim(),
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }

      // Simulate database save (placeholder for future integration)
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Chart'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_session != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.folder_shared, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Active Session: ${_session!.patientName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Chart data will be saved to this session',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
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
