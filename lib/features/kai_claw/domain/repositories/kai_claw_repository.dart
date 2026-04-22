import 'package:dartz/dartz.dart';
import 'package:kaiclaw/core/error/failures.dart';
import 'package:kaiclaw/features/kai_claw/domain/entities/message.dart';

abstract class KaiClawRepository {
  Future<Either<Failure, Message>> sendMessage(String text);
  Future<Either<Failure, void>> sendCommand(String commandType);
  Future<Either<Failure, void>> uploadFile(String fileName, List<int> bytes);
  Future<Either<Failure, void>> recordAudio(String fileName, List<int> bytes);
}
