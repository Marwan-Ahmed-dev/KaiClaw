import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaiclaw/features/kai_claw/domain/entities/message.dart';
import 'package:kaiclaw/features/kai_claw/domain/usecases/record_audio.dart';
import 'package:kaiclaw/features/kai_claw/domain/usecases/send_command.dart';
import 'package:kaiclaw/features/kai_claw/domain/usecases/send_message.dart';
import 'package:kaiclaw/features/kai_claw/domain/usecases/upload_file.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

// State definition
class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final Map<String, List<Message>> chatHistory; // For multiple chats feature

  ChatState({required this.messages, this.isLoading = false, this.error, Map<String, List<Message>>? chatHistory})
      : chatHistory = chatHistory ?? {};

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    Map<String, List<Message>>? chatHistory,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      chatHistory: chatHistory ?? this.chatHistory,
    );
  }
}

// Controller/Notifier
class ChatController extends StateNotifier<ChatState> {
  final SendMessageUseCase sendMessage;
  final SendCommandUseCase sendCommand;
  final UploadFileUseCase uploadFile;
  final RecordAudioUseCase recordAudio;
  final Uuid uuid;

  ChatController({
    required this.sendMessage,
    required this.sendCommand,
    required this.uploadFile,
    required this.recordAudio,
    required this.uuid,
  }) : super(ChatState(messages: []));

  Future<void> sendChatMessage(String text) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final userMessage = Message(
      id: uuid.v4(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, userMessage]);

    final result = await sendMessage(text);
    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        _addBotMessage("حدث خطأ عند إرسال الرسالة: ${failure.message}");
      },
      (botResponse) {
        state = state.copyWith(isLoading: false);
        _addBotMessage(botResponse.text);
      },
    );
  }

  void _addBotMessage(String text) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        Message( // Simulate bot response
          id: uuid.v4(),
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  Future<void> performCommand(String command) async {
    state = state.copyWith(isLoading: true, error: null);
    _addBotMessage("جارٍ تنفيذ الأمر: $command..."); // Optimistic update
    final result = await sendCommand(command);
    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        _addBotMessage("فشل تنفيذ الأمر: ${failure.message}");
      },
      (_) {
        state = state.copyWith(isLoading: false);
        _addBotMessage("تم تنفيذ الأمر $command بنجاح.");
      },
    );
  }

  Future<void> handleFileUpload(String fileName, List<int> bytes) async {
    state = state.copyWith(isLoading: true, error: null);
    _addBotMessage("جارٍ رفع الملف: $fileName..."); // Optimistic update

    final result = await uploadFile(UploadFileParams(fileName: fileName, bytes: bytes));
    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        _addBotMessage("فشل رفع الملف: ${failure.message}");
      },
      (_) {
        state = state.copyWith(isLoading: false);
        _addBotMessage("تم رفع الملف $fileName بنجاح.");
        // Optionally, could add a message with a link to the uploaded file if webhook supports
      },
    );
  }

  Future<void> handleAudioRecordingUpload(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final fileName = filePath.split('/').last;
    final audioFile = File(filePath);
    final bytes = await audioFile.readAsBytes();

    _addBotMessage("جارٍ رفع التسجيل الصوتي: $fileName..."); // Optimistic update

    final result = await recordAudio(RecordAudioParams(fileName: fileName, bytes: bytes));
    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        _addBotMessage("فشل رفع التسجيل الصوتي: ${failure.message}");
      },
      (_) {
        state = state.copyWith(isLoading: false);
        _addBotMessage("تم رفع التسجيل الصوتي $fileName بنجاح.");
      },
    );
  }

  void startNewChat() {
    // Save current chat before starting a new one (placeholder logic)
    if (state.messages.isNotEmpty) {
      final chatName = "Chat ${state.chatHistory.length + 1}"; // Basic naming
      state = state.copyWith(chatHistory: {...state.chatHistory, chatName: state.messages});
    }

    state = ChatState(messages: []);
    _addBotMessage("بدأت محادثة جديدة. كيف يمكنني مساعدتك؟");
  }

  // Placeholder for switching between chats
  void loadChat(String chatName) {
    if (state.chatHistory.containsKey(chatName)) {
      state = state.copyWith(messages: state.chatHistory[chatName], error: null, isLoading: false);
      _addBotMessage("تم تحميل المحادثة: $chatName");
    } else {
      _addBotMessage("المحادثة '$chatName' غير موجودة.");
    }
  }
}
