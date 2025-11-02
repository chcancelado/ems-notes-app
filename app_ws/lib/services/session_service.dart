import 'dart:async';

/// Represents a patient session with associated data
class Session {
  final String id;
  final String patientName;
  final DateTime startedAt;
  final Map<String, dynamic> data;

  Session({
    required this.id,
    required this.patientName,
    DateTime? startedAt,
    Map<String, dynamic>? data,
  })  : startedAt = startedAt ?? DateTime.now(),
        data = data ?? {};

  /// Get patient info from session data
  Map<String, dynamic> get patientInfo {
    return Map<String, dynamic>.from(data['patientInfo'] ?? {});
  }

  /// Set patient info in session data
  void setPatientInfo(Map<String, dynamic> info) {
    data['patientInfo'] = Map<String, dynamic>.from(info);
  }

  /// Get vitals list from session data
  List<Map<String, dynamic>> get vitals {
    final vitalsList = data['vitals'];
    if (vitalsList is List) {
      return List<Map<String, dynamic>>.from(
        vitalsList.map((v) => Map<String, dynamic>.from(v)),
      );
    }
    return [];
  }

  /// Add vitals record to session
  void addVitals(Map<String, dynamic> vitalsData) {
    final vitalsList = data['vitals'] as List? ?? [];
    vitalsList.insert(0, Map<String, dynamic>.from(vitalsData));
    data['vitals'] = vitalsList;
  }

  /// Get chart data from session
  Map<String, dynamic> get chart {
    return Map<String, dynamic>.from(data['chart'] ?? {});
  }

  /// Set chart data in session
  void setChart(Map<String, dynamic> chartData) {
    data['chart'] = Map<String, dynamic>.from(chartData);
  }

  /// Get notes from session data
  String get notes {
    return data['notes'] as String? ?? '';
  }

  /// Set notes in session data
  void setNotes(String notesText) {
    data['notes'] = notesText;
  }

  /// Calculate elapsed time since session start
  Duration get elapsedTime {
    return DateTime.now().difference(startedAt);
  }

  /// Convert session to JSON-serializable map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientName': patientName,
      'startedAt': startedAt.toIso8601String(),
      'data': data,
    };
  }

  /// Create session from JSON map
  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      patientName: json['patientName'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

/// Service for managing in-memory session storage
class SessionService {
  final List<Session> _sessions = [];
  final StreamController<List<Session>> _sessionsController =
      StreamController<List<Session>>.broadcast();

  /// Get all sessions
  List<Session> get sessions => List.unmodifiable(_sessions);

  /// Stream of session updates
  Stream<List<Session>> get sessionsStream => _sessionsController.stream;

  /// Add a new session
  void addSession(Session session) {
    // Remove any existing session with the same ID
    _sessions.removeWhere((s) => s.id == session.id);
    
    // Add new session to the beginning of the list
    _sessions.insert(0, session);
    
    // Notify listeners
    _sessionsController.add(sessions);
  }

  /// Find a session by ID
  Session? findSessionById(String id) {
    try {
      return _sessions.firstWhere((session) => session.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Update session data
  void updateSession(String id, Map<String, dynamic> updates) {
    final session = findSessionById(id);
    if (session != null) {
      session.data.addAll(updates);
      _sessionsController.add(sessions);
    }
  }

  /// Remove a session by ID
  void removeSession(String id) {
    _sessions.removeWhere((session) => session.id == id);
    _sessionsController.add(sessions);
  }

  /// Clear all sessions
  void clearAllSessions() {
    _sessions.clear();
    _sessionsController.add(sessions);
  }

  /// Get the most recent session
  Session? get latestSession {
    if (_sessions.isEmpty) return null;
    return _sessions.first;
  }

  /// Get sessions for a specific date
  List<Session> getSessionsByDate(DateTime date) {
    return _sessions.where((session) {
      final sessionDate = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      final targetDate = DateTime(date.year, date.month, date.day);
      return sessionDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  /// Get count of active sessions
  int get sessionCount => _sessions.length;

  /// Check if a session exists
  bool hasSession(String id) {
    return _sessions.any((session) => session.id == id);
  }

  /// Dispose resources
  void dispose() {
    _sessionsController.close();
  }
}

/// Global singleton instance of SessionService
final sessionService = SessionService();
