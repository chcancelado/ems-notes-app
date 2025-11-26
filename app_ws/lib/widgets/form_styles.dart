import 'package:flutter/material.dart';

import 'first_aid_dialog.dart';

class FormStyles {
  const FormStyles._();

  static const double maxContentWidth = 720;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(24, 32, 24, 24);
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const Size buttonMinSize = Size.fromHeight(52);
  static final RoundedRectangleBorder buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  static ButtonStyle primaryElevatedButton(BuildContext context) =>
      ElevatedButton.styleFrom(
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        shape: buttonShape,
      );

  static ButtonStyle primaryOutlinedButton(BuildContext context) =>
      OutlinedButton.styleFrom(
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        shape: buttonShape,
      );

  static ButtonStyle firstAidOutlinedButton() => OutlinedButton.styleFrom(
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        foregroundColor: firstAidAccentColor,
        backgroundColor: Colors.white,
        side: const BorderSide(
          color: firstAidAccentColor,
          width: 2,
        ),
        shape: buttonShape,
      );

  static ButtonStyle firstAidElevatedButton() => ElevatedButton.styleFrom(
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        backgroundColor: firstAidAccentColor,
        foregroundColor: Colors.white,
        shape: buttonShape,
      );
}
