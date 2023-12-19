// lib/screenshots.dart

import 'package:flutter/material.dart';
import 'package:screenshooter/screenshooter.dart';

import 'main.dart' as app;

void main() {
  ScreenshotSuite(
    name: 'default',
    prepare: () async {
      // This is executed before everything else.
      // You will need to start the real app here
      app.main();
    },
    cleanup: () async {},
    prepareLocale: (ScreenshotLocale locale) async {
      // If you specify locales in the config later, this will be called
      // for every locale. You probably want to set your locale here

      app.setLocale(Locale(locale.languageCode, locale.countryCode));
    },
    cleanupLocale: (ScreenshotLocale locale) async {
      // Same as prepareLocale but obviously runs after taking
      // the screenshots for the locale
    },
    screenshots: [
      Screenshot(
        // a unique name for the screenshot
        name: 'home',
        // delay after calling prepare (e.g. waiting for images to load)
        delay: const Duration(seconds: 2),
        prepare: () async {
          app.rootNavigatorKey.currentState!.popUntil((route) => route.isFirst);
          app.rootNavigatorKey.currentState!.pushReplacementNamed('/');
        },
        cleanup: () async {
          // perform some cleanup
        },
      ),
      Screenshot(
        name: 'other',
        delay: const Duration(seconds: 5),
        prepare: () async {
          app.rootNavigatorKey.currentState!.pushNamed('/other');
        },
      ),
    ],
  ).run();
}
