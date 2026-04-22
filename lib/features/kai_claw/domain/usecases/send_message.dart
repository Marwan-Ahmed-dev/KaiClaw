import 'package:dartz/dartz.dart';
import 'package:kaiclaw/core/error/failures.dart';
import 'package:kaiclaw/core/usecases/usecase.dart';
import 'package:kaiclaw/features/kai_claw/domain/entities/message.dart';
import 'package:kaiclaw/features/kai_claw/domain/repositories/kai_claw_repository.dart';

class SendMessageUseCase implements UseCase<Message, String> {
  final KaiClawRepository repository;

  SendMessageUseCase(this.repository);

  @override
  Future<Either<Failure, Message>> call(String messageText) async {
    return await repository.sendMessage(messageText);
  }
}
