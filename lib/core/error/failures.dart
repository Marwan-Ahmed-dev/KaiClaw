import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure([this.properties = const <dynamic>[]]);

  final List properties;

  @override
  List<Object> get props => properties;
}

class ServerFailure extends Failure {
  final String message;
  const ServerFailure({this.message = 'An unexpected server error occurred.'});
  @override
  List<Object> get props => [message];
}

class NetworkFailure extends Failure {
  final String message;
  const NetworkFailure({this.message = 'Please check your internet connection.'});
  @override
  List<Object> get props => [message];
}

class CacheFailure extends Failure {
  final String message;
  const CacheFailure({this.message = 'Failed to retrieve data from cache.'});
  @override
  List<Object> get props => [message];
}

class UnknownFailure extends Failure {
  final String message;
  const UnknownFailure({this.message = 'An unknown error occurred.'});
  @override
  List<Object> get props => [message];
}
