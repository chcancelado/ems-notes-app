import '../../services/session_service.dart';

class ChartController {
  /// Save chart for a session
  void saveSessionChart(String sessionId, Map<String, dynamic> chart) {
    sessionService.setSessionChart(sessionId, chart);
  }

  Map<String, dynamic> loadSessionChart(String sessionId) {
    return sessionService.getSessionChart(sessionId);
  }
}

