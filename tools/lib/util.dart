library boot.os.tools.util;

String? nullIfEmpty(String? input) {
  if (input == null) {
    return null;
  }

  if (input.isEmpty) {
    return null;
  }
  return input;
}

void removeAllNullValues(input) {
  if (input is Map<String, dynamic>) {
    for (final key in input.keys.toList()) {
      final value = input[key];
      if (value == null) {
        input.remove(key);
      } else {
        removeAllNullValues(value);
      }
    }
  } else if (input is List<dynamic>) {
    input.removeWhere((x) => x == null);
    for (final value in input) {
      removeAllNullValues(value);
    }
  }
}
