import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'session_service.dart';

class SupabaseSessionRepository {
  SupabaseSessionRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    return user;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, dynamic> _buildIncidentInfo(Map<String, dynamic> row) {
    return {
      'incident_date': row['incident_date'],
      'arrival_at': row['arrival_at'],
      'address': row['incident_address'],
      'type': row['incident_type'],
    };
  }

  Map<String, dynamic> _buildPatientInfo(Map<String, dynamic>? row) {
    if (row == null) {
      return {};
    }
    return {
      'name': row['patient_name'] ?? '',
      'date_of_birth': row['date_of_birth'],
      'sex': row['sex'],
      'height_in_inches': row['height_in_inches'],
      'weight_in_pounds': row['weight_in_pounds'],
      'allergies': row['allergies'],
      'medications': row['medications'],
      'medical_history': row['medical_history'] as String? ?? '',
      'chief_complaint': row['chief_complaint'],
    };
  }

  Map<String, dynamic> _buildVitals(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'pulse_rate': row['pulse_rate'],
      'breathing_rate': row['breathing_rate'],
      'blood_pressure_systolic': row['blood_pressure_systolic'],
      'blood_pressure_diastolic': row['blood_pressure_diastolic'],
      'spo2': row['spo2'],
      'blood_glucose': row['blood_glucose'],
      'temperature': row['temperature'],
      'notes': row['notes'],
      'recording_started_at': row['recording_started_at'],
      'recording_ended_at': row['recording_ended_at'],
      'recorded_at': row['recorded_at'],
    };
  }

  Session _mapSessionRow(Map<String, dynamic> row) {
    final session = Session(
      id: row['id'] as String,
      patientName:
          (row['session_patient_info']?['patient_name'] as String?) ?? '',
      startedAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
    session.setIncidentInfo(_buildIncidentInfo(row));
    final patientRow = row['session_patient_info'];
    if (patientRow is Map<String, dynamic>) {
      session.setPatientInfo(_buildPatientInfo(patientRow));
    }
    final vitalsRows = row['session_vitals'];
    if (vitalsRows is List) {
      final vitals = vitalsRows
          .whereType<Map<String, dynamic>>()
          .map(_buildVitals)
          .toList();
      session.setVitals(vitals);
    }
    return session;
  }

  Future<Session> createSession({
    required DateTime incidentDate,
    DateTime? arrivalAt,
    required String address,
    required String type,
  }) async {
    final user = _requireUser();

    final payload = {
      'user_id': user.id,
      'incident_date': _formatDate(incidentDate),
      if (arrivalAt != null) 'arrival_at': arrivalAt.toIso8601String(),
      'incident_address': address,
      'incident_type': type,
    };

    final row = await _client
        .from('sessions')
        .insert(payload)
        .select()
        .single();

    final session = Session(
      id: row['id'] as String,
      startedAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
    session.setIncidentInfo(_buildIncidentInfo(row));
    return session;
  }

  Future<Map<String, dynamic>> updateSession({
    required String sessionId,
    required DateTime incidentDate,
    DateTime? arrivalAt,
    required String address,
    required String type,
  }) async {
    _requireUser();

    final payload = {
      'incident_date': _formatDate(incidentDate),
      'incident_address': address,
      'incident_type': type,
      'arrival_at': arrivalAt?.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await _client
        .from('sessions')
        .update(payload)
        .eq('id', sessionId)
        .select()
        .maybeSingle();

    if (row == null) {
      throw StateError('Session not found for update.');
    }

    return _buildIncidentInfo(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>?> fetchPatientInfo(String sessionId) async {
    final user = _requireUser();
    final row = await _client
        .from('session_patient_info')
        .select()
        .eq('session_id', sessionId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return _buildPatientInfo(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>> upsertPatientInfo({
    required String sessionId,
    String? name,
    DateTime? dateOfBirth,
    String sex = 'U',
    int? heightInInches,
    int? weightInPounds,
    String? allergies,
    String? medications,
    String? medicalHistory,
    String? chiefComplaint,
  }) async {
    _requireUser();
    final fallbackDate = dateOfBirth ?? DateTime.now();
    final safeHeight = (heightInInches ?? 1) > 0 ? (heightInInches ?? 1) : 1;
    final safeWeight = (weightInPounds ?? 1) > 0 ? (weightInPounds ?? 1) : 1;
    final payload = {
      'session_id': sessionId,
      'patient_name':
          (name ?? '').isEmpty ? 'No Patient Name Entered' : name,
      'date_of_birth': _formatDate(fallbackDate),
      'sex': (sex.isEmpty ? 'U' : sex),
      'height_in_inches': safeHeight,
      'weight_in_pounds': safeWeight,
      'allergies': (allergies ?? '').isEmpty ? null : allergies,
      'medications': (medications ?? '').isEmpty ? null : medications,
      'medical_history': medicalHistory ?? '',
      'chief_complaint': (chiefComplaint ?? '').isEmpty
          ? 'Unknown'
          : chiefComplaint,
    };

    final row = await _client
        .from('session_patient_info')
        .upsert(payload)
        .select()
        .single();

    return _buildPatientInfo(Map<String, dynamic>.from(row));
  }

  Future<List<Map<String, dynamic>>> fetchVitals(String sessionId) async {
    _requireUser();
    final rows = await _client
        .from('session_vitals')
        .select()
        .eq('session_id', sessionId)
        .order('recorded_at', ascending: false);

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(_buildVitals)
        .toList();
  }

  Future<Map<String, dynamic>> addVitals({
    required String sessionId,
    int? pulseRate,
    int? breathingRate,
    int? systolic,
    int? diastolic,
    int? spo2,
    int? bloodGlucose,
    int? temperature,
    String? notes,
    DateTime? recordingStartedAt,
    DateTime? recordingEndedAt,
  }) async {
    _requireUser();

    final payload = {
      'session_id': sessionId,
      'pulse_rate': pulseRate,
      'breathing_rate': breathingRate,
      'blood_pressure_systolic': systolic,
      'blood_pressure_diastolic': diastolic,
      'spo2': spo2,
      'blood_glucose': bloodGlucose,
      'temperature': temperature,
      'notes': notes?.isEmpty ?? true ? null : notes,
      if (recordingStartedAt != null)
        'recording_started_at': recordingStartedAt.toIso8601String(),
      if (recordingEndedAt != null)
        'recording_ended_at': recordingEndedAt.toIso8601String(),
    };

    final row = await _client
        .from('session_vitals')
        .insert(payload)
        .select()
        .single();

    return _buildVitals(Map<String, dynamic>.from(row));
  }

  Future<void> deleteSession(String sessionId) async {
    _requireUser();
    await _client.from('sessions').delete().eq('id', sessionId);
  }

  Future<List<Session>> fetchSessions() async {
    final user = _requireUser();

    final rows = await _client
        .from('sessions')
        .select('''
          id,
          incident_date,
          arrival_at,
          incident_address,
          incident_type,
          created_at,
          session_patient_info (
            patient_name,
            date_of_birth,
            sex,
            height_in_inches,
            weight_in_pounds,
            allergies,
            medications,
            medical_history,
            chief_complaint
          )
        ''')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(_mapSessionRow)
        .toList();
  }

  Future<Session?> fetchSessionDetail(String sessionId) async {
    final user = _requireUser();
    final row = await _client
        .from('sessions')
        .select('''
          id,
          incident_date,
          arrival_at,
          incident_address,
          incident_type,
          created_at,
          session_patient_info (
            patient_name,
            date_of_birth,
            sex,
            height_in_inches,
            weight_in_pounds,
            allergies,
            medications,
            medical_history,
            chief_complaint
          ),
          session_vitals (
            id,
            pulse_rate,
            breathing_rate,
            blood_pressure_systolic,
            blood_pressure_diastolic,
            spo2,
            blood_glucose,
            temperature,
            notes,
            recorded_at
          )
        ''')
        .eq('user_id', user.id)
        .eq('id', sessionId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return _mapSessionRow(Map<String, dynamic>.from(row));
  }
}
