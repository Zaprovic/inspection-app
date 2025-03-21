import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _db;
  static DatabaseService get instance => _instance;
  static final DatabaseService _instance = DatabaseService._constructor();

  final String _databaseName = 'inspections';

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, 'inspections_data.db');

    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
CREATE TABLE IF NOT EXISTS $_databaseName(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  date TEXT,
  location TEXT,
  description TEXT
)''');
      },
    );
    return database;
  }

  // Create operation
  Future<int> createInspection(Map<String, dynamic> inspection) async {
    final db = await database;
    return await db.insert(_databaseName, inspection);
  }

  // Read operations
  Future<List<Map<String, dynamic>>> getAllInspections() async {
    final db = await database;
    return await db.query(_databaseName);
  }

  Future<Map<String, dynamic>?> getInspection(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _databaseName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Update operation
  Future<int> updateInspection(int id, Map<String, dynamic> inspection) async {
    final db = await database;
    return await db.update(
      _databaseName,
      inspection,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete operations
  Future<int> deleteInspection(int id) async {
    final db = await database;
    return await db.delete(_databaseName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllInspections() async {
    final db = await database;
    return await db.delete(_databaseName);
  }

  // Close the database
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
