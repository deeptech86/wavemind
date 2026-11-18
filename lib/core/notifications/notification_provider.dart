import 'local_notification_service.dart';
import 'notification_service.dart';

/// Which notification backend is currently active. [local] and a future
/// `firebase` push backend are built as independent implementations of
/// [NotificationService] (see that file), so either can be the active one
/// without the other existing yet or depending on it. Swapping providers is
/// an A/B-style toggle: flip [active] and rebuild.
enum NotificationProvider { local, firebase }

abstract final class NotificationConfig {
  /// The only provider implemented so far. Flipping this to `firebase`
  /// requires adding a `FirebaseNotificationService` and a case for it in
  /// [createNotificationService] first.
  static const NotificationProvider active = NotificationProvider.local;
}

NotificationService createNotificationService() {
  switch (NotificationConfig.active) {
    case NotificationProvider.local:
      return LocalNotificationService();
    case NotificationProvider.firebase:
      throw UnimplementedError(
        'Firebase push notifications are not implemented yet — see '
        'NotificationConfig.',
      );
  }
}

/// App-wide singleton — one notification backend instance for the whole app.
final NotificationService notificationService = createNotificationService();
