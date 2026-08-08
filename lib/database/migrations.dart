import 'package:sqflite/sqflite.dart';

class DatabaseMigrations {
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _toV2(db);
    if (oldVersion < 3) await _toV3(db);
    if (oldVersion < 4) await _toV4(db);
    if (oldVersion < 5) await _toV5(db);
    if (oldVersion < 6) await _toV6(db);
    if (oldVersion < 7) await _toV7(db);
    if (oldVersion < 8) await _toV8(db);
    if (oldVersion < 9) await _toV9(db);
    if (oldVersion < 10) await _toV10(db);
    if (oldVersion < 11) await _toV11(db);
    if (oldVersion < 12) await _toV12(db);
    if (oldVersion < 13) await _toV13(db);
    if (oldVersion < 14) await _toV14(db);
    if (oldVersion < 15) await _toV15(db);
  }

  static Future<void> _toV2(Database db) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS work_reports(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id INTEGER NOT NULL UNIQUE,
        battery_voltage REAL,
        loop_resistance_kohm REAL,
        cause TEXT NOT NULL DEFAULT '',
        work_done TEXT NOT NULL DEFAULT '',
        result TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(request_id) REFERENCES requests(id) ON DELETE CASCADE
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS photos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(request_id) REFERENCES requests(id) ON DELETE CASCADE
      )
    """);
  }

  static Future<void> _toV3(Database db) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS migration_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_version INTEGER NOT NULL,
        to_version INTEGER NOT NULL,
        migrated_at TEXT NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS backup_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        type TEXT NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS import_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        mode TEXT NOT NULL,
        result TEXT NOT NULL
      )
    """);

    await db.insert('migration_log', {
      'from_version': 2,
      'to_version': 3,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> _toV4(Database db) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS object_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        object_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(object_id) REFERENCES objects(id) ON DELETE CASCADE
      )
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_requests_object
      ON requests(object_id)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_requests_created
      ON requests(created_at)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_photos_request
      ON photos(request_id)
    """);

    await db.insert('migration_log', {
      'from_version': 3,
      'to_version': 4,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> _toV5(Database db) async {
    // Отмечаем успешно синхронизированные записи, чтобы потом
    // безопасно удалять только подтверждённый сервером технический хвост.
    final syncColumns = await db.rawQuery("PRAGMA table_info(sync_queue)");
    final hasSyncedAt =
        syncColumns.any((row) => row['name'] == 'synced_at');

    if (!hasSyncedAt) {
      await db.execute(
        'ALTER TABLE sync_queue ADD COLUMN synced_at TEXT',
      );
    }

    await db.execute("""
      CREATE TABLE IF NOT EXISTS app_settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS photo_archives(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id INTEGER NOT NULL,
        photo_count INTEGER NOT NULL,
        archive_file TEXT NOT NULL,
        archived_at TEXT NOT NULL,
        FOREIGN KEY(request_id) REFERENCES requests(id) ON DELETE CASCADE
      )
    """);


    await db.insert(
      'app_settings',
      {'key': 'history_page_size', 'value': '50'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'app_settings',
      {'key': 'photo_preview_cache_width', 'value': '900'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'app_settings',
      {'key': 'sent_sync_retention_days', 'value': '30'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_requests_object_created
      ON requests(object_id, created_at DESC)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_sync_synced_at
      ON sync_queue(synced_at)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_work_reports_request
      ON work_reports(request_id)
    """);

    await db.insert('migration_log', {
      'from_version': 4,
      'to_version': 5,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }


  static Future<void> _toV6(Database db) async {
    final requestColumns = await db.rawQuery("PRAGMA table_info(requests)");
    final hasRequestIsTest =
        requestColumns.any((row) => row['name'] == 'is_test');
    if (!hasRequestIsTest) {
      await db.execute(
        'ALTER TABLE requests ADD COLUMN is_test INTEGER NOT NULL DEFAULT 0',
      );
    }

    final photoColumns = await db.rawQuery("PRAGMA table_info(photos)");
    final hasPhotoIsTest =
        photoColumns.any((row) => row['name'] == 'is_test');
    if (!hasPhotoIsTest) {
      await db.execute(
        'ALTER TABLE photos ADD COLUMN is_test INTEGER NOT NULL DEFAULT 0',
      );
    }

    final reportColumns =
        await db.rawQuery("PRAGMA table_info(work_reports)");
    final hasReportIsTest =
        reportColumns.any((row) => row['name'] == 'is_test');
    if (!hasReportIsTest) {
      await db.execute(
        'ALTER TABLE work_reports ADD COLUMN is_test INTEGER NOT NULL DEFAULT 0',
      );
    }

    await db.execute("""
      CREATE TABLE IF NOT EXISTS stress_test_runs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        request_count INTEGER NOT NULL,
        photo_count INTEGER NOT NULL,
        insert_ms INTEGER NOT NULL,
        history_query_ms INTEGER NOT NULL,
        open_requests_query_ms INTEGER NOT NULL,
        database_bytes INTEGER NOT NULL
      )
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_requests_is_test
      ON requests(is_test)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_photos_is_test
      ON photos(is_test)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_work_reports_is_test
      ON work_reports(is_test)
    """);

    await db.insert('migration_log', {
      'from_version': 5,
      'to_version': 6,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV7(Database db) async {
    final photoColumns = await db.rawQuery("PRAGMA table_info(photos)");
    final hasFileSize =
        photoColumns.any((row) => row['name'] == 'file_size_bytes');
    final hasMode =
        photoColumns.any((row) => row['name'] == 'capture_mode');

    if (!hasFileSize) {
      await db.execute(
        'ALTER TABLE photos ADD COLUMN file_size_bytes INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!hasMode) {
      await db.execute(
        "ALTER TABLE photos ADD COLUMN capture_mode TEXT NOT NULL DEFAULT 'lite'",
      );
    }

    // Настройки лёгкого фоторежима. Хранятся в app_settings,
    // поэтому их можно менять без следующей миграции схемы.
    await db.insert(
      'app_settings',
      {'key': 'photo_mode', 'value': 'lite'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'app_settings',
      {'key': 'photo_jpeg_quality', 'value': '70'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'app_settings',
      {'key': 'photo_max_width', 'value': '1280'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'app_settings',
      {'key': 'photo_max_height', 'value': '1280'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'app_settings',
      {'key': 'photo_preview_cache_width', 'value': '640'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert('migration_log', {
      'from_version': 6,
      'to_version': 7,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV8(Database db) async {
    await db.insert(
      'app_settings',
      {'key': 'appearance_theme', 'value': 'light'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'app_settings',
      {'key': 'appearance_text_scale', 'value': '1.0'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert('migration_log', {
      'from_version': 7,
      'to_version': 8,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV9(Database db) async {
    final objectColumns = await db.rawQuery("PRAGMA table_info(objects)");

    bool has(String name) =>
        objectColumns.any((row) => row['name'] == name);

    if (!has('connection')) {
      await db.execute(
        "ALTER TABLE objects ADD COLUMN connection TEXT NOT NULL DEFAULT 'SIM'",
      );
    }
    if (!has('status')) {
      await db.execute(
        "ALTER TABLE objects ADD COLUMN status TEXT NOT NULL DEFAULT 'Норма'",
      );
    }
    if (!has('notes')) {
      await db.execute(
        "ALTER TABLE objects ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
      );
    }
    if (!has('entrances')) {
      await db.execute(
        'ALTER TABLE objects ADD COLUMN entrances INTEGER',
      );
    }

    await db.execute("""
      CREATE TABLE IF NOT EXISTS object_equipment(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        object_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        model TEXT NOT NULL DEFAULT '',
        location TEXT NOT NULL DEFAULT '',
        serial_number TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(object_id) REFERENCES objects(id) ON DELETE CASCADE
      )
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_object_equipment_object
      ON object_equipment(object_id)
    """);

    await db.insert('migration_log', {
      'from_version': 8,
      'to_version': 9,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV10(Database db) async {
    final requestColumns = await db.rawQuery("PRAGMA table_info(requests)");
    final hasSource =
        requestColumns.any((row) => row['name'] == 'source');

    if (!hasSource) {
      await db.execute(
        "ALTER TABLE requests ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
      );
    }

    await db.execute("""
      CREATE TABLE IF NOT EXISTS reference_values(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        value TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 100,
        active INTEGER NOT NULL DEFAULT 1,
        UNIQUE(category, value)
      )
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_reference_values_category
      ON reference_values(category, active, sort_order, value)
    """);

    Future<void> seed(
      String category,
      String value,
      int sortOrder,
    ) async {
      await db.insert(
        'reference_values',
        {
          'category': category,
          'value': value,
          'sort_order': sortOrder,
          'active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await seed('request_type', 'Сработка', 10);
    await seed('request_type', 'Нет контрольного события', 20);
    await seed('request_type', 'Не ставится на охрану', 30);
    await seed('request_type', 'Потеря связи', 40);
    await seed('request_type', 'АКБ разряжена', 50);
    await seed('request_type', 'АКБ отключена', 60);
    await seed('request_type', 'Обрыв линии', 70);
    await seed('request_type', 'Плановое обслуживание', 80);
    await seed('request_type', 'Другое', 90);

    await seed('fault_cause', 'Обрыв линии', 10);
    await seed('fault_cause', 'Нарушение контакта', 20);
    await seed('fault_cause', 'Неисправность датчика', 30);
    await seed('fault_cause', 'Разряжена АКБ', 40);
    await seed('fault_cause', 'Потеря канала связи', 50);
    await seed('fault_cause', 'Неисправность питания', 60);
    await seed('fault_cause', 'Не установлена', 90);

    await seed('work_result', 'Работоспособность восстановлена', 10);
    await seed('work_result', 'Требуется повторный выезд', 20);
    await seed('work_result', 'Требуется материал/оборудование', 30);
    await seed('work_result', 'Передано на дополнительную диагностику', 40);

    await db.insert('migration_log', {
      'from_version': 9,
      'to_version': 10,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV11(Database db) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS request_materials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        material_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(request_id) REFERENCES requests(id) ON DELETE CASCADE,
        FOREIGN KEY(material_id) REFERENCES materials(id)
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS stock_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        request_id INTEGER,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        balance_after REAL NOT NULL,
        comment TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(material_id) REFERENCES materials(id),
        FOREIGN KEY(request_id) REFERENCES requests(id) ON DELETE SET NULL
      )
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_request_materials_request
      ON request_materials(request_id, created_at)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_stock_movements_material
      ON stock_movements(material_id, created_at DESC)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_stock_movements_request
      ON stock_movements(request_id)
    """);

    await db.insert('migration_log', {
      'from_version': 10,
      'to_version': 11,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV12(Database db) async {
    final materialColumns = await db.rawQuery("PRAGMA table_info(materials)");
    final hasAccountingPrice =
        materialColumns.any((row) => row['name'] == 'accounting_price');

    if (!hasAccountingPrice) {
      await db.execute(
        'ALTER TABLE materials ADD COLUMN accounting_price REAL NOT NULL DEFAULT 0',
      );
    }

    await db.execute("""
      CREATE TABLE IF NOT EXISTS organization_profile(
        id INTEGER PRIMARY KEY CHECK (id = 1),
        full_name TEXT NOT NULL DEFAULT '',
        short_name TEXT NOT NULL DEFAULT '',
        inn TEXT NOT NULL DEFAULT '',
        kpp TEXT NOT NULL DEFAULT '',
        legal_address TEXT NOT NULL DEFAULT '',
        director_position TEXT NOT NULL DEFAULT 'Руководитель',
        director_name TEXT NOT NULL DEFAULT '',
        accountant_position TEXT NOT NULL DEFAULT 'Главный бухгалтер',
        accountant_name TEXT NOT NULL DEFAULT '',
        material_responsible_position TEXT NOT NULL DEFAULT 'Материально ответственное лицо',
        material_responsible_name TEXT NOT NULL DEFAULT '',
        forms_approval_order_no TEXT NOT NULL DEFAULT '',
        forms_approval_order_date TEXT NOT NULL DEFAULT '',
        procurement_regime TEXT NOT NULL DEFAULT 'commercial'
      )
    """);

    await db.insert(
      'organization_profile',
      {
        'id': 1,
        'full_name': '',
        'short_name': '',
        'inn': '',
        'kpp': '',
        'legal_address': '',
        'director_position': 'Руководитель',
        'director_name': '',
        'accountant_position': 'Главный бухгалтер',
        'accountant_name': '',
        'material_responsible_position': 'Материально ответственное лицо',
        'material_responsible_name': '',
        'forms_approval_order_no': '',
        'forms_approval_order_date': '',
        'procurement_regime': 'commercial',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.execute("""
      CREATE TABLE IF NOT EXISTS inventory_documents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        document_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        title TEXT NOT NULL,
        organization_name TEXT NOT NULL,
        organization_inn TEXT NOT NULL DEFAULT '',
        organization_kpp TEXT NOT NULL DEFAULT '',
        content_description TEXT NOT NULL DEFAULT '',
        basis TEXT NOT NULL DEFAULT '',
        source_request_id INTEGER,
        creator_position TEXT NOT NULL DEFAULT '',
        creator_name TEXT NOT NULL DEFAULT '',
        accountant_position TEXT NOT NULL DEFAULT '',
        accountant_name TEXT NOT NULL DEFAULT '',
        approver_position TEXT NOT NULL DEFAULT '',
        approver_name TEXT NOT NULL DEFAULT '',
        responsible_position TEXT NOT NULL DEFAULT '',
        responsible_name TEXT NOT NULL DEFAULT '',
        forms_approval_order_no TEXT NOT NULL DEFAULT '',
        forms_approval_order_date TEXT NOT NULL DEFAULT '',
        procurement_regime TEXT NOT NULL DEFAULT 'commercial',
        pdf_path TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(source_request_id) REFERENCES requests(id) ON DELETE SET NULL
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS inventory_document_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        material_id INTEGER,
        item_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        amount REAL NOT NULL DEFAULT 0,
        comment TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(document_id) REFERENCES inventory_documents(id) ON DELETE CASCADE,
        FOREIGN KEY(material_id) REFERENCES materials(id) ON DELETE SET NULL
      )
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_inventory_documents_type_date
      ON inventory_documents(document_type, document_date DESC)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_inventory_document_items_doc
      ON inventory_document_items(document_id)
    """);

    await db.insert(
      'app_settings',
      {'key': 'purchase_request_next_number', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'app_settings',
      {'key': 'writeoff_act_next_number', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert('migration_log', {
      'from_version': 11,
      'to_version': 12,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV13(Database db) async {
    final movementColumns =
        await db.rawQuery("PRAGMA table_info(stock_movements)");
    final hasReceiptId =
        movementColumns.any((row) => row['name'] == 'receipt_id');

    if (!hasReceiptId) {
      await db.execute(
        'ALTER TABLE stock_movements ADD COLUMN receipt_id INTEGER',
      );
    }

    await db.execute("""
      CREATE TABLE IF NOT EXISTS goods_receipts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT NOT NULL,
        receipt_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'posted',
        purchase_document_id INTEGER,
        supplier_name TEXT NOT NULL DEFAULT '',
        supplier_inn TEXT NOT NULL DEFAULT '',
        supplier_document_type TEXT NOT NULL DEFAULT 'УПД',
        supplier_document_number TEXT NOT NULL DEFAULT '',
        supplier_document_date TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        total_amount REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(purchase_document_id)
          REFERENCES inventory_documents(id) ON DELETE SET NULL
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS goods_receipt_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        amount REAL NOT NULL DEFAULT 0,
        comment TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(receipt_id)
          REFERENCES goods_receipts(id) ON DELETE CASCADE,
        FOREIGN KEY(material_id)
          REFERENCES materials(id)
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS stock_batches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        receipt_id INTEGER NOT NULL,
        receipt_item_id INTEGER NOT NULL,
        quantity_received REAL NOT NULL,
        quantity_remaining REAL NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        received_at TEXT NOT NULL,
        supplier_name TEXT NOT NULL DEFAULT '',
        supplier_document TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(material_id)
          REFERENCES materials(id),
        FOREIGN KEY(receipt_id)
          REFERENCES goods_receipts(id) ON DELETE RESTRICT,
        FOREIGN KEY(receipt_item_id)
          REFERENCES goods_receipt_items(id) ON DELETE RESTRICT
      )
    """);


    await db.execute("""
      CREATE TABLE IF NOT EXISTS request_material_batch_allocations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_material_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        FOREIGN KEY(request_material_id)
          REFERENCES request_materials(id) ON DELETE CASCADE,
        FOREIGN KEY(batch_id)
          REFERENCES stock_batches(id) ON DELETE RESTRICT
      )
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_batch_allocations_request_material
      ON request_material_batch_allocations(request_material_id)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_batch_allocations_batch
      ON request_material_batch_allocations(batch_id)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_stock_movements_receipt
      ON stock_movements(receipt_id)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_goods_receipts_date
      ON goods_receipts(receipt_date DESC)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_goods_receipts_purchase
      ON goods_receipts(purchase_document_id, status)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_goods_receipt_items_receipt
      ON goods_receipt_items(receipt_id)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_stock_batches_material
      ON stock_batches(material_id, quantity_remaining, received_at)
    """);

    await db.insert(
      'app_settings',
      {'key': 'goods_receipt_next_number', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert('migration_log', {
      'from_version': 12,
      'to_version': 13,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV14(Database db) async {
    final requestMaterialColumns =
        await db.rawQuery("PRAGMA table_info(request_materials)");
    final hasSourceKind =
        requestMaterialColumns.any((row) => row['name'] == 'source_kind');
    final hasSourceEngineerId =
        requestMaterialColumns.any(
          (row) => row['name'] == 'source_engineer_id',
        );

    if (!hasSourceKind) {
      await db.execute(
        "ALTER TABLE request_materials "
        "ADD COLUMN source_kind TEXT NOT NULL DEFAULT 'warehouse'",
      );
    }

    if (!hasSourceEngineerId) {
      await db.execute(
        'ALTER TABLE request_materials '
        'ADD COLUMN source_engineer_id INTEGER',
      );
    }

    final movementColumns =
        await db.rawQuery("PRAGMA table_info(stock_movements)");
    final hasEngineerId =
        movementColumns.any((row) => row['name'] == 'engineer_id');
    final hasEngineerBalance =
        movementColumns.any(
          (row) => row['name'] == 'engineer_balance_after',
        );

    if (!hasEngineerId) {
      await db.execute(
        'ALTER TABLE stock_movements ADD COLUMN engineer_id INTEGER',
      );
    }

    if (!hasEngineerBalance) {
      await db.execute(
        'ALTER TABLE stock_movements '
        'ADD COLUMN engineer_balance_after REAL',
      );
    }

    await db.execute("""
      CREATE TABLE IF NOT EXISTS engineers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        vehicle TEXT NOT NULL DEFAULT '',
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS engineer_stock(
        engineer_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        PRIMARY KEY(engineer_id, material_id),
        FOREIGN KEY(engineer_id)
          REFERENCES engineers(id) ON DELETE CASCADE,
        FOREIGN KEY(material_id)
          REFERENCES materials(id) ON DELETE CASCADE
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS engineer_stock_batches(
        engineer_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        PRIMARY KEY(engineer_id, batch_id),
        FOREIGN KEY(engineer_id)
          REFERENCES engineers(id) ON DELETE CASCADE,
        FOREIGN KEY(batch_id)
          REFERENCES stock_batches(id) ON DELETE RESTRICT,
        FOREIGN KEY(material_id)
          REFERENCES materials(id) ON DELETE CASCADE
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS stock_transfers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_number TEXT NOT NULL,
        transfer_type TEXT NOT NULL,
        engineer_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'posted',
        comment TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(engineer_id)
          REFERENCES engineers(id) ON DELETE RESTRICT
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS stock_transfer_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL,
        FOREIGN KEY(transfer_id)
          REFERENCES stock_transfers(id) ON DELETE CASCADE,
        FOREIGN KEY(material_id)
          REFERENCES materials(id) ON DELETE RESTRICT
      )
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_engineer_stock_material
      ON engineer_stock(material_id, engineer_id)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_engineer_stock_batches_engineer
      ON engineer_stock_batches(engineer_id, material_id, quantity)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_stock_transfers_engineer
      ON stock_transfers(engineer_id, created_at DESC)
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_stock_movements_engineer
      ON stock_movements(engineer_id, created_at DESC)
    """);

    await db.insert(
      'app_settings',
      {'key': 'stock_transfer_next_number', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert('migration_log', {
      'from_version': 13,
      'to_version': 14,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }



  static Future<void> _toV15(Database db) async {
    await db.insert(
      'app_settings',
      {'key': 'simple_workflow', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'app_settings',
      {'key': 'default_engineer_id', 'value': ''},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'app_settings',
      {'key': 'auto_prepare_writeoff', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert('migration_log', {
      'from_version': 14,
      'to_version': 15,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }


}
