import 'package:flutter/material.dart';

const Color firstAidAccentColor = Color(0xFFE57373);
const Color _firstAidBackgroundColor = Color(0xFFFFEBEE);

const Map<String, List<String>> _firstAidTips = {
  'Abdominal Pain': [
    'Allow the patient to rest in a position of comfort.',
    'Monitor for vomiting and be prepared to roll the patient onto their side.',
    'Watch for signs of shock and keep the patient warm.',
  ],
  'Allergic Reaction / Anaphylaxis': [
    'Remove the patient from the source of the allergen if it is safe.',
    'Assist with a prescribed epinephrine auto-injector when indicated.',
    'Monitor airway swelling and be ready to ventilate if breathing worsens.',
  ],
  'Altered Mental Status': [
    'Check airway, breathing, and circulation frequently.',
    'Look for medical alert tags, glucose monitors, or medications.',
    'Protect the patient from injury and prepare for rapid transport.',
  ],
  'Animal Bite / Snake Bite': [
    'Clean the wound gently and cover with a sterile dressing.',
    'Immobilize the bitten area and keep it at heart level.',
    'Capture or note the animal’s description if it is safe to do so.',
  ],
  'Chest Pain / Cardiac': [
    'Place the patient in a position of comfort and keep them calm.',
    'Assist with prescribed nitroglycerin or aspirin per protocols.',
    'Be prepared to start CPR or use an AED if cardiac arrest occurs.',
  ],
  'Dehydration': [
    'Move the patient to a cool environment and loosen restrictive clothing.',
    'Provide small sips of oral rehydration solution if the patient is alert.',
    'Monitor for signs of shock such as weak pulse or altered mental status.',
  ],
  'Diabetic Emergency (Hypo/Hyperglycemia)': [
    'Check blood glucose if equipment is available.',
    'Give oral glucose if the patient is alert and able to swallow safely.',
    'Prepare for deterioration and transport promptly if mental status worsens.',
  ],
  'Difficulty Breathing / Respiratory Distress': [
    'Place the patient in a position that eases breathing (usually upright).',
    'Administer high-flow oxygen per protocol.',
    'Assist with prescribed inhalers or nebulizers when indicated.',
  ],
  'Electrocution': [
    'Ensure the power source is shut off before approaching the patient.',
    'Assess for burns at entry and exit points and cool thermal burns.',
    'Monitor cardiac rhythm and prepare for CPR if needed.',
  ],
  'Fever / Infection / Sepsis': [
    'Remove excess clothing and keep the patient comfortably cool.',
    'Encourage oral fluids if the patient is alert and allowed.',
    'Watch for signs of sepsis such as altered mental status or low blood pressure.',
  ],
  'GI Bleed': [
    'Keep the patient calm and in a position of comfort.',
    'Do not offer anything by mouth.',
    'Monitor for shock and be prepared for rapid transport.',
  ],
  'Hazardous Materials Exposure': [
    'Ensure scene safety and use appropriate personal protective equipment.',
    'Remove contaminated clothing and brush off dry chemicals.',
    'Flush affected skin or eyes with copious water when appropriate.',
  ],
  'Heat Exhaustion / Heat Stroke': [
    'Move the patient to a shaded or cool environment immediately.',
    'Cool with fans, misting, or ice packs at the neck, armpits, and groin.',
    'Provide oral fluids if the patient is alert; prepare for rapid transport.',
  ],
  'Hypothermia / Cold Exposure': [
    'Remove wet clothing and insulate the patient from the ground.',
    'Warm the patient gradually using blankets or warm packs to the trunk.',
    'Handle gently and avoid rough movements that may trigger dysrhythmias.',
  ],
  'Nausea / Vomiting': [
    'Position the patient to prevent aspiration, preferably on their side.',
    'Offer an emesis bag and reassure the patient.',
    'Monitor for dehydration or signs of a more serious underlying condition.',
  ],
  'OB/GYN (Pregnancy / Childbirth)': [
    'Determine if delivery is imminent by assessing contractions and crowning.',
    'Prepare a clean area and necessary supplies for delivery.',
    'Support the newborn immediately after birth and keep both warm.',
  ],
  'Overdose / Poisoning': [
    'Ensure scene safety and avoid exposure to the substance.',
    'Support airway and administer oxygen as needed.',
    'Bring medication bottles or substance containers to the hospital if safe.',
  ],
  'Psychiatric / Behavioral': [
    'Maintain a calm demeanor and keep a safe distance.',
    'Remove potential weapons and limit stimulation when possible.',
    'Request law enforcement assistance if the scene becomes unsafe.',
  ],
  'Seizure': [
    'Protect the patient from injury by clearing nearby hazards.',
    'Do not restrain the patient or place anything in their mouth.',
    'After the seizure, maintain airway and place in recovery position.',
  ],
  'Stroke / CVA': [
    'Perform a FAST assessment and note the time symptoms started.',
    'Keep the patient head elevated about 30 degrees if tolerated.',
    'Avoid giving anything by mouth and prepare for rapid transport.',
  ],
  'Syncope / Fainting': [
    'Lay the patient supine and elevate the legs if no trauma is suspected.',
    'Loosen tight clothing and ensure adequate airflow.',
    'Monitor vital signs and look for underlying causes.',
  ],
  'Trauma': [
    'Control severe bleeding with direct pressure or tourniquets as needed.',
    'Stabilize suspected fractures and spinal injuries.',
    'Continuously monitor airway, breathing, and circulation.',
  ],
  'Unconscious / Unresponsive': [
    'Open the airway and check for breathing and pulse.',
    'Begin CPR if the patient is pulseless and apneic.',
    'Use airway adjuncts and ventilation support as needed.',
  ],
  'default': [
    'Ensure scene safety and use appropriate personal protective equipment.',
    'Monitor airway, breathing, and circulation continuously.',
    'Contact medical control or prepare for rapid transport as indicated.',
  ],
};

Future<void> showFirstAidDialog(BuildContext context, String incidentType) {
  final tips = _firstAidTips[incidentType] ?? _firstAidTips['default']!;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        backgroundColor: _firstAidBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'First Aid: $incidentType',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: firstAidAccentColor.darken(),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
              color: firstAidAccentColor.darken(),
              tooltip: 'Close',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tips
              .map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tip,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

extension _ColorHelpers on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final adjusted = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return adjusted.toColor();
  }
}
