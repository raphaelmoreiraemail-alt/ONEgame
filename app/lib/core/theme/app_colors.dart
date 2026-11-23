import 'package:material_ui/material_ui.dart';

/// OneGame brand palette (section 11). Mini-games may add their own palette,
/// but the HUD always uses these colors.
abstract final class AppColors {
  static const alarmRed = Color(0xFFE8322F);
  static const yellow = Color(0xFFFFD23F);
  static const night = Color(0xFF120D0E);
  static const bone = Color(0xFFF4ECE4);

  /// Calendar / status colors (profile).
  static const onTime = Color(0xFF2FA35A);
  static const late = Color(0xFFF08A24);
  static const missed = Color(0xFF8E8A87);
}
