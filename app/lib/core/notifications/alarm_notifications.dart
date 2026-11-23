import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../time/regions.dart';

/// The alarm push (section 4.6): Android channel `alarm` (max importance,
/// custom sound), iOS time-sensitive. In local mode the alarms are scheduled
/// on the device; with Firebase they come from FCM topics.
class AlarmNotifications {
  AlarmNotifications({this.enabled = true});

  /// Disabled in tests (no platform plugins).
  final bool enabled;

  static const channelId = 'alarm';
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  StreamSubscription<RemoteMessage>? _fcm;

  AndroidNotificationDetails _android(String channelName) =>
      AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.max,
        sound: const RawResourceAndroidNotificationSound('alarm'),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      );

  static const _darwin = DarwinNotificationDetails(
    sound: 'alarm.wav',
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  Future<void> init({required String channelName}) async {
    if (!enabled || _ready) return;
    _ready = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            channelName,
            importance: Importance.max,
            sound: const RawResourceAndroidNotificationSound('alarm'),
          ),
        );
  }

  /// Asks for permission (onboarding). Returns true when granted.
  Future<bool> requestPermission() async {
    if (!enabled) return true;
    if (Platform.isAndroid) {
      final a = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await a?.requestNotificationsPermission() ?? false;
      await a?.requestExactAlarmsPermission();
      return granted;
    }
    final i = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await i?.requestPermissions(alert: true, sound: true, badge: true) ??
        false;
  }

  /// Local mode: schedules the next alarms on the device.
  Future<void> scheduleLocal(
    List<(DateTime, String title, String body)> alarms, {
    required String channelName,
  }) async {
    if (!enabled) return;
    await _plugin.cancelAll();
    for (var i = 0; i < alarms.length; i++) {
      final (at, title, body) = alarms[i];
      final when = tz.TZDateTime.from(at, tz.UTC);
      final details = NotificationDetails(
        android: _android(channelName),
        iOS: _darwin,
      );
      try {
        await _plugin.zonedSchedule(
          id: i,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: title,
          body: body,
        );
      } on PlatformException {
        // Exact alarms not allowed: fall back to inexact scheduling.
        await _plugin.zonedSchedule(
          id: i,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        );
      }
    }
  }

  /// Firebase mode: one topic per region and language.
  Future<void> subscribe(
    Region region,
    String lang,
    void Function() onAlarm,
  ) async {
    if (!enabled) return;
    final m = FirebaseMessaging.instance;
    await m.requestPermission();
    for (final r in Region.values) {
      for (final l in ['fr', 'en']) {
        final topic = 'alert_${r.name}_$l';
        if (r == region && l == lang) {
          await m.subscribeToTopic(topic);
        } else {
          await m.unsubscribeFromTopic(topic);
        }
      }
    }
    await _fcm?.cancel();
    // App open when the alarm rings: no system notification, the home
    // screen switches to "ringing" by itself (section 4.6).
    _fcm = FirebaseMessaging.onMessage.listen((_) => onAlarm());
  }
}

final alarmNotificationsProvider = Provider<AlarmNotifications>(
  (ref) => AlarmNotifications(enabled: false),
);
