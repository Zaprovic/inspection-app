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
      version: 2, // Increased version for schema update
      onCreate: (db, version) {
        return db.execute('''
CREATE TABLE IF NOT EXISTS $_databaseName(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  date TEXT,
  location TEXT,
  description TEXT,
  status TEXT NOT NULL DEFAULT "Pendiente de sincronización"
)''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add status column if upgrading from version 1
          await db.execute(
            'ALTER TABLE $_databaseName ADD COLUMN status TEXT NOT NULL DEFAULT "Pendiente de sincronización"',
          );
        }
      },
    );
    return database;
  }

  // Create operation
  Future<int> createInspection(Map<String, dynamic> inspection) async {
    final db = await database;

    // Ensure status field is included
    if (!inspection.containsKey('status')) {
      inspection['status'] = 'Pendiente de sincronización';
    }

    return await db.insert(_databaseName, inspection);
  }

  // Read operations
  Future<List<Map<String, dynamic>>> getAllInspections() async {
    final db = await database;
    return await db.query(_databaseName, orderBy: 'date DESC');
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

  // Get inspections by status
  Future<List<Map<String, dynamic>>> getInspectionsByStatus(
    String status,
  ) async {
    final db = await database;
    return await db.query(
      _databaseName,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'date DESC',
    );
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

  // Update only the status of an inspection
  Future<int> updateInspectionStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      _databaseName,
      {'status': status},
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
