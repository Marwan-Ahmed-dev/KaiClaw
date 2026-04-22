import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:kaiclaw/core/error/failures.dart';
import 'package:kaiclaw/core/usecases/usecase.dart';
import 'package:kaiclaw/features/kai_claw/domain/repositories/kai_claw_repository.dart';

class UploadFileUseCase implements UseCase<void, UploadFileParams> {
  final KaiClawRepository repository;

  UploadFileUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UploadFileParams params) async {
    return await repository.uploadFile(params.fileName, params.bytes);
  }
}

class UploadFileParams extends Equatable {
  final String fileName;
  final List<int> bytes;

  const UploadFileParams({required this.fileName, required required this.bytes});

  @override
  List<Object?> get props => [fileName, bytes];
}
