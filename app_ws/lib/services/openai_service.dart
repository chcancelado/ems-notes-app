import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  final String _apiKey;

  OpenAIService() : _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

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
You are an AI assistant specialized in Emergency Medical Services (EMS). 
Your role is to help EMS professionals with:
- Medical terminology and procedures
- Patient assessment guidance
- Documentation assistance
- Protocol clarification
- General EMS knowledge

Important guidelines:
- Always prioritize patient safety
- Remind users to follow local protocols and medical direction
- Do not provide specific medical diagnoses
- Encourage consultation with medical control when uncertain
- Be concise and clear in emergency situations

Context: This is an EMS documentation app for first responders.
''';

    final messages = <Map<String, String>>[];
    
    // Add patient context if available
    if (patientContext != null && patientContext.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': 'Current patient context: $patientContext',
      });
    }
    
    messages.add({
      'role': 'user',
      'content': userQuestion,
    });

    return sendMessage(messages: messages, systemPrompt: systemPrompt);
  }
}
