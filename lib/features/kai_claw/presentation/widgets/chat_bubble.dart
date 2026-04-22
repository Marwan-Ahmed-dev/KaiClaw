import 'package:flutter/material.dart';
import 'package:kaiclaw/features/kai_claw/domain/entities/message.dart';
import 'package:intl/intl.dart'; // For date formatting

class ChatBubble extends StatelessWidget {
  final Message message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isUser ? Colors.deepPurple[200] : Colors.grey[300];
    final textColor = message.isUser ? Colors.black87 : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12.0),
            topRight: const Radius.circular(12.0),
            bottomLeft: message.isUser ? const Radius.circular(12.0) : const Radius.circular(12.0),
            bottomRight: message.isUser ? const Radius.circular(12.0) : const Radius.circular(12.0),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 16.0),
            ),
            const SizedBox(height: 4.0),
            Text(
              DateFormat('hh:mm a').format(message.timestamp),
              style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10.0),
            ),
          ],
        ),
      ),
    );
  }
}
