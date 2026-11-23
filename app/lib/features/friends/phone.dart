/// Minimal E.164 normalisation for contact matching (section 9.7).
const _callingCodes = {
  'FR': '33',
  'BE': '32',
  'CH': '41',
  'LU': '352',
  'MC': '377',
  'CA': '1',
  'US': '1',
  'GB': '44',
  'DE': '49',
  'ES': '34',
  'IT': '39',
  'PT': '351',
  'NL': '31',
  'MA': '212',
  'DZ': '213',
  'TN': '216',
  'SN': '221',
  'CI': '225',
  'CM': '237',
  'JP': '81',
  'BR': '55',
  'MX': '52',
  'AU': '61',
};

/// Returns `+<digits>` or null when the number cannot be normalised.
String? normalizePhone(String raw, String? country) {
  var s = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (s.startsWith('+')) {
    final digits = s.substring(1).replaceAll('+', '');
    return digits.length >= 8 ? '+$digits' : null;
  }
  final cc = _callingCodes[country?.toUpperCase()];
  if (cc == null) return null;
  if (s.startsWith('0')) s = s.substring(1);
  if (cc == '1' && s.length == 11 && s.startsWith('1')) s = s.substring(1);
  return s.length >= 7 ? '+$cc$s' : null;
}
