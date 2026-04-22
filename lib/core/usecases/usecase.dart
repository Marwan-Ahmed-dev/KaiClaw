import 'package:dartz/dartz.dart' as dartz; // Using as dartz to avoid name conflicts
import 'package:kaiclaw/core/error/failures.dart';

abstract class UseCase<Type, Params> {
  Future<dartz.Either<Failure, Type>> call(Params params);
}

class NoParams extends dartz.Equatable {
  @override
  List<Object?> get props => [];
}
