import 'dart:async';

/// A one-shot cancellation signal for a lifecycle operation.
///
/// Every coordinator in this package needs the same primitive: race an
/// in-flight platform future against "this operation was superseded or stopped",
/// and surface the cancellation as the coordinator's own error type. Keeping it
/// here means the five call sites cannot drift in how they observe
/// cancellation (an earlier version of this package had three subtly different
/// copies).
///
/// The signal is intentionally one-shot: once cancelled it never un-cancels, so
/// a late cancellation cannot resurrect a superseded operation.
final class CancellationSignal {
  final Completer<void> _signal = Completer<void>();

  bool get isCancelled => _signal.isCompleted;

  /// Marks the operation as cancelled. A second call is a no-op.
  void cancel() {
    if (!_signal.isCompleted) {
      _signal.complete();
    }
  }

  /// Completes with [operation]'s result, or throws the error returned by
  /// [cancellationError] if the signal fires first.
  ///
  /// [cancellationError] is a factory, not a value: it is only called once the
  /// signal has fired. A caller that learns *why* the operation was cancelled at
  /// cancel time — a disconnect, a changed GATT database — must therefore still
  /// report that specific reason even though the race was set up earlier.
  ///
  /// If [operation] itself fails first, its error propagates untouched — a
  /// genuine platform failure must not be masked by a later cancellation.
  Future<T> race<T>(
    Future<T> operation, {
    required Object Function() cancellationError,
  }) {
    return Future.any<T>(<Future<T>>[
      operation,
      _signal.future.then<T>((_) => throw cancellationError()),
    ]);
  }
}
