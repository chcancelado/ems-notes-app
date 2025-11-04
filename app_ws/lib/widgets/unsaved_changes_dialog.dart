import 'package:flutter/material.dart';

Future<bool> showUnsavedChangesDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard Changes?'),
      content: const Text(
        'Any information entered on this page will be lost if you leave. '
        'Do you want to continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return result ?? false;
}

