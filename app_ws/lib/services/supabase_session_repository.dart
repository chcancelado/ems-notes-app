import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../models/session_models.dart';
import 'agency_service.dart';
import 'session_service.dart';

class AuthRequiredException implements Exception {
  AuthRequiredException([this.message = 'No authenticated user.']);
  final String message;

  @override
  String toString() => 'AuthRequiredException: $message';
}

class SupabaseSessionRepository {
  SupabaseSessionRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final AgencyService _agencyService = AgencyService();
  String? _currentUserId;

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthRequiredException();
    }
    _currentUserId = user.id;
    return user;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  IncidentInfo _mapIncidentInfo(Map<String, dynamic> row) {
    return IncidentInfo.fromSupabaseRow(row);
  }

  PatientInfo _mapPatientInfo(Map<String, dynamic>? row) {
    if (row == null) {
      return const PatientInfo();
    }
    return PatientInfo.fromSupabaseRow(row);
  }

  VitalsEntry _mapVitals(Map<String, dynamic> row) {
    return VitalsEntry.fromSupabaseRow(row);
  }

  Session _mapSessionRow(
    Map<String, dynamic> row, {
    bool sharedWithMe = false,
    String? sharedByUserId,
  }) {
    final ownerId = row['user_id'] as String? ?? _currentUserId ?? '';
    final bool isShared =
        sharedWithMe || (_currentUserId != null && ownerId != _currentUserId);
    final session = Session(
      id: row['id'] as String,
      ownerId: ownerId,
      agencyId: row['agency_id'] as String?,
      patientName:
          (row['session_patient_info']?['patient_name'] as String?) ?? '',
      startedAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      sharedWithMe: isShared,
      sharedByUserId: sharedByUserId,
    );
    session.setIncidentInfo(_mapIncidentInfo(row));
    final patientRow = row['session_patient_info'];
    if (patientRow is Map<String, dynamic>) {
      session.setPatientInfo(_mapPatientInfo(patientRow));
    }
    final vitalsRows = row['session_vitals'];
    if (vitalsRows is List) {
      final vitals = vitalsRows
          .whereType<Map<String, dynamic>>()
          .map(_mapVitals)
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
    final agencyId = await _agencyService.getAgencyId();

    final payload = {
      'user_id': user.id,
      'agency_id': agencyId,
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
      ownerId: user.id,
      agencyId: agencyId,
    );
    session.setIncidentInfo(_mapIncidentInfo(row));
    return session;
  }

  Future<IncidentInfo> updateSession({
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

    return _mapIncidentInfo(Map<String, dynamic>.from(row));
  }

  Future<PatientInfo?> fetchPatientInfo(String sessionId) async {
    final user = _requireUser();
    final row = await _client
        .from('session_patient_info')
        .select()
        .eq('session_id', sessionId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return _mapPatientInfo(Map<String, dynamic>.from(row));
  }

  Future<PatientInfo> upsertPatientInfo({
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
      'patient_name': (name ?? '').isEmpty ? 'No Patient Name Entered' : name,
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

    return _mapPatientInfo(Map<String, dynamic>.from(row));
  }

  Future<List<VitalsEntry>> fetchVitals(String sessionId) async {
    _requireUser();
    final rows = await _client
        .from('session_vitals')
        .select()
        .eq('session_id', sessionId)
        .order('recorded_at', ascending: false);

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(_mapVitals)
        .toList();
  }

  Future<VitalsEntry> addVitals({
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

    return _mapVitals(Map<String, dynamic>.from(row));
  }

  Future<void> deleteSession(String sessionId) async {
    _requireUser();
    await _client.from('sessions').delete().eq('id', sessionId);
  }

  Future<List<AgencyMember>> fetchAgencyMembers() =>
      _agencyService.fetchMembers();

  Future<void> shareSession({
    required String sessionId,
    required String shareWithUserId,
  }) async {
    final user = _requireUser();
    await _client.from('session_shares').upsert({
      'session_id': sessionId,
      'shared_with_user_id': shareWithUserId,
      'shared_by_user_id': user.id,
    });
  }

  Future<List<Session>> fetchSessions() async {
    final user = _requireUser();
    final selectColumns = '''
      id,
      user_id,
      agency_id,
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
    ''';

    final ownRows = await _client
        .from('sessions')
        .select(selectColumns)
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final sharedRows = await _client
        .from('session_shares')
        .select('session_id, shared_by_user_id, sessions!inner($selectColumns)')
        .eq('shared_with_user_id', user.id);

    final sessions = <Session>[];
    sessions.addAll(
      (ownRows as List<dynamic>).whereType<Map<String, dynamic>>().map(
        (row) => _mapSessionRow(row, sharedWithMe: false),
      ),
    );

    for (final item in sharedRows as List<dynamic>) {
      if (item is Map<String, dynamic> &&
          item['sessions'] is Map<String, dynamic>) {
        final sRow = Map<String, dynamic>.from(item['sessions']);
        sessions.add(
          _mapSessionRow(
            sRow,
            sharedWithMe: true,
            sharedByUserId: item['shared_by_user_id'] as String?,
          ),
        );
      }
    }

    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<List<AgencyMember>> fetchSharedWith(String sessionId) async {
    final shareRows = await _client
        .from('session_shares')
        .select('shared_with_user_id')
        .eq('session_id', sessionId);
    final ids = (shareRows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((row) => row['shared_with_user_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];

    final memberRows = await _client
        .from('agency_members')
        .select('user_id, member_email, first_name, last_name')
        .inFilter('user_id', ids);

    final members = (memberRows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => AgencyMember(
            userId: row['user_id'] as String,
            email: row['member_email'] as String? ?? '',
            firstName: row['first_name'] as String?,
            lastName: row['last_name'] as String?,
          ),
        )
        .toList();

    // In case some users lack agency_members rows, include them with email fallback.
    final existingIds = members.map((m) => m.userId).toSet();
    for (final id in ids) {
      if (!existingIds.contains(id)) {
        members.add(AgencyMember(userId: id, email: ''));
      }
    }

    return members;
  }

  Future<Session?> fetchSessionDetail(String sessionId) async {
    _requireUser();
    final row = await _client
        .from('sessions')
        .select('''
          id,
          user_id,
          agency_id,
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
            recorded_at,
            recording_started_at,
            recording_ended_at
          )
        ''')
        .eq('id', sessionId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final shared =
        _currentUserId != null &&
        (row['user_id'] as String? ?? '') != _currentUserId;
    return _mapSessionRow(Map<String, dynamic>.from(row), sharedWithMe: shared);
  }
}
