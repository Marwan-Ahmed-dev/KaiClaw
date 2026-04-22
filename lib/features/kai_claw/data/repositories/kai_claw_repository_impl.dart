import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:kaiclaw/core/error/failures.dart';
import 'package:kaiclaw/features/kai_claw/data/datasources/kai_claw_remote_data_source.dart';
import 'package:kaiclaw/features/kai_claw/data/models/message_model.dart';
import 'package:kaiclaw/features/kai_claw/domain/entities/message.dart';
import 'package:kaiclaw/features/kai_claw/domain/repositories/kai_claw_repository.dart';

class KaiClawRepositoryImpl implements KaiClawRepository {
  final KaiClawRemoteDataSource remoteDataSource;

  KaiClawRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Message>> sendMessage(String text) async {
    try {
      final remoteMessage = await remoteDataSource.sendMessage(text);
      return Right(remoteMessage);
    } on ServerFailure catch (e) {
      return Left(e);
    } on NetworkFailure catch(e) {
      return Left(e);
    } on SocketException {
      return const Left(NetworkFailure());
    } on Exception catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendCommand(String commandType) async {
    try {
      await remoteDataSource.sendCommand(commandType);
      return const Right(null);
    } on ServerFailure catch (e) {
      return Left(e);
    } on NetworkFailure catch(e) {
      return Left(e);
    } on SocketException {
      return const Left(NetworkFailure());
    } on Exception catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> uploadFile(String fileName, List<int> bytes) async {
    try {
      await remoteDataSource.uploadFile(fileName, bytes);
      return const Right(null);
    } on ServerFailure catch (e) {
      return Left(e);
    } on NetworkFailure catch(e) {
      return Left(e);
    } on SocketException {
      return const Left(NetworkFailure());
    } on Exception catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> recordAudio(String fileName, List<int> bytes) async {
    try {
      await remoteDataSource.recordAudio(fileName, bytes);
      return const Right(null);
    } on ServerFailure catch (e) {
      return Left(e);
    } on NetworkFailure catch(e) {
      return Left(e);
    } on SocketException {
      return const Left(NetworkFailure());
    } on Exception catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
