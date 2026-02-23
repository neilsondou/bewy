import 'package:window_manager/window_manager.dart';

class AppExitService {
  AppExitService._();

  static Future<void> Function()? _closeHandler;

  static void registerCloseHandler(Future<void> Function() handler) {
    _closeHandler = handler;
  }

  static void unregisterCloseHandler() {
    _closeHandler = null;
  }

  static Future<void> requestClose() async {
    final handler = _closeHandler;
    if (handler != null) {
      await handler();
      return;
    }
    await windowManager.close();
  }
}
