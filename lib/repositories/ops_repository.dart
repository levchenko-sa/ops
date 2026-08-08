import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/material_item.dart';
import '../models/stock_transfer.dart';
import '../models/engineer_stock_item.dart';
import '../models/engineer.dart';
import '../models/stock_batch.dart';
import '../models/goods_receipt_item.dart';
import '../models/goods_receipt.dart';
import '../models/organization_profile.dart';
import '../models/inventory_document_item.dart';
import '../models/inventory_document.dart';
import '../models/object_history_entry.dart';
import '../models/object_equipment.dart';
import '../models/ops_object.dart';
import '../models/photo_record.dart';
import '../models/reference_value.dart';
import '../models/request_material.dart';
import '../models/stock_movement.dart';
import '../models/work_request.dart';
import '../services/report_parser.dart';

class OpsRepository {
  final AppDatabase _database = AppDatabase.instance;

  Future<List<OpsObject>> getObjects({
    String search = '',
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await _database.database;
    final query = search.trim();

    final rows = await db.query(
      'objects',
      where: query.isEmpty ? null : 'address LIKE ? COLLATE NOCASE',
      whereArgs: query.isEmpty ? null : ['%$query%'],
      orderBy: 'address COLLATE NOCASE',
      limit: limit,
      offset: offset,
    );

    return rows.map(OpsObject.fromMap).toList();
  }

  Future<OpsObject?> getObject(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'objects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OpsObject.fromMap(rows.first);
  }

  Future<OpsObject?> findObjectByAddress(String address) async {
    final db = await _database.database;
    final normalized =
        address.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    final rows = await db.query('objects');
    for (final row in rows) {
      final candidate = (row['address'] as String)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (candidate == normalized) {
        return OpsObject.fromMap(row);
      }
    }
    return null;
  }

  Future<int> addObject(String address) async {
    final db = await _database.database;
    return db.insert('objects', {
      'address': address,
      'system': 'Си-Норд AirPro',
    });
  }

  Future<int> createRequest({
    required int objectId,
    required String type,
    required int priority,
    String comment = '',
    String source = 'manual',
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('requests', {
      'object_id': objectId,
      'type': type,
      'priority': priority,
      'status': 'Новая',
      'comment': comment,
      'source': source,
      'created_at': now,
      'updated_at': now,
    });

    await _enqueue(
      entity: 'request',
      entityId: id,
      operation: 'create',
      payload: {
        'type': type,
        'priority': priority,
        'source': source,
      },
    );

    return id;
  }

  Future<int> importReport(String text) async {
    final parser = ReportParser();
    final items = parser.parse(text);
    var created = 0;

    for (final item in items) {
      var object = await findObjectByAddress(item.address);

      if (object == null) {
        final objectId = await addObject(item.address);
        object = OpsObject(
          id: objectId,
          address: item.address,
          system: 'Си-Норд AirPro',
        );
      }

      await createRequest(
        objectId: object.id!,
        type: item.type,
        priority: item.priority,
        comment: 'Создано из импортированного отчёта',
        source: 'import',
      );
      created++;
    }

    return created;
  }

  Future<List<WorkRequest>> getOpenRequests({
    int? objectId,
    int limit = 200,
  }) async {
    final db = await _database.database;
    final args = <Object?>[];
    var where = "r.status != 'Выполнена'";

    if (objectId != null) {
      where += ' AND r.object_id = ?';
      args.add(objectId);
    }

    final rows = await db.rawQuery('''
      SELECT
        r.*,
        o.address AS address
      FROM requests r
      JOIN objects o ON o.id = r.object_id
      WHERE $where
      ORDER BY r.priority DESC, r.created_at ASC
      LIMIT $limit
    ''', args);

    return rows.map(WorkRequest.fromMap).toList();
  }

  Future<void> updateRequestStatus(int id, String status) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'requests',
      {'status': status, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _enqueue(
      entity: 'request',
      entityId: id,
      operation: 'update',
      payload: {'status': status},
    );
  }

  Future<void> saveWorkReport({
    required int requestId,
    double? batteryVoltage,
    double? loopResistanceKohm,
    required String cause,
    required String workDone,
    required String result,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'work_reports',
      {
        'request_id': requestId,
        'battery_voltage': batteryVoltage,
        'loop_resistance_kohm': loopResistanceKohm,
        'cause': cause,
        'work_done': workDone,
        'result': result,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await updateRequestStatus(requestId, 'Выполнена');

    await _enqueue(
      entity: 'work_report',
      entityId: requestId,
      operation: 'upsert',
      payload: {
        'battery_voltage': batteryVoltage,
        'loop_resistance_kohm': loopResistanceKohm,
        'cause': cause,
        'work_done': workDone,
        'result': result,
      },
    );
  }

  Future<void> addPhoto({
    required int requestId,
    required String type,
    required String path,
    int fileSizeBytes = 0,
    String captureMode = 'lite',
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('photos', {
      'request_id': requestId,
      'type': type,
      'path': path,
      'created_at': now,
      'file_size_bytes': fileSizeBytes,
      'capture_mode': captureMode,
    });

    await _enqueue(
      entity: 'photo',
      entityId: id,
      operation: 'create',
      payload: {
        'request_id': requestId,
        'type': type,
        'path': path,
        'file_size_bytes': fileSizeBytes,
        'capture_mode': captureMode,
      },
    );
  }

  Future<List<PhotoRecord>> getPhotos(int requestId) async {
    final db = await _database.database;
    final rows = await db.query(
      'photos',
      where: 'request_id = ?',
      whereArgs: [requestId],
      orderBy: 'created_at',
    );
    return rows.map(PhotoRecord.fromMap).toList();
  }


  Future<List<RequestMaterial>> getRequestMaterials(
    int requestId,
  ) async {
    final db = await _database.database;
    final rows = await db.rawQuery("""
      SELECT
        rm.*,
        COALESCE(e.name, '') AS source_engineer_name
      FROM request_materials rm
      LEFT JOIN engineers e ON e.id = rm.source_engineer_id
      WHERE rm.request_id = ?
      ORDER BY rm.created_at ASC
    """, [requestId]);

    return rows.map(RequestMaterial.fromMap).toList();
  }

  Future<int> consumeMaterialForRequest({
    required int requestId,
    required int materialId,
    required double quantity,
    String comment = '',
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Количество должно быть больше нуля');
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    late int requestMaterialId;
    late String materialName;
    late String unit;
    late double balanceAfter;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'materials',
        where: 'id = ?',
        whereArgs: [materialId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Материал не найден');
      }

      materialName = rows.first['name'] as String;
      unit = rows.first['unit'] as String;
      final current = (rows.first['quantity'] as num).toDouble();

      if (quantity > current) {
        throw StateError(
          'Недостаточно на основном складе. Доступно: '
          '${current.toStringAsFixed(current % 1 == 0 ? 0 : 2)} $unit',
        );
      }

      balanceAfter = current - quantity;

      await txn.update(
        'materials',
        {'quantity': balanceAfter},
        where: 'id = ?',
        whereArgs: [materialId],
      );

      requestMaterialId = await txn.insert(
        'request_materials',
        {
          'request_id': requestId,
          'material_id': materialId,
          'material_name': materialName,
          'unit': unit,
          'quantity': quantity,
          'created_at': now,
          'source_kind': 'warehouse',
          'source_engineer_id': null,
        },
      );

      // Техническая трассировка FIFO только для связи с партиями.
      // Метод бухгалтерской оценки запасов приложение не задаёт.
      var toAllocate = quantity;
      final batches = await txn.query(
        'stock_batches',
        where: 'material_id = ? AND quantity_remaining > 0',
        whereArgs: [materialId],
        orderBy: 'received_at ASC, id ASC',
      );

      for (final batch in batches) {
        if (toAllocate <= 0.000001) break;

        final batchId = batch['id'] as int;
        final available =
            (batch['quantity_remaining'] as num).toDouble();
        final take = available < toAllocate ? available : toAllocate;

        if (take <= 0) continue;

        await txn.update(
          'stock_batches',
          {'quantity_remaining': available - take},
          where: 'id = ?',
          whereArgs: [batchId],
        );

        await txn.insert(
          'request_material_batch_allocations',
          {
            'request_material_id': requestMaterialId,
            'batch_id': batchId,
            'quantity': take,
          },
        );

        toAllocate -= take;
      }

      await txn.insert(
        'stock_movements',
        {
          'material_id': materialId,
          'request_id': requestId,
          'receipt_id': null,
          'engineer_id': null,
          'movement_type': 'consume',
          'quantity': -quantity,
          'balance_after': balanceAfter,
          'engineer_balance_after': null,
          'comment': comment.trim(),
          'created_at': now,
        },
      );
    });

    await _enqueue(
      entity: 'request_material',
      entityId: requestMaterialId,
      operation: 'create',
      payload: {
        'request_id': requestId,
        'material_id': materialId,
        'material_name': materialName,
        'unit': unit,
        'quantity': quantity,
        'source_kind': 'warehouse',
        'balance_after': balanceAfter,
        'comment': comment.trim(),
      },
    );

    return requestMaterialId;
  }

  Future<int> consumeEngineerMaterialForRequest({
    required int requestId,
    required int engineerId,
    required int materialId,
    required double quantity,
    String comment = '',
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Количество должно быть больше нуля');
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    late int requestMaterialId;
    late String materialName;
    late String unit;
    late String engineerName;
    late double engineerBalanceAfter;
    late double warehouseBalance;

    await db.transaction((txn) async {
      final engineerRows = await txn.query(
        'engineers',
        where: 'id = ? AND active = 1',
        whereArgs: [engineerId],
        limit: 1,
      );
      if (engineerRows.isEmpty) {
        throw StateError('Инженер не найден или отключён');
      }
      engineerName = engineerRows.first['name'] as String;

      final materialRows = await txn.query(
        'materials',
        where: 'id = ?',
        whereArgs: [materialId],
        limit: 1,
      );
      if (materialRows.isEmpty) {
        throw StateError('Материал не найден');
      }

      materialName = materialRows.first['name'] as String;
      unit = materialRows.first['unit'] as String;
      warehouseBalance =
          (materialRows.first['quantity'] as num).toDouble();

      final stockRows = await txn.query(
        'engineer_stock',
        where: 'engineer_id = ? AND material_id = ?',
        whereArgs: [engineerId, materialId],
        limit: 1,
      );

      final current = stockRows.isEmpty
          ? 0.0
          : (stockRows.first['quantity'] as num).toDouble();

      if (quantity > current) {
        throw StateError(
          'Недостаточно у $engineerName. Доступно: '
          '${current.toStringAsFixed(current % 1 == 0 ? 0 : 2)} $unit',
        );
      }

      engineerBalanceAfter = current - quantity;

      await txn.update(
        'engineer_stock',
        {'quantity': engineerBalanceAfter},
        where: 'engineer_id = ? AND material_id = ?',
        whereArgs: [engineerId, materialId],
      );

      requestMaterialId = await txn.insert(
        'request_materials',
        {
          'request_id': requestId,
          'material_id': materialId,
          'material_name': materialName,
          'unit': unit,
          'quantity': quantity,
          'created_at': now,
          'source_kind': 'engineer',
          'source_engineer_id': engineerId,
        },
      );

      var toAllocate = quantity;
      final batchRows = await txn.rawQuery("""
        SELECT
          esb.batch_id,
          esb.quantity,
          sb.received_at
        FROM engineer_stock_batches esb
        JOIN stock_batches sb ON sb.id = esb.batch_id
        WHERE esb.engineer_id = ?
          AND esb.material_id = ?
          AND esb.quantity > 0
        ORDER BY sb.received_at ASC, esb.batch_id ASC
      """, [engineerId, materialId]);

      for (final batch in batchRows) {
        if (toAllocate <= 0.000001) break;

        final batchId = batch['batch_id'] as int;
        final available = (batch['quantity'] as num).toDouble();
        final take = available < toAllocate ? available : toAllocate;

        await txn.update(
          'engineer_stock_batches',
          {'quantity': available - take},
          where: 'engineer_id = ? AND batch_id = ?',
          whereArgs: [engineerId, batchId],
        );

        await txn.insert(
          'request_material_batch_allocations',
          {
            'request_material_id': requestMaterialId,
            'batch_id': batchId,
            'quantity': take,
          },
        );

        toAllocate -= take;
      }

      await txn.insert(
        'stock_movements',
        {
          'material_id': materialId,
          'request_id': requestId,
          'receipt_id': null,
          'engineer_id': engineerId,
          'movement_type': 'consume_engineer',
          'quantity': -quantity,
          'balance_after': warehouseBalance,
          'engineer_balance_after': engineerBalanceAfter,
          'comment': comment.trim(),
          'created_at': now,
        },
      );
    });

    await _enqueue(
      entity: 'request_material',
      entityId: requestMaterialId,
      operation: 'create',
      payload: {
        'request_id': requestId,
        'material_id': materialId,
        'material_name': materialName,
        'unit': unit,
        'quantity': quantity,
        'source_kind': 'engineer',
        'source_engineer_id': engineerId,
        'source_engineer_name': engineerName,
        'engineer_balance_after': engineerBalanceAfter,
        'comment': comment.trim(),
      },
    );

    return requestMaterialId;
  }

  Future<void> removeRequestMaterial(int requestMaterialId) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    late int materialId;
    late int requestId;
    late double quantity;
    late double warehouseBalanceAfter;
    late String materialName;
    late String sourceKind;
    int? sourceEngineerId;
    double? engineerBalanceAfter;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'request_materials',
        where: 'id = ?',
        whereArgs: [requestMaterialId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Списание уже удалено');
      }

      final row = rows.first;
      materialId = row['material_id'] as int;
      requestId = row['request_id'] as int;
      quantity = (row['quantity'] as num).toDouble();
      materialName = row['material_name'] as String;
      sourceKind = row['source_kind'] as String? ?? 'warehouse';
      sourceEngineerId = row['source_engineer_id'] as int?;

      final materialRows = await txn.query(
        'materials',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [materialId],
        limit: 1,
      );

      if (materialRows.isEmpty) {
        throw StateError('Материал склада не найден');
      }

      final warehouseCurrent =
          (materialRows.first['quantity'] as num).toDouble();

      final allocations = await txn.query(
        'request_material_batch_allocations',
        where: 'request_material_id = ?',
        whereArgs: [requestMaterialId],
      );

      if (sourceKind == 'engineer' && sourceEngineerId != null) {
        final engineerStockRows = await txn.query(
          'engineer_stock',
          columns: ['quantity'],
          where: 'engineer_id = ? AND material_id = ?',
          whereArgs: [sourceEngineerId, materialId],
          limit: 1,
        );

        final engineerCurrent = engineerStockRows.isEmpty
            ? 0.0
            : (engineerStockRows.first['quantity'] as num).toDouble();
        engineerBalanceAfter = engineerCurrent + quantity;
        warehouseBalanceAfter = warehouseCurrent;

        await txn.insert(
          'engineer_stock',
          {
            'engineer_id': sourceEngineerId,
            'material_id': materialId,
            'quantity': engineerBalanceAfter,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final allocation in allocations) {
          final batchId = allocation['batch_id'] as int;
          final allocated =
              (allocation['quantity'] as num).toDouble();

          final rows = await txn.query(
            'engineer_stock_batches',
            columns: ['quantity'],
            where: 'engineer_id = ? AND batch_id = ?',
            whereArgs: [sourceEngineerId, batchId],
            limit: 1,
          );

          final current = rows.isEmpty
              ? 0.0
              : (rows.first['quantity'] as num).toDouble();

          await txn.insert(
            'engineer_stock_batches',
            {
              'engineer_id': sourceEngineerId,
              'batch_id': batchId,
              'material_id': materialId,
              'quantity': current + allocated,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await txn.insert(
          'stock_movements',
          {
            'material_id': materialId,
            'request_id': requestId,
            'receipt_id': null,
            'engineer_id': sourceEngineerId,
            'movement_type': 'return_engineer',
            'quantity': quantity,
            'balance_after': warehouseBalanceAfter,
            'engineer_balance_after': engineerBalanceAfter,
            'comment':
                'Возврат отменённого списания инженеру: $materialName',
            'created_at': now,
          },
        );
      } else {
        warehouseBalanceAfter = warehouseCurrent + quantity;

        for (final allocation in allocations) {
          final batchId = allocation['batch_id'] as int;
          final allocated =
              (allocation['quantity'] as num).toDouble();

          final batchRows = await txn.query(
            'stock_batches',
            columns: ['quantity_remaining'],
            where: 'id = ?',
            whereArgs: [batchId],
            limit: 1,
          );

          if (batchRows.isEmpty) continue;

          final remaining =
              (batchRows.first['quantity_remaining'] as num).toDouble();

          await txn.update(
            'stock_batches',
            {'quantity_remaining': remaining + allocated},
            where: 'id = ?',
            whereArgs: [batchId],
          );
        }

        await txn.update(
          'materials',
          {'quantity': warehouseBalanceAfter},
          where: 'id = ?',
          whereArgs: [materialId],
        );

        await txn.insert(
          'stock_movements',
          {
            'material_id': materialId,
            'request_id': requestId,
            'receipt_id': null,
            'engineer_id': null,
            'movement_type': 'return',
            'quantity': quantity,
            'balance_after': warehouseBalanceAfter,
            'engineer_balance_after': null,
            'comment': 'Возврат отменённого списания: $materialName',
            'created_at': now,
          },
        );
      }

      await txn.delete(
        'request_materials',
        where: 'id = ?',
        whereArgs: [requestMaterialId],
      );
    });

    await _enqueue(
      entity: 'request_material',
      entityId: requestMaterialId,
      operation: 'delete',
      payload: {
        'request_id': requestId,
        'material_id': materialId,
        'quantity': quantity,
        'source_kind': sourceKind,
        'source_engineer_id': sourceEngineerId,
        'balance_after': warehouseBalanceAfter,
        'engineer_balance_after': engineerBalanceAfter,
      },
    );
  }


  Future<List<StockMovement>> getStockMovements({
    int? materialId,
    int? requestId,
    int limit = 100,
  }) async {
    final db = await _database.database;

    final clauses = <String>[];
    final args = <Object?>[];

    if (materialId != null) {
      clauses.add('material_id = ?');
      args.add(materialId);
    }
    if (requestId != null) {
      clauses.add('request_id = ?');
      args.add(requestId);
    }

    final whereSql =
        clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';

    final rows = await db.rawQuery("""
      SELECT
        sm.*,
        COALESCE(e.name, '') AS engineer_name
      FROM stock_movements sm
      LEFT JOIN engineers e ON e.id = sm.engineer_id
      $whereSql
      ORDER BY sm.created_at DESC
      LIMIT ?
    """, [
      ...args,
      limit,
    ]);

    return rows.map(StockMovement.fromMap).toList();
  }


  Future<OrganizationProfile> getOrganizationProfile() async {
    final db = await _database.database;
    final rows = await db.query(
      'organization_profile',
      where: 'id = 1',
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Профиль организации не создан');
    }

    return OrganizationProfile.fromMap(rows.first);
  }

  Future<void> saveOrganizationProfile(
    OrganizationProfile profile,
  ) async {
    final db = await _database.database;
    await db.update(
      'organization_profile',
      {
        'full_name': profile.fullName.trim(),
        'short_name': profile.shortName.trim(),
        'inn': profile.inn.trim(),
        'kpp': profile.kpp.trim(),
        'legal_address': profile.legalAddress.trim(),
        'director_position': profile.directorPosition.trim(),
        'director_name': profile.directorName.trim(),
        'accountant_position': profile.accountantPosition.trim(),
        'accountant_name': profile.accountantName.trim(),
        'material_responsible_position':
            profile.materialResponsiblePosition.trim(),
        'material_responsible_name':
            profile.materialResponsibleName.trim(),
        'forms_approval_order_no':
            profile.formsApprovalOrderNo.trim(),
        'forms_approval_order_date':
            profile.formsApprovalOrderDate.trim(),
        'procurement_regime': profile.procurementRegime.trim(),
      },
      where: 'id = 1',
    );

    await _enqueue(
      entity: 'organization_profile',
      entityId: 1,
      operation: 'update',
      payload: {
        'full_name': profile.fullName,
        'inn': profile.inn,
        'kpp': profile.kpp,
        'procurement_regime': profile.procurementRegime,
      },
    );
  }

  Future<void> updateMaterialAccountingPrice(
    int materialId,
    double price,
  ) async {
    if (price < 0) return;

    final db = await _database.database;
    await db.update(
      'materials',
      {'accounting_price': price},
      where: 'id = ?',
      whereArgs: [materialId],
    );
  }


  Future<void> updateMaterialPlanning({
    required int materialId,
    required double minQuantity,
    required double accountingPrice,
  }) async {
    if (minQuantity < 0 || accountingPrice < 0) {
      throw ArgumentError('Значения не могут быть отрицательными');
    }

    final db = await _database.database;
    await db.update(
      'materials',
      {
        'min_quantity': minQuantity,
        'accounting_price': accountingPrice,
      },
      where: 'id = ?',
      whereArgs: [materialId],
    );
  }

  Future<List<MaterialItem>> getLowStockMaterials() async {
    final db = await _database.database;

    // Для закупки учитываем запас организации целиком:
    // основной склад + мобильные запасы инженеров.
    final rows = await db.rawQuery("""
      SELECT
        m.id,
        m.name,
        m.unit,
        m.min_quantity,
        m.accounting_price,
        (
          m.quantity +
          COALESCE(SUM(es.quantity), 0)
        ) AS quantity
      FROM materials m
      LEFT JOIN engineer_stock es ON es.material_id = m.id
      GROUP BY
        m.id,
        m.name,
        m.unit,
        m.min_quantity,
        m.accounting_price,
        m.quantity
      HAVING (
        m.quantity +
        COALESCE(SUM(es.quantity), 0)
      ) <= m.min_quantity
      ORDER BY m.name COLLATE NOCASE
    """);

    return rows.map(MaterialItem.fromMap).toList();
  }

  Future<String> _nextInventoryDocumentNumber(
    DatabaseExecutor txn,
    String documentType,
  ) async {
    final key = documentType == 'purchase_request'
        ? 'purchase_request_next_number'
        : 'writeoff_act_next_number';

    final rows = await txn.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    final current = rows.isEmpty
        ? 1
        : int.tryParse(rows.first['value'] as String? ?? '') ?? 1;

    await txn.insert(
      'app_settings',
      {
        'key': key,
        'value': (current + 1).toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final prefix = documentType == 'purchase_request' ? 'ЗЗ' : 'АС';
    final year = DateTime.now().year;
    return '$prefix-$year-${current.toString().padLeft(5, '0')}';
  }

  Future<int> createInventoryDocument({
    required String documentType,
    required String title,
    required String contentDescription,
    required String basis,
    int? sourceRequestId,
    required List<Map<String, Object?>> items,
  }) async {
    if (items.isEmpty) {
      throw StateError('В документе нет позиций');
    }

    final profile = await getOrganizationProfile();
    final db = await _database.database;
    final now = DateTime.now();

    late int documentId;
    late String documentNumber;

    await db.transaction((txn) async {
      documentNumber = await _nextInventoryDocumentNumber(
        txn,
        documentType,
      );

      documentId = await txn.insert(
        'inventory_documents',
        {
          'document_type': documentType,
          'document_number': documentNumber,
          'document_date': now.toIso8601String(),
          'status': 'draft',
          'title': title,
          'organization_name': profile.fullName,
          'organization_inn': profile.inn,
          'organization_kpp': profile.kpp,
          'content_description': contentDescription,
          'basis': basis,
          'source_request_id': sourceRequestId,
          'creator_position': profile.materialResponsiblePosition,
          'creator_name': profile.materialResponsibleName,
          'accountant_position': profile.accountantPosition,
          'accountant_name': profile.accountantName,
          'approver_position': profile.directorPosition,
          'approver_name': profile.directorName,
          'responsible_position': profile.materialResponsiblePosition,
          'responsible_name': profile.materialResponsibleName,
          'forms_approval_order_no': profile.formsApprovalOrderNo,
          'forms_approval_order_date': profile.formsApprovalOrderDate,
          'procurement_regime': profile.procurementRegime,
          'pdf_path': '',
          'created_at': now.toIso8601String(),
        },
      );

      for (final item in items) {
        final quantity =
            (item['quantity'] as num?)?.toDouble() ?? 0;
        final unitPrice =
            (item['unit_price'] as num?)?.toDouble() ?? 0;

        await txn.insert(
          'inventory_document_items',
          {
            'document_id': documentId,
            'material_id': item['material_id'],
            'item_name': item['item_name'] as String,
            'unit': item['unit'] as String,
            'quantity': quantity,
            'unit_price': unitPrice,
            'amount': quantity * unitPrice,
            'comment': item['comment'] as String? ?? '',
          },
        );
      }
    });

    await _enqueue(
      entity: 'inventory_document',
      entityId: documentId,
      operation: 'create',
      payload: {
        'document_type': documentType,
        'document_number': documentNumber,
        'source_request_id': sourceRequestId,
      },
    );

    return documentId;
  }

  Future<InventoryDocument?> getInventoryDocument(
    int documentId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'inventory_documents',
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return InventoryDocument.fromMap(rows.first);
  }

  Future<List<InventoryDocumentItem>> getInventoryDocumentItems(
    int documentId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'inventory_document_items',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'id',
    );

    return rows.map(InventoryDocumentItem.fromMap).toList();
  }


  Future<void> updateInventoryDocumentItem({
    required int itemId,
    required double quantity,
    required double unitPrice,
    String comment = '',
  }) async {
    if (quantity <= 0 || unitPrice < 0) {
      throw ArgumentError('Некорректное количество или цена');
    }

    final db = await _database.database;
    await db.update(
      'inventory_document_items',
      {
        'quantity': quantity,
        'unit_price': unitPrice,
        'amount': quantity * unitPrice,
        'comment': comment.trim(),
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<List<InventoryDocument>> getInventoryDocuments({
    String? documentType,
    int limit = 100,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'inventory_documents',
      where: documentType == null ? null : 'document_type = ?',
      whereArgs: documentType == null ? null : [documentType],
      orderBy: 'document_date DESC',
      limit: limit,
    );

    return rows.map(InventoryDocument.fromMap).toList();
  }

  Future<void> updateInventoryDocumentPdfPath(
    int documentId,
    String pdfPath,
  ) async {
    final db = await _database.database;
    await db.update(
      'inventory_documents',
      {
        'pdf_path': pdfPath,
        'status': 'prepared',
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<int?> getWriteoffDocumentIdForRequest(
    int requestId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'inventory_documents',
      columns: ['id'],
      where:
          "document_type = 'writeoff_act' AND source_request_id = ?",
      whereArgs: [requestId],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<int?> prepareWriteoffIfPossible(
    int requestId,
  ) async {
    final existing = await getWriteoffDocumentIdForRequest(requestId);
    if (existing != null) return existing;

    final materials = await getRequestMaterials(requestId);
    if (materials.isEmpty) return null;

    final profile = await getOrganizationProfile();
    if (!profile.hasMinimumLegalDetails) return null;

    return createWriteoffDocumentForRequest(requestId);
  }

  Future<int> createWriteoffDocumentForRequest(
    int requestId,
  ) async {
    final db = await _database.database;

    final requestRows = await db.rawQuery("""
      SELECT r.id, r.type, r.status, r.created_at, o.address
      FROM requests r
      JOIN objects o ON o.id = r.object_id
      WHERE r.id = ?
      LIMIT 1
    """, [requestId]);

    if (requestRows.isEmpty) {
      throw StateError('Заявка не найдена');
    }

    final materialRows = await db.rawQuery("""
      SELECT
        rm.material_id,
        rm.material_name,
        rm.unit,
        SUM(rm.quantity) AS quantity,
        COALESCE(m.accounting_price, 0) AS unit_price
      FROM request_materials rm
      LEFT JOIN materials m ON m.id = rm.material_id
      WHERE rm.request_id = ?
      GROUP BY
        rm.material_id,
        rm.material_name,
        rm.unit,
        m.accounting_price
      ORDER BY rm.material_name
    """, [requestId]);

    if (materialRows.isEmpty) {
      throw StateError(
        'По этой заявке нет списанных материалов',
      );
    }

    final request = requestRows.first;
    final address = request['address'] as String;
    final type = request['type'] as String;

    final items = materialRows.map((row) {
      return <String, Object?>{
        'material_id': row['material_id'],
        'item_name': row['material_name'],
        'unit': row['unit'],
        'quantity': (row['quantity'] as num).toDouble(),
        'unit_price':
            (row['unit_price'] as num?)?.toDouble() ?? 0,
        'comment': 'Заявка №$requestId, $address',
      };
    }).toList();

    return createInventoryDocument(
      documentType: 'writeoff_act',
      title: 'Акт списания материальных ценностей',
      contentDescription:
          'Списание материалов, фактически использованных '
          'при выполнении работ на объекте $address.',
      basis: 'Заявка №$requestId: $type',
      sourceRequestId: requestId,
      items: items,
    );
  }

  Future<int> createPurchaseRequestFromLowStock() async {
    final lowStock = await getLowStockMaterials();
    if (lowStock.isEmpty) {
      throw StateError(
        'Позиции ниже минимального остатка отсутствуют',
      );
    }

    final items = lowStock.map((material) {
      final target = material.minQuantity <= 0
          ? 1.0
          : material.minQuantity * 2;
      final suggested = (target - material.quantity)
          .clamp(1.0, double.infinity)
          .toDouble();

      return <String, Object?>{
        'material_id': material.id,
        'item_name': material.name,
        'unit': material.unit,
        'quantity': suggested,
        'unit_price': material.accountingPrice,
        'comment':
            'Остаток ${material.quantity}; минимум '
            '${material.minQuantity}',
      };
    }).toList();

    return createInventoryDocument(
      documentType: 'purchase_request',
      title: 'Заявка на закупку материальных ценностей',
      contentDescription:
          'Пополнение складских запасов до нормативного уровня.',
      basis:
          'Минимальные складские остатки OPS Control',
      items: items,
    );
  }


  Future<String> _nextGoodsReceiptNumber(
    DatabaseExecutor txn,
  ) async {
    const key = 'goods_receipt_next_number';

    final rows = await txn.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    final current = rows.isEmpty
        ? 1
        : int.tryParse(rows.first['value'] as String? ?? '') ?? 1;

    await txn.insert(
      'app_settings',
      {
        'key': key,
        'value': (current + 1).toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return 'ПМ-${DateTime.now().year}-'
        '${current.toString().padLeft(5, '0')}';
  }

  Future<List<InventoryDocument>> getOpenPurchaseRequests({
    int limit = 100,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'inventory_documents',
      where:
          "document_type = 'purchase_request' "
          "AND status NOT IN ('fulfilled', 'cancelled')",
      orderBy: 'document_date DESC',
      limit: limit,
    );

    return rows.map(InventoryDocument.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> getPurchaseRequestRemainingItems(
    int purchaseDocumentId,
  ) async {
    final db = await _database.database;

    return db.rawQuery("""
      SELECT
        i.material_id,
        i.item_name,
        i.unit,
        SUM(i.quantity) AS requested_quantity,
        COALESCE((
          SELECT SUM(gri.quantity)
          FROM goods_receipt_items gri
          JOIN goods_receipts gr ON gr.id = gri.receipt_id
          WHERE gr.purchase_document_id = i.document_id
            AND gr.status = 'posted'
            AND gri.material_id = i.material_id
        ), 0) AS received_quantity,
        MAX(i.unit_price) AS planned_unit_price
      FROM inventory_document_items i
      WHERE i.document_id = ?
        AND i.material_id IS NOT NULL
      GROUP BY
        i.document_id,
        i.material_id,
        i.item_name,
        i.unit
      ORDER BY i.item_name
    """, [purchaseDocumentId]);
  }

  Future<int> postGoodsReceipt({
    int? purchaseDocumentId,
    required String supplierName,
    String supplierInn = '',
    required String supplierDocumentType,
    required String supplierDocumentNumber,
    required String supplierDocumentDate,
    String notes = '',
    required List<Map<String, Object?>> items,
  }) async {
    if (items.isEmpty) {
      throw StateError('В поступлении нет позиций');
    }

    final db = await _database.database;
    final now = DateTime.now();
    late int receiptId;
    late String receiptNumber;
    var totalAmount = 0.0;

    await db.transaction((txn) async {
      receiptNumber = await _nextGoodsReceiptNumber(txn);

      receiptId = await txn.insert(
        'goods_receipts',
        {
          'receipt_number': receiptNumber,
          'receipt_date': now.toIso8601String(),
          'status': 'posted',
          'purchase_document_id': purchaseDocumentId,
          'supplier_name': supplierName.trim(),
          'supplier_inn': supplierInn.trim(),
          'supplier_document_type':
              supplierDocumentType.trim().isEmpty
                  ? 'УПД'
                  : supplierDocumentType.trim(),
          'supplier_document_number':
              supplierDocumentNumber.trim(),
          'supplier_document_date':
              supplierDocumentDate.trim(),
          'notes': notes.trim(),
          'total_amount': 0,
          'created_at': now.toIso8601String(),
        },
      );

      for (final item in items) {
        final materialId = (item['material_id'] as num?)?.toInt();
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;

        if (materialId == null || quantity <= 0 || unitPrice < 0) {
          throw StateError(
            'Некорректная позиция поступления: ${item['item_name']}',
          );
        }

        final materialRows = await txn.query(
          'materials',
          columns: ['name', 'unit', 'quantity'],
          where: 'id = ?',
          whereArgs: [materialId],
          limit: 1,
        );

        if (materialRows.isEmpty) {
          throw StateError('Материал со склада не найден');
        }

        final material = materialRows.first;
        final materialName = material['name'] as String;
        final unit = material['unit'] as String;
        final current = (material['quantity'] as num).toDouble();
        final balanceAfter = current + quantity;
        final amount = quantity * unitPrice;

        await txn.update(
          'materials',
          {'quantity': balanceAfter},
          where: 'id = ?',
          whereArgs: [materialId],
        );

        final receiptItemId = await txn.insert(
          'goods_receipt_items',
          {
            'receipt_id': receiptId,
            'material_id': materialId,
            'item_name': materialName,
            'unit': unit,
            'quantity': quantity,
            'unit_price': unitPrice,
            'amount': amount,
            'comment': item['comment'] as String? ?? '',
          },
        );

        final supplierDoc =
            '${supplierDocumentType.trim()} '
            '№ ${supplierDocumentNumber.trim()} '
            'от ${supplierDocumentDate.trim()}'.trim();

        await txn.insert(
          'stock_batches',
          {
            'material_id': materialId,
            'receipt_id': receiptId,
            'receipt_item_id': receiptItemId,
            'quantity_received': quantity,
            'quantity_remaining': quantity,
            'unit_price': unitPrice,
            'received_at': now.toIso8601String(),
            'supplier_name': supplierName.trim(),
            'supplier_document': supplierDoc,
          },
        );

        await txn.insert(
          'stock_movements',
          {
            'material_id': materialId,
            'request_id': null,
            'receipt_id': receiptId,
            'movement_type': 'receipt',
            'quantity': quantity,
            'balance_after': balanceAfter,
            'comment': supplierDoc,
            'created_at': now.toIso8601String(),
          },
        );

        totalAmount += amount;
      }

      await txn.update(
        'goods_receipts',
        {'total_amount': totalAmount},
        where: 'id = ?',
        whereArgs: [receiptId],
      );

      if (purchaseDocumentId != null) {
        final remaining = await txn.rawQuery("""
          SELECT
            i.material_id,
            SUM(i.quantity) AS requested_quantity,
            COALESCE((
              SELECT SUM(gri.quantity)
              FROM goods_receipt_items gri
              JOIN goods_receipts gr ON gr.id = gri.receipt_id
              WHERE gr.purchase_document_id = i.document_id
                AND gr.status = 'posted'
                AND gri.material_id = i.material_id
            ), 0) AS received_quantity
          FROM inventory_document_items i
          WHERE i.document_id = ?
            AND i.material_id IS NOT NULL
          GROUP BY i.document_id, i.material_id
        """, [purchaseDocumentId]);

        final allReceived = remaining.isNotEmpty &&
            remaining.every((row) {
              final requested =
                  (row['requested_quantity'] as num).toDouble();
              final received =
                  (row['received_quantity'] as num).toDouble();
              return received + 0.000001 >= requested;
            });

        final anythingReceived = remaining.any((row) {
          return (row['received_quantity'] as num).toDouble() > 0;
        });

        await txn.update(
          'inventory_documents',
          {
            'status': allReceived
                ? 'fulfilled'
                : anythingReceived
                    ? 'partially_received'
                    : 'prepared',
          },
          where: 'id = ?',
          whereArgs: [purchaseDocumentId],
        );
      }
    });

    await _enqueue(
      entity: 'goods_receipt',
      entityId: receiptId,
      operation: 'create',
      payload: {
        'receipt_number': receiptNumber,
        'purchase_document_id': purchaseDocumentId,
        'supplier_name': supplierName.trim(),
        'supplier_document_number':
            supplierDocumentNumber.trim(),
        'total_amount': totalAmount,
      },
    );

    return receiptId;
  }

  Future<List<GoodsReceipt>> getGoodsReceipts({
    int limit = 100,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'goods_receipts',
      orderBy: 'receipt_date DESC',
      limit: limit,
    );

    return rows.map(GoodsReceipt.fromMap).toList();
  }

  Future<GoodsReceipt?> getGoodsReceipt(int receiptId) async {
    final db = await _database.database;
    final rows = await db.query(
      'goods_receipts',
      where: 'id = ?',
      whereArgs: [receiptId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return GoodsReceipt.fromMap(rows.first);
  }

  Future<List<GoodsReceiptItem>> getGoodsReceiptItems(
    int receiptId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'goods_receipt_items',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'id',
    );

    return rows.map(GoodsReceiptItem.fromMap).toList();
  }

  Future<List<StockBatch>> getStockBatches(
    int materialId, {
    int limit = 100,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'stock_batches',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'received_at DESC',
      limit: limit,
    );

    return rows.map(StockBatch.fromMap).toList();
  }


  Future<List<Engineer>> getEngineers({
    bool activeOnly = true,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'engineers',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Engineer.fromMap).toList();
  }

  Future<int> addEngineer({
    required String name,
    String vehicle = '',
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Укажите имя инженера');
    }

    final db = await _database.database;
    final id = await db.insert('engineers', {
      'name': clean,
      'vehicle': vehicle.trim(),
      'active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _enqueue(
      entity: 'engineer',
      entityId: id,
      operation: 'create',
      payload: {
        'name': clean,
        'vehicle': vehicle.trim(),
      },
    );

    return id;
  }

  Future<void> updateEngineer({
    required int engineerId,
    required String name,
    String vehicle = '',
    bool active = true,
  }) async {
    final db = await _database.database;
    await db.update(
      'engineers',
      {
        'name': name.trim(),
        'vehicle': vehicle.trim(),
        'active': active ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [engineerId],
    );

    await _enqueue(
      entity: 'engineer',
      entityId: engineerId,
      operation: 'update',
      payload: {
        'name': name.trim(),
        'vehicle': vehicle.trim(),
        'active': active,
      },
    );
  }

  Future<List<EngineerStockItem>> getEngineerStock(
    int engineerId, {
    bool positiveOnly = true,
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery("""
      SELECT
        es.engineer_id,
        es.material_id,
        m.name AS material_name,
        m.unit,
        es.quantity,
        m.quantity AS warehouse_quantity
      FROM engineer_stock es
      JOIN materials m ON m.id = es.material_id
      WHERE es.engineer_id = ?
        ${positiveOnly ? 'AND es.quantity > 0' : ''}
      ORDER BY m.name COLLATE NOCASE
    """, [engineerId]);

    return rows.map(EngineerStockItem.fromMap).toList();
  }

  Future<double> getEngineerMaterialBalance({
    required int engineerId,
    required int materialId,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'engineer_stock',
      columns: ['quantity'],
      where: 'engineer_id = ? AND material_id = ?',
      whereArgs: [engineerId, materialId],
      limit: 1,
    );

    if (rows.isEmpty) return 0;
    return (rows.first['quantity'] as num).toDouble();
  }

  Future<String> _nextStockTransferNumber(
    DatabaseExecutor txn,
  ) async {
    const key = 'stock_transfer_next_number';
    final rows = await txn.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    final current = rows.isEmpty
        ? 1
        : int.tryParse(rows.first['value'] as String? ?? '') ?? 1;

    await txn.insert(
      'app_settings',
      {
        'key': key,
        'value': (current + 1).toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return 'ПС-${DateTime.now().year}-'
        '${current.toString().padLeft(5, '0')}';
  }

  Future<int> transferMaterialToEngineer({
    required int engineerId,
    required int materialId,
    required double quantity,
    String comment = '',
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Количество должно быть больше нуля');
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    late int transferId;
    late String transferNumber;
    late String materialName;
    late String unit;
    late String engineerName;
    late double warehouseAfter;
    late double engineerAfter;

    await db.transaction((txn) async {
      final engineerRows = await txn.query(
        'engineers',
        where: 'id = ? AND active = 1',
        whereArgs: [engineerId],
        limit: 1,
      );
      if (engineerRows.isEmpty) {
        throw StateError('Инженер не найден или отключён');
      }
      engineerName = engineerRows.first['name'] as String;

      final materialRows = await txn.query(
        'materials',
        where: 'id = ?',
        whereArgs: [materialId],
        limit: 1,
      );
      if (materialRows.isEmpty) {
        throw StateError('Материал не найден');
      }

      materialName = materialRows.first['name'] as String;
      unit = materialRows.first['unit'] as String;
      final warehouseCurrent =
          (materialRows.first['quantity'] as num).toDouble();

      if (quantity > warehouseCurrent) {
        throw StateError(
          'На основном складе недостаточно материала',
        );
      }

      final engineerStockRows = await txn.query(
        'engineer_stock',
        columns: ['quantity'],
        where: 'engineer_id = ? AND material_id = ?',
        whereArgs: [engineerId, materialId],
        limit: 1,
      );
      final engineerCurrent = engineerStockRows.isEmpty
          ? 0.0
          : (engineerStockRows.first['quantity'] as num).toDouble();

      warehouseAfter = warehouseCurrent - quantity;
      engineerAfter = engineerCurrent + quantity;

      await txn.update(
        'materials',
        {'quantity': warehouseAfter},
        where: 'id = ?',
        whereArgs: [materialId],
      );

      await txn.insert(
        'engineer_stock',
        {
          'engineer_id': engineerId,
          'material_id': materialId,
          'quantity': engineerAfter,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Перемещаем партийную трассировку FIFO вместе с товаром.
      var toMove = quantity;
      final batches = await txn.query(
        'stock_batches',
        where: 'material_id = ? AND quantity_remaining > 0',
        whereArgs: [materialId],
        orderBy: 'received_at ASC, id ASC',
      );

      for (final batch in batches) {
        if (toMove <= 0.000001) break;

        final batchId = batch['id'] as int;
        final available =
            (batch['quantity_remaining'] as num).toDouble();
        final take = available < toMove ? available : toMove;
        if (take <= 0) continue;

        await txn.update(
          'stock_batches',
          {'quantity_remaining': available - take},
          where: 'id = ?',
          whereArgs: [batchId],
        );

        final engineerBatchRows = await txn.query(
          'engineer_stock_batches',
          columns: ['quantity'],
          where: 'engineer_id = ? AND batch_id = ?',
          whereArgs: [engineerId, batchId],
          limit: 1,
        );
        final currentEngineerBatch = engineerBatchRows.isEmpty
            ? 0.0
            : (engineerBatchRows.first['quantity'] as num).toDouble();

        await txn.insert(
          'engineer_stock_batches',
          {
            'engineer_id': engineerId,
            'batch_id': batchId,
            'material_id': materialId,
            'quantity': currentEngineerBatch + take,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        toMove -= take;
      }

      transferNumber = await _nextStockTransferNumber(txn);

      transferId = await txn.insert(
        'stock_transfers',
        {
          'transfer_number': transferNumber,
          'transfer_type': 'issue_to_engineer',
          'engineer_id': engineerId,
          'status': 'posted',
          'comment': comment.trim(),
          'created_at': now,
        },
      );

      await txn.insert(
        'stock_transfer_items',
        {
          'transfer_id': transferId,
          'material_id': materialId,
          'item_name': materialName,
          'unit': unit,
          'quantity': quantity,
        },
      );

      await txn.insert(
        'stock_movements',
        {
          'material_id': materialId,
          'request_id': null,
          'receipt_id': null,
          'engineer_id': engineerId,
          'movement_type': 'issue_engineer',
          'quantity': -quantity,
          'balance_after': warehouseAfter,
          'engineer_balance_after': engineerAfter,
          'comment':
              '${comment.trim()} Выдано: $engineerName'.trim(),
          'created_at': now,
        },
      );
    });

    await _enqueue(
      entity: 'stock_transfer',
      entityId: transferId,
      operation: 'create',
      payload: {
        'transfer_number': transferNumber,
        'transfer_type': 'issue_to_engineer',
        'engineer_id': engineerId,
        'material_id': materialId,
        'quantity': quantity,
        'warehouse_after': warehouseAfter,
        'engineer_after': engineerAfter,
      },
    );

    return transferId;
  }

  Future<int> returnMaterialFromEngineer({
    required int engineerId,
    required int materialId,
    required double quantity,
    String comment = '',
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Количество должно быть больше нуля');
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    late int transferId;
    late String transferNumber;
    late String materialName;
    late String unit;
    late String engineerName;
    late double warehouseAfter;
    late double engineerAfter;

    await db.transaction((txn) async {
      final engineerRows = await txn.query(
        'engineers',
        where: 'id = ?',
        whereArgs: [engineerId],
        limit: 1,
      );
      if (engineerRows.isEmpty) {
        throw StateError('Инженер не найден');
      }
      engineerName = engineerRows.first['name'] as String;

      final materialRows = await txn.query(
        'materials',
        where: 'id = ?',
        whereArgs: [materialId],
        limit: 1,
      );
      if (materialRows.isEmpty) {
        throw StateError('Материал не найден');
      }

      materialName = materialRows.first['name'] as String;
      unit = materialRows.first['unit'] as String;
      final warehouseCurrent =
          (materialRows.first['quantity'] as num).toDouble();

      final stockRows = await txn.query(
        'engineer_stock',
        columns: ['quantity'],
        where: 'engineer_id = ? AND material_id = ?',
        whereArgs: [engineerId, materialId],
        limit: 1,
      );
      final engineerCurrent = stockRows.isEmpty
          ? 0.0
          : (stockRows.first['quantity'] as num).toDouble();

      if (quantity > engineerCurrent) {
        throw StateError(
          'У инженера недостаточно материала для возврата',
        );
      }

      engineerAfter = engineerCurrent - quantity;
      warehouseAfter = warehouseCurrent + quantity;

      await txn.update(
        'materials',
        {'quantity': warehouseAfter},
        where: 'id = ?',
        whereArgs: [materialId],
      );

      await txn.update(
        'engineer_stock',
        {'quantity': engineerAfter},
        where: 'engineer_id = ? AND material_id = ?',
        whereArgs: [engineerId, materialId],
      );

      // Возвращаем партийный остаток обратно на основной склад.
      var toReturn = quantity;
      final engineerBatches = await txn.rawQuery("""
        SELECT
          esb.batch_id,
          esb.quantity,
          sb.received_at
        FROM engineer_stock_batches esb
        JOIN stock_batches sb ON sb.id = esb.batch_id
        WHERE esb.engineer_id = ?
          AND esb.material_id = ?
          AND esb.quantity > 0
        ORDER BY sb.received_at ASC, esb.batch_id ASC
      """, [engineerId, materialId]);

      for (final batch in engineerBatches) {
        if (toReturn <= 0.000001) break;

        final batchId = batch['batch_id'] as int;
        final engineerBatchQty =
            (batch['quantity'] as num).toDouble();
        final giveBack =
            engineerBatchQty < toReturn ? engineerBatchQty : toReturn;

        await txn.update(
          'engineer_stock_batches',
          {'quantity': engineerBatchQty - giveBack},
          where: 'engineer_id = ? AND batch_id = ?',
          whereArgs: [engineerId, batchId],
        );

        final mainBatchRows = await txn.query(
          'stock_batches',
          columns: ['quantity_remaining'],
          where: 'id = ?',
          whereArgs: [batchId],
          limit: 1,
        );

        if (mainBatchRows.isNotEmpty) {
          final mainRemaining =
              (mainBatchRows.first['quantity_remaining'] as num).toDouble();
          await txn.update(
            'stock_batches',
            {'quantity_remaining': mainRemaining + giveBack},
            where: 'id = ?',
            whereArgs: [batchId],
          );
        }

        toReturn -= giveBack;
      }

      transferNumber = await _nextStockTransferNumber(txn);

      transferId = await txn.insert(
        'stock_transfers',
        {
          'transfer_number': transferNumber,
          'transfer_type': 'return_to_warehouse',
          'engineer_id': engineerId,
          'status': 'posted',
          'comment': comment.trim(),
          'created_at': now,
        },
      );

      await txn.insert(
        'stock_transfer_items',
        {
          'transfer_id': transferId,
          'material_id': materialId,
          'item_name': materialName,
          'unit': unit,
          'quantity': quantity,
        },
      );

      await txn.insert(
        'stock_movements',
        {
          'material_id': materialId,
          'request_id': null,
          'receipt_id': null,
          'engineer_id': engineerId,
          'movement_type': 'return_warehouse',
          'quantity': quantity,
          'balance_after': warehouseAfter,
          'engineer_balance_after': engineerAfter,
          'comment':
              '${comment.trim()} Возврат от: $engineerName'.trim(),
          'created_at': now,
        },
      );
    });

    await _enqueue(
      entity: 'stock_transfer',
      entityId: transferId,
      operation: 'create',
      payload: {
        'transfer_number': transferNumber,
        'transfer_type': 'return_to_warehouse',
        'engineer_id': engineerId,
        'material_id': materialId,
        'quantity': quantity,
        'warehouse_after': warehouseAfter,
        'engineer_after': engineerAfter,
      },
    );

    return transferId;
  }

  Future<List<StockTransfer>> getStockTransfers({
    int? engineerId,
    int limit = 100,
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery("""
      SELECT
        st.*,
        e.name AS engineer_name
      FROM stock_transfers st
      JOIN engineers e ON e.id = st.engineer_id
      ${engineerId == null ? '' : 'WHERE st.engineer_id = ?'}
      ORDER BY st.created_at DESC
      LIMIT ?
    """, [
      if (engineerId != null) engineerId,
      limit,
    ]);

    return rows.map(StockTransfer.fromMap).toList();
  }

  Future<List<MaterialItem>> getMaterials() async {
    final db = await _database.database;
    final rows = await db.query('materials', orderBy: 'name');
    return rows.map(MaterialItem.fromMap).toList();
  }

  Future<void> consumeMaterial(int id, double amount) async {
    if (amount <= 0) return;

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    late double balanceAfter;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'materials',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Материал не найден');
      }

      final current =
          (rows.first['quantity'] as num).toDouble();

      if (amount > current) {
        throw StateError('Недостаточно материала на складе');
      }

      balanceAfter = current - amount;

      await txn.update(
        'materials',
        {'quantity': balanceAfter},
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.insert(
        'stock_movements',
        {
          'material_id': id,
          'request_id': null,
          'movement_type': 'manual_issue',
          'quantity': -amount,
          'balance_after': balanceAfter,
          'comment': 'Ручное списание со склада',
          'created_at': now,
        },
      );
    });

    await _enqueue(
      entity: 'material',
      entityId: id,
      operation: 'consume',
      payload: {
        'amount': amount,
        'balance_after': balanceAfter,
      },
    );
  }

  Future<void> _enqueue({
    required String entity,
    required int entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final db = await _database.database;
    await db.insert('sync_queue', {
      'entity': entity,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }


  Future<List<ObjectHistoryEntry>> getObjectHistory(
    int objectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery("""
      SELECT
        r.id AS request_id,
        r.type,
        r.status,
        r.priority,
        r.created_at,
        r.updated_at,
        wr.battery_voltage,
        wr.loop_resistance_kohm,
        wr.cause,
        wr.work_done,
        wr.result,
        (
          SELECT COUNT(*)
          FROM photos p
          WHERE p.request_id = r.id
        ) AS photo_count,
        (
          SELECT COALESCE(SUM(pa.photo_count), 0)
          FROM photo_archives pa
          WHERE pa.request_id = r.id
        ) AS archived_photo_count
      FROM requests r
      LEFT JOIN work_reports wr ON wr.request_id = r.id
      WHERE r.object_id = ?
      ORDER BY r.created_at DESC
      LIMIT ? OFFSET ?
    """, [objectId, limit, offset]);

    return rows.map(ObjectHistoryEntry.fromMap).toList();
  }


  Future<List<Map<String, Object?>>> getObjectNotes(int objectId) async {
    final db = await _database.database;
    return db.query(
      'object_notes',
      where: 'object_id = ?',
      whereArgs: [objectId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> addObjectNote(int objectId, String text) async {
    final value = text.trim();
    if (value.isEmpty) return;

    final db = await _database.database;
    await db.insert('object_notes', {
      'object_id': objectId,
      'text': value,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _enqueue(
      entity: 'object_note',
      entityId: objectId,
      operation: 'create',
      payload: {'text': value},
    );
  }

  Future<Map<String, Object?>> getObjectHistoryStats(int objectId) async {
    final db = await _database.database;

    final totalRows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM requests WHERE object_id = ?',
      [objectId],
    );

    final completedRows = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM requests "
      "WHERE object_id = ? AND status = 'Выполнена'",
      [objectId],
    );

    final repeatRows = await db.rawQuery("""
      SELECT type, COUNT(*) AS cnt
      FROM requests
      WHERE object_id = ?
      GROUP BY type
      ORDER BY cnt DESC
      LIMIT 1
    """, [objectId]);

    int count(List<Map<String, Object?>> rows) =>
        (rows.first['cnt'] as num?)?.toInt() ?? 0;

    return {
      'total': count(totalRows),
      'completed': count(completedRows),
      'top_type': repeatRows.isEmpty ? null : repeatRows.first['type'],
      'top_type_count':
          repeatRows.isEmpty ? 0 : (repeatRows.first['cnt'] as num).toInt(),
    };
  }


  Future<String> getObjectAssistantHint(int objectId) async {
    final db = await _database.database;

    final repeated = await db.rawQuery("""
      SELECT type, COUNT(*) AS cnt
      FROM requests
      WHERE object_id = ?
      GROUP BY type
      ORDER BY cnt DESC
      LIMIT 1
    """, [objectId]);

    final lastRepair = await db.rawQuery("""
      SELECT wr.cause, wr.work_done, wr.result, r.type
      FROM requests r
      JOIN work_reports wr ON wr.request_id = r.id
      WHERE r.object_id = ?
      ORDER BY wr.created_at DESC
      LIMIT 1
    """, [objectId]);

    if (repeated.isEmpty && lastRepair.isEmpty) {
      return 'Истории пока мало. После первых закрытых заявок '
          'здесь появятся подсказки по повторяющимся неисправностям.';
    }

    final parts = <String>[];

    if (repeated.isNotEmpty) {
      final type = repeated.first['type'];
      final cnt = (repeated.first['cnt'] as num?)?.toInt() ?? 0;
      if (cnt >= 2) {
        parts.add('Повторяется событие «$type» ($cnt раз).');
      }
    }

    if (lastRepair.isNotEmpty) {
      final row = lastRepair.first;
      final cause = (row['cause'] as String?)?.trim() ?? '';
      final work = (row['work_done'] as String?)?.trim() ?? '';

      if (cause.isNotEmpty) {
        parts.add('Последняя подтверждённая причина: $cause.');
      }
      if (work.isNotEmpty) {
        parts.add('В прошлый раз помогло: $work.');
      }
    }

    if (parts.isEmpty) {
      return 'История есть, но пока недостаточно повторов для уверенной подсказки.';
    }

    return parts.join(' ');
  }


  Future<void> updateObjectPassport(OpsObject object) async {
    if (object.id == null) return;

    final db = await _database.database;
    await db.update(
      'objects',
      {
        'address': object.address.trim(),
        'system': object.system.trim(),
        'connection': object.connection.trim(),
        'status': object.status.trim(),
        'notes': object.notes.trim(),
        'entrances': object.entrances,
        'latitude': object.latitude,
        'longitude': object.longitude,
      },
      where: 'id = ?',
      whereArgs: [object.id],
    );

    await _enqueue(
      entity: 'object',
      entityId: object.id!,
      operation: 'update',
      payload: {
        'address': object.address,
        'system': object.system,
        'connection': object.connection,
        'status': object.status,
        'notes': object.notes,
        'entrances': object.entrances,
      },
    );
  }

  Future<List<ObjectEquipment>> getObjectEquipment(int objectId) async {
    final db = await _database.database;
    final rows = await db.query(
      'object_equipment',
      where: 'object_id = ?',
      whereArgs: [objectId],
      orderBy: 'name COLLATE NOCASE',
    );

    return rows.map(ObjectEquipment.fromMap).toList();
  }

  Future<int> addObjectEquipment({
    required int objectId,
    required String name,
    String model = '',
    String location = '',
    String serialNumber = '',
    String notes = '',
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('object_equipment', {
      'object_id': objectId,
      'name': name.trim(),
      'model': model.trim(),
      'location': location.trim(),
      'serial_number': serialNumber.trim(),
      'notes': notes.trim(),
      'created_at': now,
    });

    await _enqueue(
      entity: 'object_equipment',
      entityId: id,
      operation: 'create',
      payload: {
        'object_id': objectId,
        'name': name,
        'model': model,
        'location': location,
        'serial_number': serialNumber,
      },
    );

    return id;
  }

  Future<void> deleteObjectEquipment(int id) async {
    final db = await _database.database;
    await db.delete(
      'object_equipment',
      where: 'id = ?',
      whereArgs: [id],
    );

    await _enqueue(
      entity: 'object_equipment',
      entityId: id,
      operation: 'delete',
      payload: const {},
    );
  }

  Future<int> objectOpenRequestCount(int objectId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM requests "
      "WHERE object_id = ? AND status != 'Выполнена'",
      [objectId],
    );
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }


  Future<List<ReferenceValue>> getReferenceValues(
    String category, {
    bool activeOnly = true,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'reference_values',
      where: activeOnly
          ? 'category = ? AND active = 1'
          : 'category = ?',
      whereArgs: [category],
      orderBy: 'sort_order ASC, value COLLATE NOCASE ASC',
    );

    return rows.map(ReferenceValue.fromMap).toList();
  }

  Future<int> addReferenceValue({
    required String category,
    required String value,
  }) async {
    final clean = value.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Пустое значение справочника');
    }

    final db = await _database.database;

    final maxRows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), 0) AS max_sort '
      'FROM reference_values WHERE category = ?',
      [category],
    );
    final maxSort =
        (maxRows.first['max_sort'] as num?)?.toInt() ?? 0;

    final id = await db.insert(
      'reference_values',
      {
        'category': category,
        'value': clean,
        'sort_order': maxSort + 10,
        'active': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    await _enqueue(
      entity: 'reference_value',
      entityId: id,
      operation: 'create',
      payload: {
        'category': category,
        'value': clean,
      },
    );

    return id;
  }

  Future<void> updateReferenceValue(
    int id, {
    required String value,
  }) async {
    final clean = value.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Пустое значение справочника');
    }

    final db = await _database.database;
    await db.update(
      'reference_values',
      {'value': clean},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _enqueue(
      entity: 'reference_value',
      entityId: id,
      operation: 'update',
      payload: {'value': clean},
    );
  }

  Future<void> setReferenceValueActive(
    int id,
    bool active,
  ) async {
    final db = await _database.database;
    await db.update(
      'reference_values',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _enqueue(
      entity: 'reference_value',
      entityId: id,
      operation: 'update',
      payload: {'active': active},
    );
  }

  Future<void> deleteReferenceValue(int id) async {
    final db = await _database.database;
    await db.delete(
      'reference_values',
      where: 'id = ?',
      whereArgs: [id],
    );

    await _enqueue(
      entity: 'reference_value',
      entityId: id,
      operation: 'delete',
      payload: const {},
    );
  }

  Future<WorkRequest?> findOpenDuplicateRequest({
    required int objectId,
    required String type,
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery("""
      SELECT r.*, o.address AS address
      FROM requests r
      JOIN objects o ON o.id = r.object_id
      WHERE r.object_id = ?
        AND r.type = ?
        AND r.status != 'Выполнена'
      ORDER BY r.created_at DESC
      LIMIT 1
    """, [objectId, type]);

    if (rows.isEmpty) return null;
    return WorkRequest.fromMap(rows.first);
  }

  Future<int> openRequestCount() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM requests WHERE status != 'Выполнена'",
    );
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<int> pendingSyncCount() async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM sync_queue',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> objectCount() async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM objects',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
