import 'package:flutter/material.dart';

import '../repositories/ops_repository.dart';
import 'appearance_settings_screen.dart';
import 'data_management_screen.dart';
import 'engineer_stock_screen.dart';
import 'import_screen.dart';
import 'inventory_documents_screen.dart';
import 'manual_request_screen.dart';
import 'objects_screen.dart';
import 'qr_scanner_screen.dart';
import 'reference_books_screen.dart';
import 'requests_screen.dart';
import 'route_screen.dart';
import 'warehouse_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = OpsRepository();

  int _objects = 0;
  int _requests = 0;
  int _sync = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final objects = await _repo.objectCount();
    final requests = await _repo.openRequestCount();
    final sync = await _repo.pendingSyncCount();

    if (!mounted) return;
    setState(() {
      _objects = objects;
      _requests = requests;
      _sync = sync;
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
    await _reload();
  }

  Widget _smallMetric(
    String title,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 8,
          ),
          child: Column(
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 5),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    String? subtitle,
    bool primary = false,
  }) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(title),
        ),
      );
    }

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OPS Control'),
        actions: [
          IconButton(
            onPressed: () => _open(const QrScannerScreen()),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'QR объекта',
          ),
          IconButton(
            onPressed: () =>
                _open(const AppearanceSettingsScreen()),
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Оформление',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _smallMetric(
                  'Объекты',
                  '$_objects',
                  Icons.apartment,
                ),
                const SizedBox(width: 8),
                _smallMetric(
                  'Открытые',
                  '$_requests',
                  Icons.assignment_outlined,
                ),
                const SizedBox(width: 8),
                _smallMetric(
                  'Очередь',
                  '$_sync',
                  Icons.sync,
                ),
              ],
            ),
            const SizedBox(height: 14),

            _action(
              title: 'Открытые заявки ($_requests)',
              icon: Icons.assignment,
              primary: true,
              onTap: () => _open(const RequestsScreen()),
            ),
            const SizedBox(height: 10),

            _action(
              title: 'Маршрут',
              subtitle: 'Заявки на сегодня',
              icon: Icons.route,
              onTap: () => _open(const RouteScreen()),
            ),
            const SizedBox(height: 8),

            _action(
              title: 'Объекты',
              subtitle: 'Поиск дома, паспорт, история',
              icon: Icons.apartment,
              onTap: () => _open(const ObjectsScreen()),
            ),
            const SizedBox(height: 8),

            _action(
              title: 'Новая заявка',
              icon: Icons.add_task,
              onTap: () => _open(const ManualRequestScreen()),
            ),
            const SizedBox(height: 8),

            _action(
              title: 'Импорт утреннего отчёта',
              icon: Icons.document_scanner_outlined,
              onTap: () => _open(const ImportScreen()),
            ),
            const SizedBox(height: 14),

            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Материалы'),
                subtitle: const Text(
                  'Открывать только когда нужно',
                ),
                children: [
                  ListTile(
                    onTap: () =>
                        _open(const EngineerStockScreen()),
                    leading: const Icon(
                      Icons.local_shipping_outlined,
                    ),
                    title: const Text('Мой запас / машина'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    onTap: () => _open(const WarehouseScreen()),
                    leading: const Icon(Icons.warehouse_outlined),
                    title: const Text('Основной склад'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    onTap: () =>
                        _open(const InventoryDocumentsScreen()),
                    leading: const Icon(
                      Icons.description_outlined,
                    ),
                    title: const Text('Закупка и документы'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.tune),
                title: const Text('Настройки'),
                subtitle: const Text(
                  'Редко используемые функции',
                ),
                children: [
                  ListTile(
                    onTap: () =>
                        _open(const ReferenceBooksScreen()),
                    leading: const Icon(
                      Icons.menu_book_outlined,
                    ),
                    title: const Text('Справочники'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    onTap: () =>
                        _open(const DataManagementScreen()),
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text(
                      'Резервные копии и данные',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
