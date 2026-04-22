import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaiclaw/features/kai_claw/domain/entities/message.dart';
import 'package:kaiclaw/features/kai_claw/presentation/providers/audio_recorder_controller.dart';
import 'package:kaiclaw/features/kai_claw/presentation/providers/chat_controller.dart';
import 'package:kaiclaw/features/kai_claw/presentation/providers/providers.dart';
import 'package:kaiclaw/features/kai_claw/presentation/screens/chat_list_screen.dart';
import 'package:kaiclaw/features/kai_claw/presentation/screens/settings_screen.dart';
import 'package:kaiclaw/features/kai_claw/presentation/widgets/action_button.dart';
import 'package:kaiclaw/features/kai_claw/presentation/widgets/chat_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // Request necessary permissions (storage, microphone)
  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    // For older Android versions, storage permission might be needed for file_picker
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      ref.read(chatControllerProvider.notifier).sendChatMessage(text);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;
      if (file.bytes != null) {
        ref.read(chatControllerProvider.notifier).handleFileUpload(
              file.name,
              file.bytes!.toList(),
            );
      } else if (file.path != null) {
        // Fallback for larger files where bytes are not immediately available
        // on some platforms (e.g., web or desktop) or for memory efficiency.
        // Needs a different approach for sending, e.g., streaming or reading from path.
        // For simplicity, we'll read bytes if path is available.
        final File pickedFile = File(file.path!);
        final bytes = await pickedFile.readAsBytes();
         ref.read(chatControllerProvider.notifier).handleFileUpload(
              file.name,
              bytes.toList(),
            );
      }
    } else {
      print('User canceled the file picker');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء اختيار الملف.')),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    final audioRecorderState = ref.read(audioRecorderControllerProvider);
    final audioRecorderController = ref.read(audioRecorderControllerProvider.notifier);
    final chatController = ref.read(chatControllerProvider.notifier);

    if (audioRecorderController.isRecording()) {
      final path = await audioRecorderController.stopRecording();
      if (path != null) {
        await chatController.handleAudioRecordingUpload(path);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل إيقاف التسجيل أو حفظه.')),
          );
        }
      }
    } else {
      await audioRecorderController.startRecording();
      if (audioRecorderController.state.recordingState == RecordingState.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في التسجيل: ${audioRecorderController.state.errorMessage}')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    ref.read(audioRecorderProvider).dispose(); // Dispose the audio recorder
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final audioRecorderState = ref.watch(audioRecorderControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KaiClaw Control Pad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(chatControllerProvider.notifier).performCommand('redeploy'),
            tooltip: 'Redeploy KaiClaw',
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: () => ref.read(chatControllerProvider.notifier).performCommand('restart'),
            tooltip: 'Restart KaiClaw',
          ),
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () => ref.read(chatControllerProvider.notifier).startNewChat(),
            tooltip: 'Start New Chat',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Text(
                'KaiClaw Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chats'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            // Add more menu items here, e.g., for Skill Management, Logs
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final message = chatState.messages[index];
                return ChatBubble(message: message);
              },
            ),
          ),
          if (chatState.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          if (chatState.error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Error: ${chatState.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ActionButton(
                      icon: Icons.upload_file,
                      text: 'Upload File',
                      onPressed: _pickFile,
                    ),
                    ActionButton(
                      icon: audioRecorderState.isRecording() ? Icons.stop : Icons.mic,
                      text: audioRecorderState.isRecording() ? 'Stop Recording' : 'Record Audio',
                      onPressed: _toggleRecording,
                      buttonColor: audioRecorderState.isRecording() ? Colors.red : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'أرسل رسالة إلى KaiClaw...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    FloatingActionButton(
                      onPressed: _sendMessage,
                      mini: true,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
