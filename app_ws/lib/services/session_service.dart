class Session {
  final String id;
  final String patientName;
  final DateTime startedAt;
  final Map<String, dynamic> data;

  Session({required this.id, required this.patientName, DateTime? startedAt, Map<String, dynamic>? data})
      : startedAt = startedAt ?? DateTime.now(),
        data = data ?? {};
}

class SessionService {
  final List<Session> _sessions = [];

  List<Session> get sessions => List.unmodifiable(_sessions);

  void addSession(Session s) => _sessions.add(s);

  Session? findById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

final sessionService = SessionService();
