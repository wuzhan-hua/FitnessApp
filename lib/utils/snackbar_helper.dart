import 'package:flutter/material.dart';

void showLatestSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(content: Text(message), duration: duration));
}
