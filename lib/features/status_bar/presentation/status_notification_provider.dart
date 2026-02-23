import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatusNotification {
  const StatusNotification({
    required this.message,
    this.type = StatusNotificationType.info,
  });

  final String message;
  final StatusNotificationType type;
}

enum StatusNotificationType { info, success, error }

class StatusNotificationNotifier extends StateNotifier<StatusNotification?> {
  StatusNotificationNotifier() : super(null);

  Timer? _dismissTimer;

  void show(
    String message, {
    StatusNotificationType type = StatusNotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismissTimer?.cancel();
    state = StatusNotification(message: message, type: type);
    _dismissTimer = Timer(duration, () {
      if (mounted) state = null;
    });
  }

  void dismiss() {
    _dismissTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

final statusNotificationProvider =
    StateNotifierProvider<StatusNotificationNotifier, StatusNotification?>(
      (ref) => StatusNotificationNotifier(),
    );
