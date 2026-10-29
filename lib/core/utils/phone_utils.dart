/// Normalizes an Algerian mobile number to local format: 0[567]XXXXXXXX.
///
/// Accepts digits typed as "05/06/07…", "213…", or "+213…" and strips any
/// other formatting (spaces, dashes, etc). Returns `null` when the input
/// doesn't resolve to a valid 10-digit Algerian mobile number.
String? normalizeAlgerianPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('213')) {
    digits = '0${digits.substring(3)}';
  }
  if (RegExp(r'^0[567]\d{8}$').hasMatch(digits)) {
    return digits;
  }
  return null;
}
