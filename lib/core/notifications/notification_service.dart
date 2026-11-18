/// Which screen a tapped notification should open.
enum NotificationTarget { meditation, moodCheckIn, competition }

/// A notification backend. [LocalNotificationService] (on-device scheduled,
/// no server) is the first implementation; a Firebase push backend is
/// planned as a second, independent one — see `notification_provider.dart`
/// for how the active implementation is selected. This interface is kept
/// free of any provider-specific types so the two can coexist without either
/// depending on the other.
abstract class NotificationService {
  /// Sets up the platform plugin(s). Call once, before anything else here.
  /// [onNotificationTap] fires when the sailor taps a delivered notification.
  Future<void> initialize({
    void Function(NotificationTarget target)? onNotificationTap,
  });

  /// Requests the OS notification permission. Returns whether it's granted
  /// (including if it already was).
  Future<bool> requestPermission();

  /// Fires immediately — the one-time "you're in" welcome right after signup.
  Future<void> showSignupWelcome();

  /// (Re)schedules every recurring reminder: the 7am meditation nudge, the
  /// 9am + midday mood check-ins, and the 3pm competition countdown. Safe to
  /// call repeatedly (e.g. on every app launch) — each reminder has a stable
  /// identity, so scheduling again overwrites rather than duplicates it.
  Future<void> scheduleDailyReminders();

  /// Cancels every reminder scheduled by [scheduleDailyReminders] (not the
  /// one-time welcome). Called on logout so a signed-out device stops
  /// nagging a sailor who isn't using it anymore.
  Future<void> cancelAll();
}
