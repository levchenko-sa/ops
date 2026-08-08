import 'package:flutter/material.dart';

import '../services/photo_settings_service.dart';

class PhotoSettingsScreen extends StatefulWidget {
  const PhotoSettingsScreen({super.key});

  @override
  State<PhotoSettingsScreen> createState() => _PhotoSettingsScreenState();
}

class _PhotoSettingsScreenState extends State<PhotoSettingsScreen> {
  final _service = PhotoSettingsService();

  int _quality = 70;
  int _dimension = 1280;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _service.liteProfile();
    if (!mounted) return;
    setState(() {
      _quality = profile.jpegQuality;
      _dimension = profile.maxWidth.round();
      _loading = false;
    });
  }

  Future<void> _apply(int dimension, int quality) async {
    await _service.saveLiteProfile(
      jpegQuality: quality,
      maxDimension: dimension,
    );

    if (!mounted) return;
    setState(() {
      _dimension = dimension;
      _quality = quality;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Настройки фото сохранены'),
      ),
    );
  }

  Widget _preset({
    required String title,
    required String subtitle,
    required int dimension,
    required int quality,
  }) {
    final selected = _dimension == dimension && _quality == quality;

    return Card(
      child: RadioListTile<String>(
        value: '$dimension-$quality',
        groupValue: '$_dimension-$_quality',
        onChanged: (_) => _apply(dimension, quality),
        title: Text(title),
        subtitle: Text(subtitle),
        secondary: selected
            ? const Icon(Icons.check_circle)
            : const Icon(Icons.photo_outlined),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Качество фото')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _preset(
                  title: 'Максимальная экономия',
                  subtitle: '1024 px • JPEG 65% • самый маленький файл',
                  dimension: 1024,
                  quality: 65,
                ),
                _preset(
                  title: 'Лёгкий — рекомендуется',
                  subtitle:
                      '1280 px • JPEG 70% • хороший баланс размера и деталей',
                  dimension: 1280,
                  quality: 70,
                ),
                _preset(
                  title: 'Повышенная чёткость',
                  subtitle: '1600 px • JPEG 76% • для сложных объектов',
                  dimension: 1600,
                  quality: 76,
                ),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Для шильдиков, маркировки, номеров клемм и очень '
                      'мелких надписей в карточке работы можно временно '
                      'включить «Детальный режим». Он применяется только '
                      'к конкретному снимку и не меняет лёгкий режим '
                      'по умолчанию.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
