import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:kaiclaw/core/error/failures.dart';
import 'package:kaiclaw/core/usecases/usecase.dart';
import 'package:kaiclaw/features/kai_claw/domain/repositories/kai_claw_repository.dart';

class RecordAudioUseCase implements UseCase<void, RecordAudioParams> {
  final KaiClawRepository repository;

  RecordAudioUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(RecordAudioParams params) async {
    return await repository.recordAudio(params.fileName, params.bytes);
  }
}

class RecordAudioParams extends Equatable {
  final String fileName;
  final List<int> bytes;

  const RecordAudioParams({required this.fileName, required required this.bytes});

  @override
  List<Object?> get props => [fileName, bytes];
}
