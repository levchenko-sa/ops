import 'package:flutter/material.dart';

import '../models/organization_profile.dart';
import '../repositories/ops_repository.dart';

class OrganizationSettingsScreen extends StatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  State<OrganizationSettingsScreen> createState() =>
      _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState
    extends State<OrganizationSettingsScreen> {
  final _repo = OpsRepository();

  final _fullName = TextEditingController();
  final _shortName = TextEditingController();
  final _inn = TextEditingController();
  final _kpp = TextEditingController();
  final _address = TextEditingController();
  final _directorPosition =
      TextEditingController(text: 'Руководитель');
  final _directorName = TextEditingController();
  final _accountantPosition =
      TextEditingController(text: 'Главный бухгалтер');
  final _accountantName = TextEditingController();
  final _responsiblePosition = TextEditingController(
    text: 'Материально ответственное лицо',
  );
  final _responsibleName = TextEditingController();
  final _orderNo = TextEditingController();
  final _orderDate = TextEditingController();

  String _regime = 'commercial';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _shortName,
      _inn,
      _kpp,
      _address,
      _directorPosition,
      _directorName,
      _accountantPosition,
      _accountantName,
      _responsiblePosition,
      _responsibleName,
      _orderNo,
      _orderDate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final p = await _repo.getOrganizationProfile();

    _fullName.text = p.fullName;
    _shortName.text = p.shortName;
    _inn.text = p.inn;
    _kpp.text = p.kpp;
    _address.text = p.legalAddress;
    _directorPosition.text = p.directorPosition;
    _directorName.text = p.directorName;
    _accountantPosition.text = p.accountantPosition;
    _accountantName.text = p.accountantName;
    _responsiblePosition.text = p.materialResponsiblePosition;
    _responsibleName.text = p.materialResponsibleName;
    _orderNo.text = p.formsApprovalOrderNo;
    _orderDate.text = p.formsApprovalOrderDate;
    _regime = p.procurementRegime;

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_fullName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите полное наименование организации'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    await _repo.saveOrganizationProfile(
      OrganizationProfile(
        fullName: _fullName.text,
        shortName: _shortName.text,
        inn: _inn.text,
        kpp: _kpp.text,
        legalAddress: _address.text,
        directorPosition: _directorPosition.text,
        directorName: _directorName.text,
        accountantPosition: _accountantPosition.text,
        accountantName: _accountantName.text,
        materialResponsiblePosition: _responsiblePosition.text,
        materialResponsibleName: _responsibleName.text,
        formsApprovalOrderNo: _orderNo.text,
        formsApprovalOrderDate: _orderDate.text,
        procurementRegime: _regime,
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Реквизиты сохранены')),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Организация и документы')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Реквизиты организации',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _field(_fullName, 'Полное наименование *'),
          _field(_shortName, 'Краткое наименование'),
          _field(
            _inn,
            'ИНН',
            keyboard: TextInputType.number,
          ),
          _field(
            _kpp,
            'КПП',
            keyboard: TextInputType.number,
          ),
          _field(_address, 'Юридический адрес'),
          const SizedBox(height: 8),
          Text(
            'Подписанты',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _field(_directorPosition, 'Должность руководителя'),
          _field(_directorName, 'Ф.И.О. руководителя'),
          _field(_accountantPosition, 'Должность бухгалтера'),
          _field(_accountantName, 'Ф.И.О. бухгалтера'),
          _field(
            _responsiblePosition,
            'Должность материально ответственного лица',
          ),
          _field(
            _responsibleName,
            'Ф.И.О. материально ответственного лица',
          ),
          const SizedBox(height: 8),
          Text(
            'Утверждение форм первичных документов',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _field(
            _orderNo,
            'Приказ об утверждении форм, №',
          ),
          _field(
            _orderDate,
            'Дата приказа (например 01.08.2026)',
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _regime,
            decoration: const InputDecoration(
              labelText: 'Режим закупок',
              prefixIcon: Icon(Icons.gavel_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'commercial',
                child: Text('Обычная хозяйственная закупка'),
              ),
              DropdownMenuItem(
                value: '44fz',
                child: Text('Заказчик по 44-ФЗ'),
              ),
              DropdownMenuItem(
                value: '223fz',
                child: Text('Заказчик по 223-ФЗ'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _regime = value);
            },
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Для акта списания эти реквизиты используются '
                'как реквизиты первичного учетного документа. '
                'Форма должна быть утверждена руководителем организации. '
                'Сформированный PDF требует подписи уполномоченных лиц.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
