import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:kaiclaw/core/constants/app_constants.dart';
import 'package:kaiclaw/core/error/failures.dart';
import 'package:kaiclaw/features/kai_claw/data/models/message_model.dart';
import 'package:uuid/uuid.dart';

abstract class KaiClawRemoteDataSource {
  Future<MessageModel> sendMessage(String text);
  Future<void> sendCommand(String commandType);
  Future<void> uploadFile(String fileName, List<int> bytes);
  Future<void> recordAudio(String fileName, List<int> bytes);
}

class KaiClawRemoteDataSourceImpl implements KaiClawRemoteDataSource {
  final http.Client client;
  final Uuid uuid;

  KaiClawRemoteDataSourceImpl({required this.client, required this.uuid});

  @override
  Future<MessageModel> sendMessage(String text) async {
    try {
      final response = await client.post(
        Uri.parse(AppConstants.webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': text, 'type': 'chat'}),
      ).timeout(const Duration(seconds: 10)); // Added timeout

      if (response.statusCode == 200) {
        // Placeholder for real webhook response parsing.
        // Assuming the webhook might return a simple text message.
        // If the webhook returns JSON, you'd parse it here.
        final responseBody = utf8.decode(response.bodyBytes);
        final dynamic responseData = json.decode(responseBody);
        
        // This is a common pattern for webhook responses; adjust as needed.
        // For now, we'll construct a dummy bot response.
        return MessageModel(
          id: uuid.v4(),
          text: responseData['reply'] ?? 'تم استلام رسالتك: "$text". جارٍ المعالجة...', // Use actual reply if available
          isUser: false,
          timestamp: DateTime.now(),
        );
      } else {
        throw ServerFailure(message: 'Failed to send message: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw const NetworkFailure(message: 'No internet connection. Please check your network.');
    } on http.ClientException catch (e) {
      throw ServerFailure(message: 'HTTP client error: ${e.message}');
    } on FormatException {
      throw const ServerFailure(message: 'Invalid response format from server.');
    } on Exception catch (e) {
      throw UnknownFailure(message: 'An unexpected error occurred: ${e.toString()}');
    }
  }

  @override
  Future<void> sendCommand(String commandType) async {
    try {
      final response = await client.post(
        Uri.parse(AppConstants.webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'command': commandType, 'type': 'command'}),
      ).timeout(const Duration(seconds: 10)); // Added timeout

      if (response.statusCode != 200) {
        throw ServerFailure(message: 'Failed to send command $commandType: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw const NetworkFailure(message: 'No internet connection. Please check your network.');
    } on http.ClientException catch (e) {
      throw ServerFailure(message: 'HTTP client error: ${e.message}');
    } on Exception catch (e) {
      throw UnknownFailure(message: 'An unexpected error occurred: ${e.toString()}');
    }
  }

  @override
  Future<void> uploadFile(String fileName, List<int> bytes) async {
    try {
      // In a real scenario, you would typically use multipart/form-data for file uploads
      // or send a Base64 encoded string if the webhook expects it.
      // For this example, we'll send a JSON payload indicating file metadata.
      // Kaiowa will need to handle this structured data and potentially request the file itself
      // or receive it as part of the initial payload (Base64).
      final response = await client.post(
        Uri.parse(AppConstants.webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': 'upload_file',
          'file_name': fileName,
          'file_size': bytes.length,
          // 'file_content_base64': base64Encode(bytes), // Uncomment if webhook expects Base64 content
          'type': 'file_upload'
        }),
      ).timeout(const Duration(seconds: 30)); // Longer timeout for file uploads

      if (response.statusCode != 200) {
        throw ServerFailure(message: 'Failed to upload file $fileName: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw const NetworkFailure(message: 'No internet connection. Please check your network.');
    } on http.ClientException catch (e) {
      throw ServerFailure(message: 'HTTP client error: ${e.message}');
    } on Exception catch (e) {
      throw UnknownFailure(message: 'An unexpected error occurred: ${e.toString()}');
    }
  }

  @override
  Future<void> recordAudio(String fileName, List<int> bytes) async {
    try {
      // Similar to file upload, audio content could be sent as Base64 or multipart.
      final response = await client.post(
        Uri.parse(AppConstants.webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': 'record_audio',
          'audio_name': fileName,
          'audio_size': bytes.length,
          // 'audio_content_base64': base64Encode(bytes), // Uncomment if webhook expects Base64 content
          'type': 'audio_record'
        }),
      ).timeout(const Duration(seconds: 30)); // Longer timeout for audio uploads

      if (response.statusCode != 200) {
        throw ServerFailure(message: 'Failed to record audio: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw const NetworkFailure(message: 'No internet connection. Please check your network.');
    } on http.ClientException catch (e) {
      throw ServerFailure(message: 'HTTP client error: ${e.message}');
    } on Exception catch (e) {
      throw UnknownFailure(message: 'An unexpected error occurred: ${e.toString()}');
    }
  }
}
