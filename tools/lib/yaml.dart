library boot.os.tools.yaml;

class YamlWriter {
  static final _cleanStringCharacters = <String>["/", ":", ".", "-"];

  static String write(dynamic yaml) {
    return _writeInternal(yaml)
        .trim()
        .split("\n")
        .map((e) => e.trimRight())
        .join("\n");
  }

  static String _writeInternal(dynamic yaml, {int indent = 0}) {
    final buffer = StringBuffer();

    if (yaml is List<dynamic>) {
      buffer.write(_writeList(yaml, indent: indent));
    } else if (yaml is Map<dynamic, dynamic>) {
      buffer.write(_writeMap(yaml, indent: indent));
    } else if (yaml is String) {
      buffer.write(_cleanWriteString(yaml));
    } else {
      buffer.write(yaml.toString());
    }

    return buffer.toString();
  }

  static String _writeList(List<dynamic> yaml, {int indent = 0}) {
    final buffer = StringBuffer("\n");

    for (var item in yaml) {
      buffer.write(
          "${_indent(indent)}- ${_writeInternal(item, indent: indent + 1)}\n");
    }

    return buffer.toString();
  }

  static String _writeMap(Map<dynamic, dynamic> yaml, {int indent = 0}) {
    final buffer = StringBuffer('\n');

    for (var key in yaml.keys) {
      var value = yaml[key];
      buffer.write(
          "${_indent(indent)}${key.toString()}: ${_writeInternal(value, indent: indent + 1).trimRight()}\n");
    }

    return buffer.toString();
  }

  static String _cleanWriteString(String input) {
    if (input.codeUnits
            .map((code) => String.fromCharCode(code))
            .every((e) => _isCleanCharacter(e)) &&
        num.tryParse(input) == null) {
      return input;
    } else {
      return "\"${input.replaceAll("\"", "\\\"")}\"";
    }
  }

  static bool _isCleanCharacter(String char) {
    final codeUnit = char.codeUnitAt(0);
    if ((codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        (codeUnit >= 48 && codeUnit <= 57)) {
      return true;
    }
    if (_cleanStringCharacters.contains(char)) {
      return true;
    }
    return false;
  }

  static String _indent(int indent) {
    return ''.padLeft(indent * 2, ' ');
  }
}
