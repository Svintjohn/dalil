import 'package:flutter/material.dart';

import 'api.dart';
import 'home.dart';
import 'profile.dart';
import 'season.dart';
import 'settings.dart';
import 'sfx.dart';
import 'sound_pill.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Profile.instance.load();
  Sfx.instance.load();
  SeasonSettings.instance.load();
  Sfx.instance.attach();
  runApp(DalilApp(api: HttpDalilApi()));
}

class DalilApp extends StatelessWidget {
  const DalilApp({super.key, required this.api});
  final DalilApi api;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, mode, _) => ValueListenableBuilder<double>(
        valueListenable: AppSettings.textScale,
        builder: (context, scale, __) => ValueListenableBuilder<String>(
          valueListenable: Profile.instance.look, // the colour or the font changed
          builder: (context, _, ___) => MaterialApp(
            title: 'Dalil',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light, accent: Profile.instance.accent),
            darkTheme: buildTheme(Brightness.dark, accent: Profile.instance.accent),
            themeMode: mode,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * scale)),
                child: TapSounds(child: child ?? const SizedBox.shrink()),
              );
            },
            home: HomePage(api: api),
          ),
        ),
      ),
    );
  }
}
