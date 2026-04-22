import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;
  final Color? buttonColor;

  const ActionButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onPressed,
    this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingActionButton.small(
          onPressed: onPressed,
          heroTag: text, // Required if multiple FloatingActionButtons are on the same screen
          backgroundColor: buttonColor,
          child: Icon(icon),
        ),
        const SizedBox(height: 4.0),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
