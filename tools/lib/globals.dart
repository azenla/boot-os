library boot.os.tools.globals;

import 'dart:io';

class GlobalSettings {
  static final shortCircuitFileValidation =
      boolForEnv("BOOT_OS_SKIP_FILE_VALIDATION");

  static bool boolForEnv(String key) =>
      <String>["1", "true"].contains(Platform.environment[key]?.toLowerCase());
}
