# Screenshooter

Automatically create screenshots of your flutter app.

## Working Principle

Screenshooter works by building a special version of your app (with a different entrypoint) and running that on an iOS simulator. This app will execute the steps you specify and notify the host when it should take the screenshot. This way you can be sure that the screenshot is exactly what is on screen, because it actually takes a real screenshot of the simulator.

## Setup

There are two steps to make your app work with Screenshooter:

1. create the screenshot suite
2. create the configuraton file

### Screenshot Suite

The screenshot suite is the client-side definition of how every screenshot is taken. Create a new entrypoint to your application (by default `lib/screenshots.dart`) and add a `ScreenshotSuite` instance and run it. A simple suite could look like this:

```dart
// lib/screenshots.dart

import 'main.dart' as main;

void main() {
    ScreenshotSuite(
        name: 'default',
        prepare: () async {
            // This is executed before everything else.
            // You will need to start the real app here
            main.main();
        },
        prepareLocale: (ScreenshotLocale locale) async {
            // If you specify locales in the config later, this will be called
            // for every locale. You probably want to set your locale here
            setAppLocale(locale); 
        },
        cleanupLocale: (ScreenshotLocale locale) async {
            // Same as prepareLocale but obviously runs after taking 
            // the screenshots for the locale
            clearCache();
        },
        cleanup: () {
            removeData();
        },
        screenshots: [...]
    ).run();
}
```

The screenshots are each described by a `Screenshot` instance, which is pretty self-explanatory:

```dart
final screenshot = Screenshot(
    // a unique name for the screenshot
    name: 'home',
    // delay after calling prepare (e.g. waiting for images to load)
    delay: const Duration(seconds: 1),
    prepare: () async {
        await navigateToHome();
    },
    cleanup: () async {
        // perform some cleanup
    }
);
```

NOTE: All methods return a `Future<void>` which is awaited before proceeding so you don't have to worry about a screenshot being taken before things are ready.

#### Screenshot Configuration

If you want to access configuration variables at runtime you can use `ScreenshotConfiguration.fromEnv`. This is a constant value so it will not slow down your application when e.g. used in if statements.
To find out if the app is currently running in screenshot mode use `ScreenshotConfiguration.fromEnv.isActive`.

If you want to log in an example user you can access `ScreenshotConfiguration.fromEnv.username` and `ScreenshotConfiguration.fromEnv.password` which will be filled with the values password to screenshooter.

### Configuration File

After setting up your screenshot suite you will need to specify how it will be run. Even though at this point you could just run screenshooter with CLI arguments, it is recommended to use a configuration file. By default the `screenshooter.yaml` file will be used with the fallback being the `screenshooter` key in the `pubspec.yaml` (see [Usage](#usage)).

Using a config file will also enable you to efficiently take screenshots for multiple simulators.

This is an example of such a config file with all possible options - they are not needed however:

```yaml
# screenshooter.yaml

bundleId: com.example.app
# This is the path for every screenshot. Placeholders:
# - {locale} will be replaced by the current locales language tag (BCP47)
# - {name} is replaced by the name specified in the `Screenshot`
# - {device} is replaced by the device identifier (as specified in `devices`)
path: screenshots/{locale}/{name}_{device}.png
# All locales to create screenshots for (in BCP47 format with `-` separators). If you omit this
# the screenshots are just taken once and the {locale} placeholder in the `path` will have the
# value `none`
locales:
  - en-US
  - de-DE
# This is a list of all the simulators to use. The key is the exact name of the iOS Simulator
# and the value is the identifier used 
devices:
  iPhone 14 Plus: iphone_65
  iPhone 8 Plus: iphone_55
```

## Usage

To run screenshooter use `dart run screenshooter` in your projects root directory. By default it will try to find a `screenshooter.yaml` file to read the configuration from. If that doesn't exist it will look for a `screenshooter` key in the `pubspec.yaml`.

To load another configuration file (for example if you have multiple configs) use `dart run screenshooter -f <name of your config.yaml>`

Use `dart run screenshooter --help` for info on all the CLI arguments.
