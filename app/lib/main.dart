import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app/app.dart';
import 'core/backend/backend.dart';
import 'core/notifications/alarm_notifications.dart';
import 'core/settings/settings.dart';
import 'core/time/clock.dart';
import 'core/time/regions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await initializeForge2D();
  final prefs = await SharedPreferences.getInstance();

  var iana = 'Europe/Paris';
  try {
    iana = (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    // Fallback below on the UTC offset.
  }
  final region = regionForTimeZone(iana, DateTime.now().timeZoneOffset);
  final locale = PlatformDispatcher.instance.locale;
  final backend = await createBackend(
    prefs: prefs,
    clock: const SystemClock(),
    detectedRegion: region,
    lang: locale.languageCode == 'en' ? 'en' : 'fr',
    country: locale.countryCode,
  );
  final notifications = AlarmNotifications();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        backendProvider.overrideWithValue(backend),
        alarmNotificationsProvider.overrideWithValue(notifications),
      ],
      child: const OneGameApp(),
    ),
  );
}
