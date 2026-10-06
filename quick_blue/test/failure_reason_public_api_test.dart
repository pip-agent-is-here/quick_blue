import 'package:flutter_test/flutter_test.dart';
import 'package:quick_blue/quick_blue.dart';

void main() {
  test('failure reasons are available from the public package entrypoint', () {
    const error = QuickBlueException(
      code: QuickBlueErrorCode.operationFailed,
      message: 'The remote device disconnected.',
      failureReason: QuickBlueFailureReason.remoteDisconnected,
    );

    expect(error.failureReason, QuickBlueFailureReason.remoteDisconnected);
  });
}