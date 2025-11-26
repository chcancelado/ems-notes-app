import 'dart:async';

/// Represents a patient session with associated data
class Session {
  final String id;
  String patientName;
  final DateTime startedAt;
  final Map<String, dynamic> data;

  Session({
    required this.id,
    String? patientName,
    DateTime? startedAt,
    Map<String, dynamic>? data,
  }) : patientName = patientName ?? '',
       startedAt = startedAt ?? DateTime.now(),
       data = data ?? {};

  /// Get incident info captured for this session
  Map<String, dynamic> get incidentInfo {
    return Map<String, dynamic>.from(data['incident'] ?? {});
  }

  /// Set the current incident information
  void setIncidentInfo(Map<String, dynamic> info) {
    data['incident'] = Map<String, dynamic>.from(info);
  }

  /// Get patient info from session data
  Map<String, dynamic> get patientInfo {
    final info = Map<String, dynamic>.from(data['patientInfo'] ?? {});
    final history = info['medical_history'];
    if (history is List) {
      info['medical_history'] = history
          .map((entry) => entry.toString())
          .join(', ');
    }
    return info;
  }

  /// Set patient info in session data
  void setPatientInfo(Map<String, dynamic> info) {
    final copy = Map<String, dynamic>.from(info);
    final history = copy['medical_history'];
    if (history is List) {
      copy['medical_history'] = history
          .map((entry) => entry.toString())
          .join(', ');
    }
    data['patientInfo'] = copy;
    final name = copy['name'] as String?;
    if (name != null && name.isNotEmpty) {
      patientName = name;
    }
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

  /// Replace vitals list with the provided records
  void setVitals(List<Map<String, dynamic>> vitalsEntries) {
    data['vitals'] = vitalsEntries
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  /// Add vitals record to session
  void addVitals(Map<String, dynamic> vitalsData) {
    final vitalsList = List<Map<String, dynamic>>.from(vitals);
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
      patientName: json['patientName'] as String?,
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

  /// Add or replace a session
  void addSession(Session session) {
    upsertSession(session);
  }

  /// Upsert session preserving ordering (new sessions appear first)
  void upsertSession(Session session) {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.insert(0, session);
    }
    _sortByRecency();
    _sessionsController.add(sessions);
  }

  /// Replace the entire session collection
  void replaceSessions(List<Session> sessions) {
    _sessions
      ..clear()
      ..addAll(sessions);
    _sortByRecency();
    _sessionsController.add(this.sessions);
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

  /// Update session incident details
  void updateIncidentInfo(String id, Map<String, dynamic> info) {
    final session = findSessionById(id);
    if (session != null) {
      session.setIncidentInfo(info);
      _sessionsController.add(sessions);
    }
  }

  /// Update patient details for a session
  void updatePatientInfo(String id, Map<String, dynamic> info) {
    final session = findSessionById(id);
    if (session != null) {
      session.setPatientInfo(info);
      _sessionsController.add(sessions);
    }
  }

  /// Replace all vitals for a session
  void replaceVitals(String id, List<Map<String, dynamic>> vitals) {
    final session = findSessionById(id);
    if (session != null) {
      session.setVitals(vitals);
      _sessionsController.add(sessions);
    }
  }

  /// Append a vitals entry for the provided session
  void addVitalsEntry(String id, Map<String, dynamic> vitals) {
    final session = findSessionById(id);
    if (session != null) {
      session.addVitals(vitals);
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

  void _sortByRecency() {
    _sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
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
