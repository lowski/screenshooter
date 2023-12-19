import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final appKey = GlobalKey<_MyAppState>();

Locale locale = const Locale('en', 'US');
List<Locale> locales = [
  const Locale('en', 'US'),
  const Locale('de', 'DE'),
];

void setLocale(Locale l) {
  locale = l;
  appKey.currentState?.restart();
}

class MyApp extends StatefulWidget {
  MyApp() : super(key: appKey);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Key key = UniqueKey();

  void restart() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screenshooter Demo',
      key: key,
      navigatorKey: rootNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: locale.countryCode == 'US' ? Colors.blue : Colors.green,
        ),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const CustomPage(
              title: 'Home Page',
              isHome: true,
            ),
        '/other': (context) => const CustomPage(
              title: 'Other Page',
              isHome: false,
            ),
      },
    );
  }
}

class CustomPage extends StatelessWidget {
  final String title;
  final bool isHome;

  const CustomPage({
    super.key,
    required this.title,
    required this.isHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Locale: $locale',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () {
                setLocale(locales.firstWhere((element) => element != locale));
              },
              child: Text(
                'Switch to ${locales.firstWhere((element) => element != locale)}',
              ),
            ),
            if (isHome)
              ElevatedButton(
                onPressed: () {
                  rootNavigatorKey.currentState!.pushNamed('/other');
                },
                child: const Text('Go to other page →'),
              ),
          ],
        ),
      ),
    );
  }
}
