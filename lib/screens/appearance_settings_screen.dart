import 'package:flutter/material.dart';

import '../theme/app_themes.dart';
import '../theme/appearance_controller.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  AppearanceController get _controller => AppearanceController.instance;

  Widget _themePreview(
    BuildContext context,
    AppThemeChoice choice,
  ) {
    final theme = AppThemes.forChoice(choice);
    final scheme = theme.colorScheme;

    return Theme(
      data: theme,
      child: Container(
        width: 82,
        height: 50,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 35,
              height: 6,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.onSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 16,
                  height: 13,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeTile(
    BuildContext context,
    AppThemeChoice choice,
  ) {
    final selected = _controller.themeChoice == choice;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _controller.setTheme(choice),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              _themePreview(context, choice),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choice.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      choice.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Оформление'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Тема',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              _themeTile(context, AppThemeChoice.light),
              const SizedBox(height: 10),
              _themeTile(context, AppThemeChoice.dark),
              const SizedBox(height: 10),
              _themeTile(context, AppThemeChoice.black),
              const SizedBox(height: 20),
              Text(
                'Читаемость',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Card(
                child: SwitchListTile(
                  title: const Text('Крупнее текст'),
                  subtitle: const Text(
                    'Увеличивает интерфейсный текст примерно на 8% '
                    'без изменения структуры экранов.',
                  ),
                  value: _controller.largeText,
                  onChanged: _controller.setLargeText,
                  secondary: const Icon(Icons.text_fields),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Тёмная тема использует не чёрный, а тёмно-серый '
                    'фон — так меньше резких перепадов яркости. '
                    'Чёрная AMOLED использует настоящий чёрный фон, '
                    'но основной текст сделан светло-серым, а не '
                    'ослепительно белым. Красный, оранжевый и зелёный '
                    'оставлены только для статусов и предупреждений.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
