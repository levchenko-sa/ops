#!/usr/bin/env python3
from __future__ import annotations

import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_DB = ROOT / 'lib/database/app_database.dart'
MIGRATIONS = ROOT / 'lib/database/migrations.dart'
CONSTANTS = ROOT / 'lib/core/app_constants.dart'

app = APP_DB.read_text(encoding='utf-8')
migrations = MIGRATIONS.read_text(encoding='utf-8')
constants = CONSTANTS.read_text(encoding='utf-8')

if 'databaseVersion = 15' not in constants:
    raise SystemExit('FAIL: expected databaseVersion = 15')

v1_start = app.index('Future<void> _createV1')
v1_end = app.index('Future<void> _seed')
v1_section = app[v1_start:v1_end]
v1_sql = re.findall(r"await db\.execute\('''(.*?)'''\);", v1_section, re.S)
if len(v1_sql) != 4:
    raise SystemExit(f'FAIL: expected 4 v1 SQL statements, found {len(v1_sql)}')


def extract_execute_sql(source: str) -> list[str]:
    """Extract literal SQL from await db.execute(...) calls in source order.

    Supports Dart adjacent string literals such as:
      'ALTER TABLE x '
      'ADD COLUMN y INTEGER'
    plus triple-quoted SQL blocks.
    """
    out: list[str] = []
    needle = 'await db.execute('
    pos = 0

    while True:
        start = source.find(needle, pos)
        if start < 0:
            break
        i = start + len(needle)
        depth = 1
        in_quote: str | None = None
        triple = False
        escaped = False

        while i < len(source) and depth > 0:
            if in_quote is not None:
                if triple:
                    if source.startswith(in_quote * 3, i):
                        i += 3
                        in_quote = None
                        triple = False
                        continue
                    i += 1
                    continue
                if escaped:
                    escaped = False
                    i += 1
                    continue
                if source[i] == '\\':
                    escaped = True
                    i += 1
                    continue
                if source[i] == in_quote:
                    in_quote = None
                i += 1
                continue

            if source.startswith("'''", i):
                in_quote = "'"
                triple = True
                i += 3
                continue
            if source.startswith('"""', i):
                in_quote = '"'
                triple = True
                i += 3
                continue
            ch = source[i]
            if ch in "'\"":
                in_quote = ch
                triple = False
                i += 1
                continue
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            i += 1

        argument = source[start + len(needle): i - 1]
        parts: list[str] = []
        j = 0
        while j < len(argument):
            if argument.startswith("'''", j) or argument.startswith('"""', j):
                quote = argument[j]
                end = argument.find(quote * 3, j + 3)
                if end < 0:
                    raise SystemExit('FAIL: unterminated triple string in db.execute')
                parts.append(argument[j + 3:end])
                j = end + 3
                continue
            if argument[j] in "'\"":
                quote = argument[j]
                j += 1
                buf: list[str] = []
                while j < len(argument):
                    ch = argument[j]
                    if ch == '\\' and j + 1 < len(argument):
                        # SQL literals here only need common escaped quotes/backslash.
                        buf.append(argument[j + 1])
                        j += 2
                        continue
                    if ch == quote:
                        j += 1
                        break
                    buf.append(ch)
                    j += 1
                parts.append(''.join(buf))
                continue
            j += 1

        if parts:
            out.append(''.join(parts).strip())
        pos = i

    return out


migration_sql = extract_execute_sql(migrations)

conn = sqlite3.connect(':memory:')
conn.execute('PRAGMA foreign_keys = ON')

for statement in v1_sql:
    conn.execute(statement)

for index, statement in enumerate(migration_sql, start=1):
    try:
        conn.execute(statement)
    except sqlite3.Error as exc:
        first_line = statement.strip().splitlines()[0]
        raise SystemExit(
            f'FAIL: migration SQL #{index} ({first_line}) -> {exc}'
        ) from exc

required_tables = {
    'objects', 'requests', 'materials', 'work_reports', 'photos',
    'sync_queue', 'app_settings', 'object_notes', 'object_equipment',
    'reference_values', 'request_materials', 'stock_movements',
    'organization_profile', 'inventory_documents',
    'inventory_document_items', 'goods_receipts', 'goods_receipt_items',
    'stock_batches', 'request_material_batch_allocations', 'engineers',
    'engineer_stock', 'engineer_stock_batches', 'stock_transfers',
    'stock_transfer_items',
}

actual_tables = {
    row[0]
    for row in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    )
}
missing = sorted(required_tables - actual_tables)
if missing:
    raise SystemExit(f'FAIL: missing tables after migrations: {missing}')

request_material_columns = {
    row[1] for row in conn.execute('PRAGMA table_info(request_materials)')
}
for required in {'source_kind', 'source_engineer_id'}:
    if required not in request_material_columns:
        raise SystemExit(f'FAIL: request_materials missing column {required}')

movement_columns = {
    row[1] for row in conn.execute('PRAGMA table_info(stock_movements)')
}
for required in {'receipt_id', 'engineer_id', 'engineer_balance_after'}:
    if required not in movement_columns:
        raise SystemExit(f'FAIL: stock_movements missing column {required}')

print(
    'OK: SQLite schema v1 -> v15 executes successfully; '
    f'{len(required_tables)} required tables present; '
    f'{len(migration_sql)} SQL statements checked.'
)
