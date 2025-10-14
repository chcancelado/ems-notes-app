import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class Session {
  final String id;
  final String patientName;
  final DateTime startedAt;
  final Map<String, dynamic> data;

  Session({required this.id, required this.patientName, DateTime? startedAt, Map<String, dynamic>? data})
      : startedAt = startedAt ?? DateTime.now(),
        data = _initializeData(data);

  factory Session.blank({required String id}) {
    return Session(id: id, patientName: '', data: null);
  }

  static Map<String, dynamic> _initializeData(Map<String, dynamic>? raw) {
    final provided = raw != null ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final patientInfoRaw = provided.remove('patient_info');
  final patientInfo = patientInfoRaw is Map
    ? Map<String, dynamic>.from(patientInfoRaw)
    : <String, dynamic>{};

    final vitalsRaw = provided.remove('vitals');
    final vitals = <Map<String, dynamic>>[];
    if (vitalsRaw is List) {
      for (final entry in vitalsRaw) {
        if (entry is Map) {
          vitals.add(Map<String, dynamic>.from(entry));
        }
      }
    }

    final chartRaw = provided.remove('chart');
    final chart = chartRaw is Map ? Map<String, dynamic>.from(chartRaw) : <String, dynamic>{};

    return {
      'patient_info': {
        'name': '',
        'age': null,
        'concern': '',
        ...patientInfo,
      },
      'vitals': vitals,
      'chart': {
        'allergies': null,
        'medications': null,
        'familyHistory': null,
        ...chart,
      },
      ...provided,
    };
  }
}

class SessionService {
  final List<Session> _sessions = [];
  final Map<String, ValueNotifier<Duration?>> _timerNotifiers = {};
  Timer? _ticker;

  List<Session> get sessions => List.unmodifiable(_sessions);

  void addSession(Session s) => _sessions.add(s);

  /// Merge keys into a session's data map.
  void updateSessionData(String id, Map<String, dynamic> updates) {
    final s = findById(id);
    if (s == null) return;
    s.data.addAll(updates);
  }

  /// Store a vitals map for the session (newest-first)
  void addSessionVitalsMap(String id, Map<String, dynamic> vitalsMap) {
    final s = findById(id);
    if (s == null) return;
    final list = (s.data['vitals'] as List<dynamic>?) ?? <dynamic>[];
    list.insert(0, vitalsMap);
    s.data['vitals'] = list;
  }

  /// Return session vitals maps (newest-first) as a typed list.
  List<Map<String, dynamic>> getSessionVitalsMaps(String id) {
    final s = findById(id);
    if (s == null) return <Map<String, dynamic>>[];
    final list = (s.data['vitals'] as List<dynamic>?) ?? <dynamic>[];
    return List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
  }

  /// Add or update chart entries for a session. Chart is stored as a map under
  /// the 'chart' key (e.g. { 'allergies': '...', 'medications': '...', 'familyHistory': '...' }).
  void setSessionChart(String id, Map<String, dynamic> chart) {
    final s = findById(id);
    if (s == null) return;
    s.data['chart'] = Map<String, dynamic>.from(chart);
  }

  /// Get chart map for a session, or empty map if none present.
  Map<String, dynamic> getSessionChart(String id) {
    final s = findById(id);
    if (s == null) return <String, dynamic>{};
    final chart = s.data['chart'] as Map<String, dynamic>?;
    return chart != null ? Map<String, dynamic>.from(chart) : <String, dynamic>{};
  }

  /// Set a session-local timer end. Stored as ISO string under 'timer_end'.
  void setSessionTimer(String id, DateTime end) {
    final s = findById(id);
    if (s == null) return;
    s.data['timer_end'] = end.toUtc().toIso8601String();
    final notifier = _timerNotifiers[id];
    if (notifier != null) {
      notifier.value = getSessionTimeLeft(id);
    }
  }

  /// Get remaining time until the session timer end.
  /// Priority: use explicit 'timer_end' stored in session.data if present
  /// (ISO string). Otherwise, fall back to computing remaining time from
  /// session.startedAt + reminderDuration. Returns null when session does
  /// not exist and Duration.zero when time has elapsed.
  Duration? getSessionTimeLeft(String id) {
    final s = findById(id);
    if (s == null) return null;

    // If an explicit timer_end was stored, use it.
    final iso = s.data['timer_end'] as String?;
    if (iso != null) {
      try {
        final end = DateTime.parse(iso).toUtc();
        final diff = end.difference(DateTime.now().toUtc());
        return diff.isNegative ? Duration.zero : diff;
      } catch (_) {
        // fall through to fallback behavior
      }
    }

    // Fallback: compute based on startedAt and configured reminderDuration.
    try {
      final elapsed = DateTime.now().difference(s.startedAt);
      final remaining = reminderDuration - elapsed;
      return remaining.isNegative ? Duration.zero : remaining;
    } catch (_) {
      return null;
    }
  }

  /// Format a Duration as MM:SS or return '--:--' when null.
  String formatDurationShort(Duration? d) {
    if (d == null) return '--:--';
    final total = d.inSeconds;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Session? findById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Subscribe to a session's remaining time. Callers should remove their
  /// listeners when the owning widget disposes; the notifier itself stays
  /// alive for the session lifespan so multiple pages can share it.
  ValueListenable<Duration?> watchSessionTimeLeft(String id) {
    final notifier = _timerNotifiers.putIfAbsent(
      id,
      () => ValueNotifier<Duration?>(getSessionTimeLeft(id)),
    );
    notifier.value = getSessionTimeLeft(id);
    _startTicker();
    return notifier;
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final expiredIds = <String>[];
      _timerNotifiers.forEach((sid, notifier) {
        final remaining = getSessionTimeLeft(sid);
        if (remaining == null) {
          expiredIds.add(sid);
          return;
        }
        if (notifier.value?.inSeconds != remaining.inSeconds) {
          notifier.value = remaining;
        }
      });
      if (expiredIds.isEmpty) return;
      for (final sid in expiredIds) {
        _timerNotifiers.remove(sid)?.dispose();
      }
      if (_timerNotifiers.isEmpty) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }
}

final sessionService = SessionService();
