import 'package:flutter_test/flutter_test.dart';
import 'package:quick_blue/src/quick_blue_android.dart';
import 'package:quick_blue_linux/quick_blue_linux.dart';
import 'package:quick_blue_platform_interface/quick_blue_platform_interface.dart';
import 'package:quick_blue_windows/quick_blue_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in <QuickBluePlatform>[
    QuickBlueAndroid(),
    QuickBlueLinux(),
    QuickBlueWindows(),
  ]) {
    test(
      '${platform.runtimeType} reports unknown instead of guessing from MTU',
      () async {
        final device = platform.device('device');
        for (final mode in [
          BleOutputProperty.withResponse,
          BleOutputProperty.withoutResponse,
        ]) {
          expect(await device.maximumWriteValueLength(mode), isNull);
          expect(
            await device
                .characteristic('service', 'characteristic')
                .maximumWriteValueLength(mode),
            isNull,
          );
        }
      },
    );
  }
}
