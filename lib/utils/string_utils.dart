String normalizeString(dynamic value, {required String fallback}) {
  if (value == null) return fallback;
  final asString = value.toString().trim();
  return asString.isEmpty ? fallback : asString;
}
