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
                        ..._buildSectionLines(
                          sections[i].lines,
                          theme.textTheme.bodyMedium?.copyWith(height: 1.3),
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
                            'Summary',
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
    lines.add('Time: ${_formatTimeOnly(context, arrival)}');
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
  const defaultPatientName = 'No Patient Name Entered';
  final today = DateTime.now();
  final name = (patient['name'] as String?)?.trim() ?? '';
  if (name.isNotEmpty && name != defaultPatientName) {
    lines.add('Name: $name');
  }
  final dob = _parseDate(patient['date_of_birth']);
  final isPlaceholderDob = dob != null &&
      dob.year == today.year &&
      dob.month == today.month &&
      dob.day == today.day;
  if (dob != null && !isPlaceholderDob) {
    lines.add('DOB: ${_formatDate(dob)}');
  }
  final sex = patient['sex'] as String?;
  if (sex != null && sex.isNotEmpty && sex.toUpperCase() != 'U') {
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

  final lines = <String>[];

  for (var i = 0; i < vitals.length; i++) {
    final entry = vitals[i];
    final recordedAt =
        _parseDateTime(entry['recorded_at']) ??
        _parseDateTime(entry['recording_ended_at']) ??
        _parseDateTime(entry['recording_started_at']);
    if (recordedAt != null) {
      lines.add('Recorded: ${_formatDateTime(context, recordedAt)}');
    }

    final pulse = _asInt(entry['pulse_rate']);
    if (pulse != null) {
      lines.add('Pulse: $pulse');
    }
    final resp = _asInt(entry['breathing_rate']);
    if (resp != null) {
      lines.add('Resp: $resp');
    }
    final sys = _asInt(entry['blood_pressure_systolic']);
    final dia = _asInt(entry['blood_pressure_diastolic']);
    if (sys != null && dia != null) {
      lines.add('BP: $sys/$dia');
    }
    final spo2 = _asInt(entry['spo2']);
    if (spo2 != null) {
      lines.add('SpO2: $spo2%');
    }
    final glucose = _asInt(entry['blood_glucose']);
    if (glucose != null) {
      lines.add('Glucose: $glucose');
    }
    final temperature = _asInt(entry['temperature']);
    if (temperature != null) {
      lines.add('Temp: $temperature°F');
    }
    final notes = entry['notes'] as String?;
    if (notes != null && notes.isNotEmpty) {
      lines.add('Notes: $notes');
    }

    if (entry['isDraft'] == true) {
      lines.add('Status: Unsaved');
    }

    if (i < vitals.length - 1) {
      lines.add('');
    }
  }

  return lines;
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

String _formatTimeOnly(BuildContext context, DateTime dateTime) {
  final local = dateTime.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
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
  if (height == null || height <= 1) {
    return null;
  }
  final feet = height ~/ 12;
  final inches = height % 12;
  return '$feet\' $inches" ($height in)';
}

String? _formatWeight(dynamic value) {
  final weight = _asInt(value);
  if (weight == null || weight <= 1) {
    return null;
  }
  return '$weight lbs';
}

List<Widget> _buildSectionLines(List<String> lines, TextStyle? baseStyle) {
  return [
    for (var i = 0; i < lines.length; i++) ...[
      _buildUnderlinedLabelLine(lines[i], baseStyle),
      if (i < lines.length - 1) const SizedBox(height: 6),
    ],
  ];
}

Widget _buildUnderlinedLabelLine(String line, TextStyle? baseStyle) {
  final colonIndex = line.indexOf(':');
  if (colonIndex <= 0) {
    return SelectableText(line, style: baseStyle);
  }
  final label = line.substring(0, colonIndex);
  final remainder = line.substring(colonIndex);
  final labelStyle = baseStyle?.copyWith(
    decoration: TextDecoration.underline,
  );

  return SelectableText.rich(
    TextSpan(
      children: [
        TextSpan(text: label, style: labelStyle),
        TextSpan(text: remainder, style: baseStyle),
      ],
    ),
  );
}

class _SummarySectionData {
  const _SummarySectionData(this.title, this.lines);

  final String title;
  final List<String> lines;
}
