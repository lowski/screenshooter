/// A simple locale implementation since the one from dart:ui is not available.
class ScreenshotLocale {
  final String languageCode;
  final String? scriptCode;
  final String? countryCode;

  ScreenshotLocale(this.languageCode, this.scriptCode, this.countryCode);

  /// Create a locale from a string in BCP47 format.
  ///
  /// Both `_` and `-` are accepted as separators. The following formats are
  /// supported:
  ///
  /// - `languageCode`
  /// - `languageCode-countryCode`
  /// - `languageCode-scriptCode-countryCode`
  factory ScreenshotLocale.fromString(String s) {
    s = s.replaceAll('_', '-');
    final hasSeparator = s.contains('-');
    if (!hasSeparator) {
      return ScreenshotLocale(s, null, null);
    }
    final parts = s.split('-');
    if (parts.length == 2) {
      return ScreenshotLocale(parts.first, null, parts.last);
    }
    if (parts.length == 3) {
      return ScreenshotLocale(parts[0], parts[1], parts[2]);
    }
    throw ArgumentError.value(
      s,
      'locales',
      'Invalid locale format. Expected BCP47 format like "en" or "en-US" or "en-Latn-US"',
    );
  }

  /// Create a list of locales from a list of strings.
  static List<ScreenshotLocale> fromStrings(Iterable<String> strings) =>
      strings.map(ScreenshotLocale.fromString).toList();

  /// Create a list of locales from a comma separated string.
  static List<ScreenshotLocale> fromSeparatedString(String s) =>
      fromStrings(s.split(',').map((s) => s.trim()));

  String toLanguageTag() {
    final parts = <String>[];
    parts.add(languageCode);
    if (scriptCode != null) parts.add(scriptCode!);
    if (countryCode != null) parts.add(countryCode!);
    return parts.join('-');
  }
}

/// A container for configuration values of the screenshot suite.
///
/// If you are trying to get the configuration in your client code, you should
/// use [ScreenshotConfiguration.fromEnv].
class ScreenshotConfiguration {
  final bool isActive;
  final String? username;
  final String? password;

  final String? _locales;

  /// The list of locales to run the screenshots for.
  List<ScreenshotLocale>? get locales =>
      _locales == null ? null : ScreenshotLocale.fromSeparatedString(_locales!);

  /// Create a new configuration.
  ///
  /// This should only be used in the host code. If you are trying to get the
  /// active configuration in your client code, use
  /// [ScreenshotConfiguration.fromEnv].
  const ScreenshotConfiguration({
    this.username,
    this.password,
    String? locales,
    this.isActive =
        const bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false),
  }) : _locales = locales;

  /// The active configuration for the client.
  static const ScreenshotConfiguration fromEnv = ScreenshotConfiguration(
    username: String.fromEnvironment('SCREENSHOT_USERNAME'),
    password: String.fromEnvironment('SCREENSHOT_PASSWORD'),
    locales: String.fromEnvironment('SCREENSHOT_LOCALES'),
  );
}
