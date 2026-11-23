import 'package:timezone/timezone.dart' as tz;

/// The 4 regions and their reference time zones (section 4.1).
enum Region {
  europe('Europe/Paris'),
  americas('America/New_York'),
  asia('Asia/Tokyo'),
  west('America/Los_Angeles');

  const Region(this.timeZone);

  final String timeZone;

  tz.Location get location => tz.getLocation(timeZone);

  static Region? byName(String? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

const _westZones = {
  'America/Los_Angeles',
  'America/Vancouver',
  'America/Tijuana',
  'America/Phoenix',
  'America/Denver',
  'America/Edmonton',
  'America/Boise',
  'America/Anchorage',
  'America/Juneau',
  'America/Whitehorse',
  'America/Yellowknife',
  'America/Hermosillo',
  'America/Mazatlan',
  'Pacific/Honolulu',
  'America/Sitka',
  'America/Nome',
};

/// Region inferred from the device time zone (IANA id), with the UTC offset
/// as a fallback when the id is unknown.
Region regionForTimeZone(String iana, Duration offset) {
  if (_westZones.contains(iana) ||
      iana.startsWith('US/Pacific') ||
      iana.startsWith('US/Mountain') ||
      iana.startsWith('US/Alaska') ||
      iana.startsWith('US/Hawaii')) {
    return Region.west;
  }
  if (iana.startsWith('America/') ||
      iana.startsWith('US/') ||
      iana.startsWith('Canada/') ||
      iana.startsWith('Brazil/') ||
      iana == 'Atlantic/Bermuda') {
    return Region.americas;
  }
  if (iana.startsWith('Europe/') ||
      iana.startsWith('Africa/') ||
      iana.startsWith('Atlantic/')) {
    return Region.europe;
  }
  if (iana.startsWith('Asia/') ||
      iana.startsWith('Australia/') ||
      iana.startsWith('Pacific/') ||
      iana.startsWith('Indian/') ||
      iana.startsWith('Antarctica/')) {
    return Region.asia;
  }
  final h = offset.inMinutes / 60;
  if (h <= -7) return Region.west;
  if (h < -1) return Region.americas;
  if (h <= 4) return Region.europe;
  return Region.asia;
}

String _two(int v) => v.toString().padLeft(2, '0');

String dayKeyOf(int y, int m, int d) => '$y-${_two(m)}-${_two(d)}';

/// `YYYY-MM-DD` of [instant] in the region's reference time zone.
String dayKeyFor(DateTime instant, Region region) {
  final t = tz.TZDateTime.from(instant.toUtc(), region.location);
  return dayKeyOf(t.year, t.month, t.day);
}

(int, int, int) parseDayKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return (p[0], p[1], p[2]);
}

String addDays(String k, int n) {
  final (y, m, d) = parseDayKey(k);
  final t = DateTime.utc(y, m, d + n);
  return dayKeyOf(t.year, t.month, t.day);
}

/// 0 = Sunday … 6 = Saturday (same as JavaScript).
int dayOfWeek(String k) {
  final (y, m, d) = parseDayKey(k);
  return DateTime.utc(y, m, d).weekday % 7;
}

/// UTC instant of a wall-clock time in [location].
DateTime zonedToUtc(
  tz.Location location,
  int y,
  int m,
  int d,
  int h,
  int min,
  int s,
) => tz.TZDateTime(location, y, m, d, h, min, s).toUtc();
