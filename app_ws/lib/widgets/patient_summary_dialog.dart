import 'package:flutter/material.dart';

import '../services/session_service.dart';

Future<void> showPatientSummaryDialog(
  BuildContext context, {
  Session? session,
  Map<String, dynamic>? incidentDraft,
  Map<String, dynamic>? patientDraft,
  List<Map<String, dynamic>>? vitalsDraft,
  Map<String, dynamic>? chartDraft,
  String? notesDraft,
}) async {
  final sections = _buildSummarySections(
    context,
    session: session,
    incidentDraft: incidentDraft,
    patientDraft: patientDraft,
    vitalsDraft: vitalsDraft,
    chartDraft: chartDraft,
    notesDraft: notesDraft,
  );

  final hasDraftData =
      (incidentDraft?.isNotEmpty ?? false) ||
      (patientDraft?.isNotEmpty ?? false) ||
      (vitalsDraft?.isNotEmpty ?? false) ||
      (chartDraft?.isNotEmpty ?? false) ||
      (notesDraft != null);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    useSafeArea: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final size = MediaQuery.of(dialogContext).size;
      final bool hasSidebar = size.width >= 900;
      final double widthFactor = hasSidebar ? 0.5 : 0.92;
      final double desiredWidth = (size.width * widthFactor).clamp(
        280.0,
        720.0,
      );
      final double maxDialogHeight = (size.height * 0.9).clamp(240.0, 1200.0);
      final double maxContentHeight = (maxDialogHeight - 120).clamp(
        160.0,
        maxDialogHeight,
      );
      final scrollController = ScrollController();

      final sectionsContent = sections.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No patient data to display yet.')),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < sections.length; i++) ...[
                        Text(
                          sections[i].title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          sections[i].lines.join('\n'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.3,
                          ),
                        ),
                        if (i < sections.length - 1)
                          const Divider(height: 32, thickness: 1),
                      ],
                    ],
                  ),
                ),
              ),
            );

      return SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: desiredWidth,
              minWidth: 280,
              maxHeight: maxDialogHeight,
            ),
            child: Material(
              elevation: 12,
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Patient Summary',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close summary',
                        ),
                      ],
                    ),
                  ),
                  if (hasDraftData)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Includes the latest saved data plus any current edits.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  sectionsContent,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

List<_SummarySectionData> _buildSummarySections(
  BuildContext context, {
  Session? session,
  Map<String, dynamic>? incidentDraft,
  Map<String, dynamic>? patientDraft,
  List<Map<String, dynamic>>? vitalsDraft,
  Map<String, dynamic>? chartDraft,
  String? notesDraft,
}) {
  final sections = <_SummarySectionData>[];

  if (session != null) {
    final sessionLines = <String>[
      'Session ID: ${session.id}',
      'Started: ${_formatDateTime(context, session.startedAt)}',
      if (session.patientName.isNotEmpty)
        'Session Patient Name: ${session.patientName}',
    ];
    sections.add(_SummarySectionData('Session', sessionLines));
  }

  final incident = _mergeData(session?.incidentInfo, incidentDraft);
  final incidentLines = _buildIncidentLines(context, incident);
  if (incidentLines.isNotEmpty) {
    sections.add(_SummarySectionData('Incident', incidentLines));
  }

  final patient = _mergeData(session?.patientInfo, patientDraft);
  final patientLines = _buildPatientLines(context, patient);
  if (patientLines.isNotEmpty) {
    sections.add(_SummarySectionData('Patient', patientLines));
  }

  final vitals = <Map<String, dynamic>>[...?session?.vitals];
  if (vitalsDraft != null) {
    vitals.insertAll(0, vitalsDraft);
  }
  final vitalsLines = _buildVitalsLines(context, vitals);
  if (vitalsLines.isNotEmpty) {
    sections.add(_SummarySectionData('Vitals', vitalsLines));
  }

  final chart = _mergeData(session?.chart, chartDraft);
  final chartLines = _buildChartLines(context, chart);
  if (chartLines.isNotEmpty) {
    sections.add(_SummarySectionData('Chart', chartLines));
  }

  final notes = notesDraft ?? session?.notes ?? '';
  if (notes.trim().isNotEmpty) {
    sections.add(_SummarySectionData('Notes', [notes.trim()]));
  }

  return sections;
}

Map<String, dynamic> _mergeData(
  Map<String, dynamic>? base,
  Map<String, dynamic>? overrides,
) {
  final result = <String, dynamic>{};
  if (base != null) {
    result.addAll(base);
  }
  if (overrides != null) {
    overrides.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is String && value.trim().isEmpty) {
        return;
      }
      result[key] = value;
    });
  }
  return result;
}

List<String> _buildIncidentLines(
  BuildContext context,
  Map<String, dynamic> incident,
) {
  if (incident.isEmpty) {
    return const [];
  }
  final lines = <String>[];
  final type = incident['type'] as String?;
  if (type != null && type.isNotEmpty) {
    lines.add('Type: $type');
  }
  final incidentDate = _parseDate(incident['incident_date']);
  if (incidentDate != null) {
    lines.add('Date: ${_formatDate(incidentDate)}');
  }
  final arrival = _parseDateTime(incident['arrival_at']);
  if (arrival != null) {
    lines.add('Arrival: ${_formatDateTime(context, arrival)}');
  }
  final address = incident['address'] as String?;
  if (address != null && address.isNotEmpty) {
    lines.add('Address: $address');
  }
  return lines;
}

List<String> _buildPatientLines(
  BuildContext context,
  Map<String, dynamic> patient,
) {
  if (patient.isEmpty) {
    return const [];
  }
  final lines = <String>[];
  final name = patient['name'] as String?;
  if (name != null && name.isNotEmpty) {
    lines.add('Name: $name');
  }
  final dob = _parseDate(patient['date_of_birth']);
  if (dob != null) {
    lines.add('DOB: ${_formatDate(dob)}');
  }
  final sex = patient['sex'] as String?;
  if (sex != null && sex.isNotEmpty) {
    lines.add('Sex: ${_describeSex(sex)}');
  }
  final heightLine = _formatHeight(patient['height_in_inches']);
  if (heightLine != null) {
    lines.add('Height: $heightLine');
  }
  final weightLine = _formatWeight(patient['weight_in_pounds']);
  if (weightLine != null) {
    lines.add('Weight: $weightLine');
  }
  final allergies = patient['allergies'] as String?;
  if (allergies != null && allergies.isNotEmpty) {
    lines.add('Allergies: $allergies');
  }
  final medications = patient['medications'] as String?;
  if (medications != null && medications.isNotEmpty) {
    lines.add('Medications: $medications');
  }
  final history = patient['medical_history'] as String?;
  if (history != null && history.isNotEmpty) {
    lines.add('Medical history: $history');
  }
  final complaint = patient['chief_complaint'] as String?;
  if (complaint != null && complaint.isNotEmpty) {
    lines.add('Chief complaint: $complaint');
  }
  return lines;
}

List<String> _buildVitalsLines(
  BuildContext context,
  List<Map<String, dynamic>> vitals,
) {
  if (vitals.isEmpty) {
    return const [];
  }

  return vitals.map((entry) {
    final parts = <String>[];
    final recordedAt =
        _parseDateTime(entry['recorded_at']) ??
        _parseDateTime(entry['recording_ended_at']) ??
        _parseDateTime(entry['recording_started_at']);
    if (recordedAt != null) {
      parts.add(_formatDateTime(context, recordedAt));
    }

    final pulse = _asInt(entry['pulse_rate']);
    if (pulse != null) {
      parts.add('Pulse $pulse');
    }
    final resp = _asInt(entry['breathing_rate']);
    if (resp != null) {
      parts.add('Resp $resp');
    }
    final sys = _asInt(entry['blood_pressure_systolic']);
    final dia = _asInt(entry['blood_pressure_diastolic']);
    if (sys != null && dia != null) {
      parts.add('BP $sys/$dia');
    }
    final spo2 = _asInt(entry['spo2']);
    if (spo2 != null) {
      parts.add('SpO2 $spo2%');
    }
    final glucose = _asInt(entry['blood_glucose']);
    if (glucose != null) {
      parts.add('Glucose $glucose');
    }
    final temperature = _asInt(entry['temperature']);
    if (temperature != null) {
      parts.add('Temp $temperature°F');
    }
    final notes = entry['notes'] as String?;
    if (notes != null && notes.isNotEmpty) {
      parts.add('Notes: $notes');
    }

    if (entry['isDraft'] == true) {
      parts.add('[Unsaved]');
    }

    return parts.isEmpty ? 'Vitals entry' : parts.join(' | ');
  }).toList();
}

List<String> _buildChartLines(
  BuildContext context,
  Map<String, dynamic> chart,
) {
  if (chart.isEmpty) {
    return const [];
  }
  final lines = <String>[];
  final allergies = chart['allergies'] as String?;
  if (allergies != null && allergies.isNotEmpty) {
    lines.add('Allergies: $allergies');
  }
  final medications = chart['medications'] as String?;
  if (medications != null && medications.isNotEmpty) {
    lines.add('Medications: $medications');
  }
  final familyHistory =
      chart['familyHistory'] as String? ?? chart['family_history'] as String?;
  if (familyHistory != null && familyHistory.isNotEmpty) {
    lines.add('Family history: $familyHistory');
  }
  final updatedAt = _parseDateTime(chart['lastUpdated'] ?? chart['updated_at']);
  if (updatedAt != null) {
    lines.add('Last updated: ${_formatDateTime(context, updatedAt)}');
  }
  return lines;
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final year = local.year.toString().padLeft(4, '0');
  return '$month/$day/$year';
}

String _formatDateTime(BuildContext context, DateTime dateTime) {
  final local = dateTime.toLocal();
  final time = TimeOfDay.fromDateTime(local).format(context);
  return '${_formatDate(local)} $time';
}

String _describeSex(String code) {
  switch (code.toUpperCase()) {
    case 'M':
      return 'Male';
    case 'F':
      return 'Female';
    case 'O':
      return 'Other';
    case 'U':
    default:
      return 'Unknown';
  }
}

String? _formatHeight(dynamic value) {
  final height = _asInt(value);
  if (height == null || height <= 0) {
    return null;
  }
  final feet = height ~/ 12;
  final inches = height % 12;
  return '${feet}\' ${inches}" ($height in)';
}

String? _formatWeight(dynamic value) {
  final weight = _asInt(value);
  if (weight == null || weight <= 0) {
    return null;
  }
  return '$weight lbs';
}

class _SummarySectionData {
  const _SummarySectionData(this.title, this.lines);

  final String title;
  final List<String> lines;
}
