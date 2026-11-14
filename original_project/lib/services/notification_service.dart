import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery_app/models/todo_item.dart';

/// Service to manage local notifications for todo reminders
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _prefsEnabledKey = 'notifications_enabled';

  /// Initialize the notification plugin
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap - can be expanded later
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Check if notifications are enabled
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? true;
  }

  /// Set notifications enabled/disabled
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, enabled);

    if (!enabled) {
      await cancelAllNotifications();
    }
  }

  /// Schedule a notification for a todo item's due date
  Future<void> scheduleTodoReminder(TodoItem todo) async {
    if (!_initialized) await initialize();
    final enabled = await isEnabled();
    if (!enabled) return;

    if (todo.dueDate == null) return;
    if (todo.isCompleted) return;

    // Don't schedule if due date is in the past
    if (todo.dueDate!.isBefore(DateTime.now())) return;

    final id = todo.id.hashCode.abs() % 2147483647; // Valid notification ID

    // Schedule notification 1 hour before due date
    final scheduledTime = todo.dueDate!.subtract(const Duration(hours: 1));

    // If the reminder time is already passed, schedule for due time itself
    final notifyAt = scheduledTime.isAfter(DateTime.now())
        ? scheduledTime
        : todo.dueDate!;

    // If even the due time is passed, skip
    if (notifyAt.isBefore(DateTime.now())) return;

    final priorityLabel = ['Low', 'Medium', 'High'][todo.priority.clamp(0, 2)];

    const androidDetails = AndroidNotificationDetails(
      'todo_reminders',
      'Todo Reminders',
      channelDescription: 'Reminders for upcoming todo due dates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use the simple show() method with a delayed Future instead of
    // scheduled notifications (which require timezone setup)
    final delay = notifyAt.difference(DateTime.now());

    // Store the scheduled time so we can manage it
    _scheduleDelayed(
      id: id,
      title: 'Todo Reminder: ${todo.title}',
      body: '[$priorityLabel] ${todo.description ?? "Due soon!"}',
      delay: delay,
      details: details,
      payload: todo.id,
    );
  }

  /// Schedule a delayed notification
  void _scheduleDelayed({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    required NotificationDetails details,
    String? payload,
  }) {
    Future.delayed(delay, () async {
      try {
        final enabled = await isEnabled();
        if (!enabled) return;

        await _plugin.show(id, title, body, details, payload: payload);
      } catch (e) {
        debugPrint('NotificationService: Error showing notification: $e');
      }
    });
  }

  /// Cancel a specific notification
  Future<void> cancelTodoReminder(String todoId) async {
    if (!_initialized) await initialize();
    final id = todoId.hashCode.abs() % 2147483647;
    await _plugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_initialized) await initialize();
    await _plugin.cancelAll();
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();
    final enabled = await isEnabled();
    if (!enabled) return;

    const androidDetails = AndroidNotificationDetails(
      'general',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedule reminders for all pending todos with due dates
  Future<void> scheduleAllTodoReminders(List<TodoItem> todos) async {
    if (!_initialized) await initialize();
    final enabled = await isEnabled();
    if (!enabled) return;

    // Cancel existing
    await cancelAllNotifications();

    // Reschedule all
    for (final todo in todos) {
      if (!todo.isCompleted && todo.dueDate != null) {
        await scheduleTodoReminder(todo);
      }
    }
  }
}
