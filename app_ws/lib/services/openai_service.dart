import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  final String _apiKey;

  OpenAIService() : _apiKey = _getApiKey();

  static String _getApiKey() {
    // Try compile-time constant first (for web/Electron builds with --dart-define)
    const fromDefine = String.fromEnvironment('OPENAI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    
    // Fall back to dotenv for local development
    return dotenv.env['OPENAI_API_KEY'] ?? '';
  }

  /// Send a message to OpenAI and get a response
  /// 
  /// [messages] - List of conversation messages with role and content
  /// [systemPrompt] - Optional system prompt to guide the AI's behavior
  Future<String> sendMessage({
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    final allMessages = <Map<String, String>>[];
    
    // Add system prompt if provided
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      allMessages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }
    
    // Add conversation messages
    allMessages.addAll(messages);

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini', // Using gpt-4o-mini for cost efficiency
          'messages': allMessages,
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        final error = jsonDecode(response.body);
        throw Exception('OpenAI API error: ${error['error']['message']}');
      }
    } catch (e) {
      throw Exception('Failed to communicate with OpenAI: $e');
    }
  }

  /// Get EMS-specific assistance
  /// This uses a specialized system prompt for medical emergency scenarios
  Future<String> getEMSAssistance({
    required String userQuestion,
    String? patientContext,
  }) async {
    final systemPrompt = '''
You are an AI assistant for Emergency Medical Technicians (EMTs) responding to active emergency scenes.

CRITICAL INSTRUCTIONS:
- Assume you are responding to an EMT on an active emergency scene
- If questions are about patient care, provide CONCISE, step-by-step instructions on what to do for the patient in that scenario
- Focus on immediate actionable steps
- Use simple, clear language appropriate for high-stress situations
- Prioritize scene safety and basic life support protocols

Your role:
- Provide quick patient care guidance (ABCs, vital signs interpretation, treatment steps)
- Help with medical terminology and documentation
- Clarify EMS protocols and procedures
- Answer general EMS knowledge questions

Important safety guidelines:
- Always remind to follow local protocols and medical direction
- Do not provide specific medical diagnoses
- Emphasize when to call for advanced life support (ALS)
- Remind to ensure scene safety first
- When uncertain, advise contacting medical control

Format responses:
- For patient care: Use numbered steps or bullet points
- Keep responses under 150 words when possible
- Focus on what to DO, not just what it is
''';

    final messages = <Map<String, String>>[];
    
    // Add patient context if available
    if (patientContext != null && patientContext.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': 'CURRENT PATIENT INFORMATION:\n$patientContext\n\nUse this information to provide contextual guidance.',
      });
    }
    
    messages.add({
      'role': 'user',
      'content': userQuestion,
    });

    return sendMessage(messages: messages, systemPrompt: systemPrompt);
  }
}
