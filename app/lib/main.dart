import 'package:flutter/material.dart';

import 'api.dart';
import 'home.dart';
import 'settings.dart';
import 'theme.dart';

void main() => runApp(DalilApp(api: HttpDalilApi()));

class DalilApp extends StatelessWidget {
  const DalilApp({super.key, required this.api});
  final DalilApi api;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, mode, _) => ValueListenableBuilder<double>(
        valueListenable: AppSettings.textScale,
        builder: (context, scale, __) => MaterialApp(
          title: 'Dalil',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * scale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomePage(api: api),
        ),
      ),
    );
  }
}
