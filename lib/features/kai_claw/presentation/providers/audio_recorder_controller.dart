import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum RecordingState { initial, recording, stopped, error }

class AudioRecorderState {
  final RecordingState recordingState;
  final String? filePath;
  final String? errorMessage;

  AudioRecorderState({
    required this.recordingState,
    this.filePath,
    this.errorMessage,
  });

  AudioRecorderState copyWith({
    RecordingState? recordingState,
    String? filePath,
    String? errorMessage,
  }) {
    return AudioRecorderState(
      recordingState: recordingState ?? this.recordingState,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage,
    );
  }
}

class AudioRecorderController extends StateNotifier<AudioRecorderState> {
  final AudioRecorder recorder;

  AudioRecorderController({required this.recorder})
      : super(AudioRecorderState(recordingState: RecordingState.initial));

  Future<bool> _checkPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return true;
    } else {
      state = state.copyWith(
          recordingState: RecordingState.error,
          errorMessage: "Microphone permission not granted.");
      return false;
    }
  }

  Future<void> startRecording() async {
    if (await _checkPermission()) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/${DateTime.now().microsecondsSinceEpoch}.m4a';

        await recorder.start(
          path: path,
          encoder: AudioEncoder.aacLc, // or other encoders
        );
        state = state.copyWith(recordingState: RecordingState.recording, filePath: path, errorMessage: null);
      } catch (e) {
        state = state.copyWith(recordingState: RecordingState.error, errorMessage: "Failed to start recording: $e");
      }
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await recorder.stop();
      if (path != null) {
        state = state.copyWith(recordingState: RecordingState.stopped, filePath: path, errorMessage: null);
        return path;
      } else {
        state = state.copyWith(recordingState: RecordingState.error, errorMessage: "Recording stop failed, path is null.");
        return null;
      }
    } catch (e) {
      state = state.copyWith(recordingState: RecordingState.error, errorMessage: "Failed to stop recording: $e");
      return null;
    }
  }

  bool isRecording() {
    return state.recordingState == RecordingState.recording;
  }
}
