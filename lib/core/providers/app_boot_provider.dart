import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppBootData {
  const AppBootData({
    required this.windowId,
    required this.isChildWindow,
    this.mainWindowId,
    this.initialTabPayload,
  });

  final String windowId;
  final bool isChildWindow;
  final String? mainWindowId;
  final Map<String, dynamic>? initialTabPayload;
}

final appBootProvider = Provider<AppBootData>(
  (ref) => const AppBootData(windowId: 'main', isChildWindow: false),
);
