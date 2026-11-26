import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';

class WebCredentialsStore {
  static const String _databaseName = 'unigrades';
  static const String _storeName = 'credentials';

  static Future<void> save({
    required String fnum,
    required String egn,
  }) async {
    await saveValue('fnum', fnum);
    await saveValue('egn', egn);
  }

  static Future<void> saveValue(String key, String value) async {
    final db = await _openDatabase();
    final transaction = db.transaction(_storeName, idbModeReadWrite);
    final store = transaction.objectStore(_storeName);
    await store.put(value, key);
    await transaction.completed;
  }

  static Future<String?> read(String key) async {
    final db = await _openDatabase();
    final transaction = db.transaction(_storeName, idbModeReadOnly);
    final store = transaction.objectStore(_storeName);
    final value = await store.getObject(key) as String?;
    await transaction.completed;
    return value;
  }

  static Future<void> saveLastGrades(String grades) => saveValue('last_grades', grades);

  static Future<String> readLastGrades() async {
    final value = await read('last_grades');
    return value ?? '';
  }

  static Future<void> clear() async {
    final db = await _openDatabase();
    final transaction = db.transaction(_storeName, idbModeReadWrite);
    final store = transaction.objectStore(_storeName);
    await store.clear();
    await transaction.completed;
  }

  static Future<Database> _openDatabase() {
    return idbFactoryWeb.open(
      _databaseName,
      version: 1,
      onUpgradeNeeded: (event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
  }
}