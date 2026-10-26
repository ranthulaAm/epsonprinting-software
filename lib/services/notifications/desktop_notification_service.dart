import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/queue/domain/print_job_models.dart';

final desktopNotificationServiceProvider =
    Provider<IDesktopNotificationService>((ref) {
  return LocalDesktopNotificationService();
});

abstract interface class IDesktopNotificationService {
  List<AppDesktopNotification> get recentNotifications;
  Future<AppDesktopNotification> notify({
    required String title,
    required String body,
    bool isError = false,
  });
  void clearNotifications();
}

class LocalDesktopNotificationService implements IDesktopNotificationService {
  static const _uuid = Uuid();
  final List<AppDesktopNotification> _notifications = [];

  @override
  List<AppDesktopNotification> get recentNotifications =>
      List.unmodifiable(_notifications);

  @override
  Future<AppDesktopNotification> notify({
    required String title,
    required String body,
    bool isError = false,
  }) async {
    final item = AppDesktopNotification(
      id: _uuid.v4(),
      title: title,
      body: body,
      isError: isError,
      timestamp: DateTime.now(),
    );
    _notifications.insert(0, item);
    if (_notifications.length > 50) {
      _notifications.removeLast();
    }
    return item;
  }

  @override
  void clearNotifications() {
    _notifications.clear();
  }
}
