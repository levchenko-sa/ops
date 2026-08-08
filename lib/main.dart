import 'package:flutter/material.dart';

import 'database/app_database.dart';
import 'screens/home_screen.dart';
import 'theme/app_themes.dart';
import 'theme/appearance_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppDatabase.instance.database;
  await AppearanceController.instance.load();

  runApp(const OpsControlApp());
}

class OpsControlApp extends StatelessWidget {
  const OpsControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceController.instance;

    return AnimatedBuilder(
      animation: appearance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'OPS Control',
          theme: AppThemes.forChoice(appearance.themeChoice),
          builder: (context, child) {
            final media = MediaQuery.of(context);

            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  appearance.textScale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
