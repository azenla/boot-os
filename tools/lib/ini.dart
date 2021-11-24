library boot.os.tools.ini;

class RelaxedIniFile {
  final Map<String, Map<String, List<String>>> sections;

  RelaxedIniFile(this.sections);

  factory RelaxedIniFile.parse(List<String> lines) {
    final sections = <String, Map<String, List<String>>>{};
    String? sectionName = null;
    var sectionContents = <String, List<String>>{};

    void saveCurrentSection() {
      if (sectionName != null) {
        sections[sectionName] = sectionContents;
        sectionContents = <String, List<String>>{};
      }
    }

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      if (line.startsWith("#")) continue;

      if (line.startsWith("[")) {
        saveCurrentSection();
        sectionName = line.substring(1, line.lastIndexOf("]"));
      } else if (line.contains("=")) {
        final separatorIndex = line.indexOf("=");
        final key = line.substring(0, separatorIndex);
        final value = line.substring(separatorIndex + 1);
        sectionContents.update(key, (list) => list..add(value),
            ifAbsent: () => <String>[value]);
      } else {
        throw Exception("Unknown line: $line");
      }
    }
    saveCurrentSection();
    return RelaxedIniFile(sections);
  }
}
