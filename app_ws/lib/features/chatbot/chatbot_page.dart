import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import '../../services/openai_service.dart';

// Floating chatbot dialog that can be shown over any page
class ChatbotDialog extends StatefulWidget {
  final PatientInfo? patientInfo;
  final List<VitalsEntry>? vitalsHistory;
  final IncidentInfo? incidentInfo;

  const ChatbotDialog({
    super.key,
    this.patientInfo,
    this.vitalsHistory,
    this.incidentInfo,
  });

  static void show(
    BuildContext context, {
    PatientInfo? patientInfo,
    List<VitalsEntry>? vitalsHistory,
    IncidentInfo? incidentInfo,
  }) {
    showDialog(
      context: context,
      builder: (context) => ChatbotDialog(
        patientInfo: patientInfo,
        vitalsHistory: vitalsHistory,
        incidentInfo: incidentInfo,
      ),
      barrierDismissible: true,
    );
  }

  @override
  State<ChatbotDialog> createState() => _ChatbotDialogState();
}

class _ChatbotDialogState extends State<ChatbotDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenAIService _openAIService = OpenAIService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message with context
    _messages.add(
      ChatMessage(
        text: _buildWelcomeMessage(),
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  String _buildWelcomeMessage() {
    final buffer = StringBuffer();
    buffer.write('Hello! I\'m your EMS AI assistant.');
    
    // Start building context description
    if (widget.patientInfo != null || widget.incidentInfo != null) {
      buffer.write(' You\'re currently documenting');
      
      // Add incident type if available
      if (widget.incidentInfo != null && widget.incidentInfo!.type.isNotEmpty) {
        buffer.write(' a ${widget.incidentInfo!.type.toLowerCase()} incident');
      } else {
        buffer.write(' an incident');
      }
      
      // Add patient info if available
      if (widget.patientInfo != null) {
        final patient = widget.patientInfo!;
        
        // Get sex
        String sexStr = '';
        if (patient.sex == 'M') {
          sexStr = ' on a male';
        } else if (patient.sex == 'F') {
          sexStr = ' on a female';
        } else {
          sexStr = ' on a';
        }
        
        buffer.write(sexStr);
        
        // Get age if DOB is available
        if (patient.dateOfBirth != null) {
          final age = DateTime.now().difference(patient.dateOfBirth!).inDays ~/ 365;
          buffer.write(' patient aged $age');
        } else {
          buffer.write(' patient');
        }
      }
      
      buffer.write('.');
    }
    
    buffer.write(' How can I help you today?');
    return buffer.toString();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String? _buildPatientContext() {
    if (widget.patientInfo == null && 
        (widget.vitalsHistory == null || widget.vitalsHistory!.isEmpty) &&
        widget.incidentInfo == null) {
      return null;
    }

    final buffer = StringBuffer();
    
    // Add incident information first
    if (widget.incidentInfo != null) {
      final incident = widget.incidentInfo!;
      buffer.writeln('Incident Information:');
      if (incident.type.isNotEmpty) {
        buffer.writeln('- Type: ${incident.type}');
      }
      if (incident.address.isNotEmpty) {
        buffer.writeln('- Location: ${incident.address}');
      }
      buffer.writeln('- Date: ${incident.incidentDate.toString().substring(0, 10)}');
      if (incident.arrivalAt != null) {
        buffer.writeln('- Arrival Time: ${incident.arrivalAt!.toString().substring(11, 16)}');
      }
      buffer.writeln();
    }
    
    if (widget.patientInfo != null) {
      final patient = widget.patientInfo!;
      buffer.writeln('Patient Demographics:');
      buffer.writeln('- Name: ${patient.name}');
      if (patient.dateOfBirth != null) {
        final age = DateTime.now().difference(patient.dateOfBirth!).inDays ~/ 365;
        buffer.writeln('- Age: $age years old (DOB: ${patient.dateOfBirth!.toString().substring(0, 10)})');
      }
      buffer.writeln('- Sex: ${patient.sex == "M" ? "Male" : patient.sex == "F" ? "Female" : "Unknown"}');
      if (patient.weightInPounds != null) {
        buffer.writeln('- Weight: ${patient.weightInPounds} lbs');
      }
      if (patient.heightInInches != null) {
        final feet = patient.heightInInches! ~/ 12;
        final inches = patient.heightInInches! % 12;
        buffer.writeln('- Height: $feet\' $inches"');
      }
      if (patient.chiefComplaint != null && patient.chiefComplaint!.isNotEmpty) {
        buffer.writeln('- Chief Complaint: ${patient.chiefComplaint}');
      }
      if (patient.medicalHistory.isNotEmpty) {
        buffer.writeln('- Medical History: ${patient.medicalHistory}');
      }
      if (patient.medications != null && patient.medications!.isNotEmpty) {
        buffer.writeln('- Current Medications: ${patient.medications}');
      }
      if (patient.allergies != null && patient.allergies!.isNotEmpty) {
        buffer.writeln('- Allergies: ${patient.allergies}');
      }
    }

    if (widget.vitalsHistory != null && widget.vitalsHistory!.isNotEmpty) {
      buffer.writeln('\nMost Recent Vital Signs:');
      final latest = widget.vitalsHistory!.first;
      if (latest.pulseRate != null) {
        buffer.writeln('- Heart Rate: ${latest.pulseRate} bpm');
      }
      if (latest.systolic != null && latest.diastolic != null) {
        buffer.writeln('- Blood Pressure: ${latest.systolic}/${latest.diastolic} mmHg');
      }
      if (latest.breathingRate != null) {
        buffer.writeln('- Respiratory Rate: ${latest.breathingRate} breaths/min');
      }
      if (latest.spo2 != null) {
        buffer.writeln('- SpO2: ${latest.spo2}%');
      }
      if (latest.temperature != null) {
        buffer.writeln('- Temperature: ${latest.temperature}°F');
      }
      if (latest.bloodGlucose != null) {
        buffer.writeln('- Blood Glucose: ${latest.bloodGlucose} mg/dL');
      }
      if (latest.recordedAt != null) {
        buffer.writeln('- Recorded: ${_formatVitalTime(latest.recordedAt!)}');
      }
      
      if (widget.vitalsHistory!.length > 1) {
        buffer.writeln('\nTotal vital sign readings: ${widget.vitalsHistory!.length}');
      }
    }

    return buffer.toString().trim();
  }

  String _formatVitalTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    return timestamp.toString().substring(0, 16);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final patientContext = _buildPatientContext();
      final response = await _openAIService.getEMSAssistance(
        userQuestion: message,
        patientContext: patientContext,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Sorry, I encountered an error: ${e.toString()}',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width > 800 ? size.width * 0.25 : 16,
        vertical: size.height > 600 ? 40 : 16,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.smart_toy,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Assistant',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.patientInfo != null)
                              Text(
                                'Patient: ${widget.patientInfo!.name}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onPrimary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  if (_buildPatientContext() != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.incidentInfo != null 
                                ? 'Incident & patient context active'
                                : 'Patient context active',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const _LoadingIndicator();
                  }
                  return _ChatBubble(message: _messages[index]);
                },
              ),
            ),
            
            // Input field
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask me anything about EMS...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Legacy full-page version (kept for route compatibility)
class ChatbotPage extends StatelessWidget {
  const ChatbotPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Show dialog and pop immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ChatbotDialog.show(context);
    });
    
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// Message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// Chat bubble widget
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              radius: 16,
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondary,
              radius: 16,
              child: Icon(
                Icons.person,
                size: 18,
                color: theme.colorScheme.onSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Loading indicator
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            radius: 16,
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
