/// Base class for failures in the domain/data layer.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

/// Failure when a remote request fails.
final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Failure when no data / empty result.
final class EmptyFailure extends Failure {
  const EmptyFailure([super.message = 'No data']);
}
