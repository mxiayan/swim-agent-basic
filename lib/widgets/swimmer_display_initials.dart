/// Two-letter initials from a display name (e.g. "Emma Xia" → "EX").
/// Single token uses the first two Unicode scalars (e.g. "Emma" → "EM").
String swimmerDisplayInitials(String raw) {
  final s = raw.trim();
  if (s.isEmpty) {
    return '';
  }
  final parts = s.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) {
    final a = _firstScalar(parts.first);
    final b = _firstScalar(parts.last);
    return '$a$b'.toUpperCase();
  }
  final token = parts.single;
  final runes = token.runes.toList();
  if (runes.length >= 2) {
    return String.fromCharCodes([runes[0], runes[1]]).toUpperCase();
  }
  if (runes.length == 1) {
    return String.fromCharCode(runes[0]).toUpperCase();
  }
  return '';
}

String _firstScalar(String s) {
  if (s.isEmpty) {
    return '';
  }
  final it = s.runes.iterator;
  return it.moveNext() ? String.fromCharCode(it.current) : '';
}
