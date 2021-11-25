library boot.os.tools.preseed;

class DebianPreseedSelection {
  final String type;
  final String value;

  DebianPreseedSelection(this.type, this.value);

  @override
  String toString() => "PreseedSelection($type, $value)";
}

class _DebianPreseedOption {
  final String what;
  final String option;

  _DebianPreseedOption(this.what, this.option);

  @override
  String toString() => "PreseedOption($what, $option)";

  @override
  bool operator ==(Object other) {
    if (other is _DebianPreseedOption) {
      return other.what == what && other.option == option;
    }
    return false;
  }

  @override
  int get hashCode => "${what}/${option}".hashCode;
}

class DebianPreseedFile {
  final Map<String, Map<_DebianPreseedOption, DebianPreseedSelection>>
      _settings;

  DebianPreseedFile(this._settings);

  DebianPreseedSelection? get(String directive, String what, String option,
      [DebianPreseedSelection? defaultValue]) {
    final directiveSettings = _settings[directive];

    if (directiveSettings == null) {
      return null;
    }
    return directiveSettings[_DebianPreseedOption(what, option)] ??
        defaultValue;
  }

  void set(String directive, String what, String option,
      DebianPreseedSelection selection) {
    if (!_settings.containsKey(directive)) {
      _settings[directive] = <_DebianPreseedOption, DebianPreseedSelection>{};
    }
    final directiveSettings = _settings[directive]!;
    directiveSettings[_DebianPreseedOption(what, option)] = selection;
  }

  DebianPreseedSelection? remove(String directive, String what, String option) {
    final directiveSettings = _settings[directive];
    if (directiveSettings == null) {
      return null;
    }

    return directiveSettings.remove(_DebianPreseedOption(what, option));
  }

  void forEach(
      void Function(String directive, String what, String option,
              DebianPreseedSelection selection)
          callback) {
    for (final directive in _settings.keys) {
      final directiveSettings = _settings[directive]!;
      for (final option in directiveSettings.keys) {
        final selection = directiveSettings[option]!;
        callback(directive, option.what, option.option, selection);
      }
    }
  }

  factory DebianPreseedFile.parse(List<String> lines) {
    final settings =
        <String, Map<_DebianPreseedOption, DebianPreseedSelection>>{};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      if (trimmed.startsWith("#")) {
        continue;
      }

      final parts = line.split(" ");
      final directive = parts[0];
      final fullOption = parts[1];
      final type = parts[2];
      final value = parts.skip(3).join(" ");

      final fullOptionParts = fullOption.split("/");
      final what = fullOptionParts[0];
      final optionName = fullOptionParts.skip(1).join("/");

      if (!settings.containsKey(directive)) {
        settings[directive] = <_DebianPreseedOption, DebianPreseedSelection>{};
      }

      final option = _DebianPreseedOption(what, optionName);
      settings[directive]![option] = DebianPreseedSelection(type, value);
    }
    return DebianPreseedFile(settings);
  }
}
