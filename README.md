# Screenshooter

Automatically create screenshots of your flutter app.

## Working Principle

Screenshooter works by building a special version of your app (with a different entrypoint) and running that on an iOS simulator. This app will execute the steps you specify and notify the host when it should take the screenshot. This way you can be sure that the screenshot is exactly what is on screen, because it actually takes a real screenshot of the simulator.

## Setup

There are two steps to make your app work with Screenshooter:

1. create the screenshot suite
2. create the configuraton file
3. (optional) add configuration for framing

### Screenshot Suite

The screenshot suite is the client-side definition of how every screenshot is taken. Create a new entrypoint to your application (by default `lib/screenshots.dart`) and add a `ScreenshotSuite` instance and run it. A simple suite could look like this:

```dart
// lib/screenshots.dart

import 'main.dart' as app;

void main() {
    ScreenshotSuite(
        name: 'default',
        prepare: () async {
            // This is executed before everything else.
            // You will need to start the real app here
            app.main();
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

If you want to log in an example user you can access `ScreenshotConfiguration.fromEnv.username` and `ScreenshotConfiguration.fromEnv.password` which will be filled with the values passed to screenshooter. These values come from the CLI args `--username` and `--password` or as (recommended) fallback from the environment variables `SCREENSHOOTER_USERNAME` and `SCREENSHOOTER_PASSWORD`.

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
# and the value is the identifier used.
devices:
  iPhone 14 Plus: iphone_65
  iPhone 8 Plus: iphone_55
# The name of the file to use as the entrypoint for the app.
target: lib/screenshots.dart
```

## Usage

To run screenshooter use `dart run screenshooter` in your projects root directory. By default it will try to find a `screenshooter.yaml` file to read the configuration from. If that doesn't exist it will look for a `screenshooter` key in the `pubspec.yaml`.

To load another configuration file (for example if you have multiple configs) use `dart run screenshooter -f <name of your config.yaml>`

Use `dart run screenshooter --help` for info on all the CLI arguments.

## Adding Device Frames

Screenshooter also includes a fast implementation for framing screenshots. This step is entirely optional and separate from taking the screenshots. Use `dart run screenshooter:frame` to run this postprocessing after creating the screenshots.

In addition to adding a device frame, this tool can also add text on top of the frame using the `titles`. The resulting image is kept in the same size as the original screenshot.

This uses the meta device frames because they are freely available and fairly current. For image processing ImageMagick is used as it is significantly faster than anything that purely uses Dart. The device frames are downloaded automatically into the `~/.cache/screenshooter-device-frames` directory. To find good `frameSelectors` you can have a look in there.

NOTE: The download link for the device frames is not static and has to be parsed from an HTML page. The tool should do this automatically but it might fail. To circumvent this, you can download the archive manually from <https://design.facebook.com/toolsandresources/devices/> and unpack it to `~/.cache/screenshooter-device-frames` so that the subdirectory `Meta Devices` contains the folders for the devices.

### Notes

#### How is the title selected?

Every titles key is checked against the filename of the screenshot. The first title whose key is contained in the filename is used.

#### How is the device frame selected?

The device name from the screenshooter configuration is used. In the config the name is the key inside the `devices` map. You can override this name by specifying another one in the `deviceFrameNames` object (see below).

### Configuration

The configuration is read from `screenshooter.frames.yaml`. If this file does not exist, the config is loaded from the `frames` key in `screenshooter.yaml` or `pubspec.yaml`.

These are all options that are available though not all are required:

```yaml
# The text to add at the top of each screenshot. The languages correspond to the
# languages in the `locales` section of the `screenshooter.yaml` file.
# The first key from this file (e.g. "home", "account") that is found verbatim in the
# filename of the screenshot is selected.
titles:
  en-US:
    home: This is the home screen
    account: This is the account screen
  de-DE:
    shop: Das ist der Home-Bildschirm
    account: Das ist der Konto-Bildschirm

# Appended to the filename of the screenshot after framing it.
suffixFrame: _framed
# Appended to the filename of the screenshot after adding the text.
suffixText: _text

# Criteria to select which frames to use. If there are multiple matches in one level in the
# directory hierarchy, the shortest one is used.
frameSelectors:
  - shadow
  - white
  - silver
  - starlight
# Override the device name used to select the frame. The key is the device identifier from the screenshooter configuration. The value is the name to use for finding a matching frame instead of the simulator name.
deviceFrameNames:
  iphone_55: iPhone SE # The "(3rd generation)" is left out for the name of the frame

# The background color for the screenshot. Can be either a hex color or a color name
# as recognized by ImageMagick.
background: black
# The amount of padding on each side in percent. Relative to the width of
# the screenshot.
paddingPercent: 5

# Settings regarding the font used for the title.
font: ./fonts/OpenSans/OpenSans-Bold.ttf
fontSize: 75
fontColor: white
```
