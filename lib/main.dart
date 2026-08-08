import 'dart:async';

import 'package:flutter/material.dart';

import 'database/app_database.dart';
import 'screens/home_screen.dart';
import 'theme/app_themes.dart';
import 'theme/appearance_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ВАЖНО: UI запускается сразу. Инициализация БД и настроек выполняется
  // после runApp(), чтобы ошибка старта не оставляла Android на splash-screen.
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
          home: const _StartupGate(),
        );
      },
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<void> _initialize() async {
    await AppDatabase.instance.database.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException(
        'База данных не открылась за 20 секунд.',
      ),
    );

    await AppearanceController.instance.load().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'Настройки оформления не загрузились за 10 секунд.',
      ),
    );
  }

  void _retry() {
    setState(() {
      _startup = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Запуск OPS Control…',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Проверяем локальную базу данных',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Ошибка запуска'),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListView(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'OPS Control не смог завершить инициализацию.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      snapshot.error.toString(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const HomeScreen();
      },
    );
  }
}
