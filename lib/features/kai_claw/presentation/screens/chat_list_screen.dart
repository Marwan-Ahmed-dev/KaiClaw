import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaiclaw/features/kai_claw/presentation/providers/providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatHistory = ref.watch(chatControllerProvider).chatHistory;
    final chatController = ref.watch(chatControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Chats'),
      ),
      body: chatHistory.isEmpty
          ? const Center(child: Text('No saved chats yet.'))
          : ListView.builder(
              itemCount: chatHistory.length,
              itemBuilder: (context, index) {
                final chatName = chatHistory.keys.elementAt(index);
                final messages = chatHistory[chatName];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: ListTile(
                    title: Text(chatName),
                    subtitle: Text('Messages: ${messages?.length ?? 0}'),
                    onTap: () {
                      chatController.loadChat(chatName);
                      Navigator.pop(context); // Go back to home screen
                    },
                  ),
                );
              },
            ),
    );
  }
}
