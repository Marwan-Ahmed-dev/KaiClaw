import 'package:dartz/dartz.dart';
import 'package:kaiclaw/core/error/failures.dart';
import 'package:kaiclaw/core/usecases/usecase.dart';
import 'package:kaiclaw/features/kai_claw/domain/repositories/kai_claw_repository.dart';

class SendCommandUseCase implements UseCase<void, String> {
  final KaiClawRepository repository;

  SendCommandUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String commandType) async {
    return await repository.sendCommand(commandType);
  }
}
