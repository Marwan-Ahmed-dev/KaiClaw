import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart'; // Import record package
import 'package:uuid/uuid.dart';
import 'package:kaiclaw/features/kai_claw/data/datasources/kai_claw_remote_data_source.dart';
import 'package:kaiclaw/features/kai_claw/data/repositories/kai_claw_repository_impl.dart';
import 'package:kaiclaw/features/kai_claw/domain/repositories/kai_claw_repository.dart';
import 'package:kaiclaw/features/kai_claw/domain/usecases/record_audio.dart';
import 'package:kaiclaw/features/kai_claw/domain/usecases/send_command.dart';
import 'package:kaiclaw/features/kai_claw/domain/usecases/send_message.dart';
import 'package:kaiclaw/features/kai_claw/domain/usecases/upload_file.dart';
import 'package:kaiclaw/features/kai_claw/presentation/providers/chat_controller.dart';
import 'package:kaiclaw/features/kai_claw/presentation/providers/audio_recorder_controller.dart';


// Uuid for message IDs
final uuidProvider = Provider((ref) => const Uuid());

// External dependencies
final httpClientProvider = Provider((ref) => http.Client());

// Record audio instance
final audioRecorderProvider = Provider((ref) => AudioRecorder());


// Data Sources
final kaiClawRemoteDataSourceProvider = Provider<KaiClawRemoteDataSource>((ref) {
  return KaiClawRemoteDataSourceImpl(
    client: ref.watch(httpClientProvider),
    uuid: ref.watch(uuidProvider)
  );
});

// Repositories
final kaiClawRepositoryProvider = Provider<KaiClawRepository>((ref) {
  return KaiClawRepositoryImpl(remoteDataSource: ref.watch(kaiClawRemoteDataSourceProvider));
});

// Use Cases
final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(ref.watch(kaiClawRepositoryProvider));
});

final sendCommandUseCaseProvider = Provider<SendCommandUseCase>((ref) {
  return SendCommandUseCase(ref.watch(kaiClawRepositoryProvider));
});

final uploadFileUseCaseProvider = Provider<UploadFileUseCase>((ref) {
  return UploadFileUseCase(ref.watch(kaiClawRepositoryProvider));
});

final recordAudioUseCaseProvider = Provider<RecordAudioUseCase>((ref) {
  return RecordAudioUseCase(ref.watch(kaiClawRepositoryProvider));
});

// Presentation Layer - Notifiers/Controllers
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    sendMessage: ref.watch(sendMessageUseCaseProvider),
    sendCommand: ref.watch(sendCommandUseCaseProvider),
    uploadFile: ref.watch(uploadFileUseCaseProvider),
    recordAudio: ref.watch(recordAudioUseCaseProvider),
    uuid: ref.watch(uuidProvider),
  );
});

final audioRecorderControllerProvider = StateNotifierProvider<AudioRecorderController, AudioRecorderState>((ref) {
  final recorder = ref.watch(audioRecorderProvider);
  return AudioRecorderController(recorder: recorder);
});
