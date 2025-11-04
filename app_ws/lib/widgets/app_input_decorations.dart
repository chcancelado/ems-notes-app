import 'package:flutter/material.dart';

class AppInputDecorations {
  const AppInputDecorations._();

  static const TextStyle fieldTextStyle =
      TextStyle(color: Color(0xFF5F6368), fontSize: 16);
  static const TextStyle _labelStyle =
      TextStyle(color: Color(0xFF6F6F6F), fontWeight: FontWeight.w500);
  static const TextStyle _hintStyle = TextStyle(color: Color(0xFF9E9E9E));

  static InputDecoration filledField(
    BuildContext context, {
    required String label,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    String? hintText,
    bool showLabel = true,
  }) {
    final borderRadius = BorderRadius.circular(12);
    final colorScheme = Theme.of(context).colorScheme;
    final lightBorder = BorderSide(color: Colors.grey.shade300, width: 1);

    return InputDecoration(
      labelText: showLabel ? label : null,
      labelStyle: showLabel ? _labelStyle : null,
      floatingLabelStyle: showLabel ? _labelStyle : null,
      hintText: hintText,
      hintStyle: _hintStyle,
      helperText: helperText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      floatingLabelBehavior:
          showLabel ? FloatingLabelBehavior.always : FloatingLabelBehavior.never,
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: lightBorder,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 1.5,
        ),
      ),
    );
  }
}
