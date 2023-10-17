/// A container for configuration values of the screenshot suite.
///
/// If you are trying to get the configuration in your client code, you should
/// use [ScreenshotConfiguration.fromEnv].
class ScreenshotConfiguration {
  final bool isActive;
  final String? username;
  final String? password;

  /// Create a new configuration.
  ///
  /// This should only be used in the host code. If you are trying to get the
  /// active configuration in your client code, use
  /// [ScreenshotConfiguration.fromEnv].
  const ScreenshotConfiguration({
    this.username,
    this.password,
    this.isActive =
        const bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false),
  });

  /// The active configuration for the client.
  static const ScreenshotConfiguration fromEnv = ScreenshotConfiguration(
    username: String.fromEnvironment('SCREENSHOT_USERNAME'),
    password: String.fromEnvironment('SCREENSHOT_PASSWORD'),
  );
}
