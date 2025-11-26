class IncidentInfo {
  const IncidentInfo({
    required this.incidentDate,
    this.arrivalAt,
    required this.address,
    required this.type,
  });

  final DateTime incidentDate;
  final DateTime? arrivalAt;
  final String address;
  final String type;

  factory IncidentInfo.fromSupabaseRow(Map<String, dynamic> row) {
    return IncidentInfo(
      incidentDate: DateTime.tryParse(
                (row['incident_date'] ?? row['date']) as String? ?? '') ??
          DateTime.now(),
      arrivalAt: row['arrival_at'] != null
          ? DateTime.tryParse(row['arrival_at'] as String)
          : null,
      address:
          (row['incident_address'] ?? row['address']) as String? ?? '',
      type: (row['incident_type'] ?? row['type']) as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incident_date': _formatDate(incidentDate),
      'arrival_at': arrivalAt?.toIso8601String(),
      'address': address,
      'type': type,
    };
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class PatientInfo {
  const PatientInfo({
    this.name = '',
    this.dateOfBirth,
    this.sex = 'U',
    this.heightInInches,
    this.weightInPounds,
    this.allergies,
    this.medications,
    this.medicalHistory = '',
    this.chiefComplaint,
  });

  final String name;
  final DateTime? dateOfBirth;
  final String sex;
  final int? heightInInches;
  final int? weightInPounds;
  final String? allergies;
  final String? medications;
  final String medicalHistory;
  final String? chiefComplaint;

  factory PatientInfo.fromSupabaseRow(Map<String, dynamic> row) {
    return PatientInfo(
      name: (row['patient_name'] ?? row['name']) as String? ?? '',
      dateOfBirth:
          DateTime.tryParse(row['date_of_birth'] as String? ?? ''),
      sex: row['sex'] as String? ?? 'U',
      heightInInches: row['height_in_inches'] as int?,
      weightInPounds: row['weight_in_pounds'] as int?,
      allergies: row['allergies'] as String?,
      medications: row['medications'] as String?,
      medicalHistory: row['medical_history'] as String? ?? '',
      chiefComplaint: row['chief_complaint'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date_of_birth': dateOfBirth != null
          ? IncidentInfo._formatDate(dateOfBirth!)
          : null,
      'sex': sex,
      'height_in_inches': heightInInches,
      'weight_in_pounds': weightInPounds,
      'allergies': allergies,
      'medications': medications,
      'medical_history': medicalHistory,
      'chief_complaint': chiefComplaint,
    };
  }
}

class VitalsEntry {
  const VitalsEntry({
    this.id,
    this.pulseRate,
    this.breathingRate,
    this.systolic,
    this.diastolic,
    this.spo2,
    this.bloodGlucose,
    this.temperature,
    this.notes,
    this.recordingStartedAt,
    this.recordingEndedAt,
    this.recordedAt,
  });

  final String? id;
  final int? pulseRate;
  final int? breathingRate;
  final int? systolic;
  final int? diastolic;
  final int? spo2;
  final int? bloodGlucose;
  final int? temperature;
  final String? notes;
  final DateTime? recordingStartedAt;
  final DateTime? recordingEndedAt;
  final DateTime? recordedAt;

  factory VitalsEntry.fromSupabaseRow(Map<String, dynamic> row) {
    return VitalsEntry(
      id: row['id'] as String?,
      pulseRate: row['pulse_rate'] as int?,
      breathingRate: row['breathing_rate'] as int?,
      systolic: row['blood_pressure_systolic'] as int?,
      diastolic: row['blood_pressure_diastolic'] as int?,
      spo2: row['spo2'] as int?,
      bloodGlucose: row['blood_glucose'] as int?,
      temperature: row['temperature'] as int?,
      notes: row['notes'] as String?,
      recordingStartedAt:
          DateTime.tryParse(row['recording_started_at'] as String? ?? ''),
      recordingEndedAt:
          DateTime.tryParse(row['recording_ended_at'] as String? ?? ''),
      recordedAt: DateTime.tryParse(row['recorded_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pulse_rate': pulseRate,
      'breathing_rate': breathingRate,
      'blood_pressure_systolic': systolic,
      'blood_pressure_diastolic': diastolic,
      'spo2': spo2,
      'blood_glucose': bloodGlucose,
      'temperature': temperature,
      'notes': notes,
      'recording_started_at': recordingStartedAt?.toIso8601String(),
      'recording_ended_at': recordingEndedAt?.toIso8601String(),
      'recorded_at': recordedAt?.toIso8601String(),
    };
  }
}
