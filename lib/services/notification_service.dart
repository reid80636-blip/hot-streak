import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}

/// Service for handling push notifications via Firebase Cloud Messaging
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _notificationsEnabled = true;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // Setup local notifications for displaying foreground messages
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'game_alerts',
      'Game Alerts',
      description: 'Notifications for followed team games',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check for initial message (app opened via notification)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // Get FCM token for debugging
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');

    _initialized = true;
  }

  /// Set whether notifications are enabled
  static void setEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  /// Sanitize team name for FCM topic (alphanumeric + underscore only)
  static String _teamToTopic(String teamName) {
    return 'team_${teamName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
  }

  /// Subscribe to notifications for the given teams
  static Future<void> subscribeToTeams(List<String> teams) async {
    if (!_notificationsEnabled) return;

    for (final team in teams) {
      final topic = _teamToTopic(team);
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    }
  }

  /// Unsubscribe from notifications for the given teams
  static Future<void> unsubscribeFromTeams(List<String> teams) async {
    for (final team in teams) {
      final topic = _teamToTopic(team);
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    }
  }

  /// Unsubscribe from all team topics
  static Future<void> unsubscribeFromAllTeams(List<String> teams) async {
    await unsubscribeFromTeams(teams);
  }

  /// Handle foreground messages by showing a local notification
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_notificationsEnabled) return;

    final notification = message.notification;
    if (notification == null) return;

    debugPrint('Foreground message: ${notification.title}');

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'game_alerts',
          'Game Alerts',
          channelDescription: 'Notifications for followed team games',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route'],
    );
  }

  /// Handle notification tap when app is in background
  static void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('Notification opened: ${message.data}');
    // Navigation can be handled here if needed
    // e.g., navigate to a specific game or screen
  }

  /// Handle local notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    // Navigation can be handled here if needed
  }
}
