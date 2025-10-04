import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:swipewipe10/models/album.dart';
import 'package:swipewipe10/models/media.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('swipeclean.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgradeDB);
  }

  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE medias ADD COLUMN filename TEXT NOT NULL DEFAULT ""');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const nullableTextType = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const nullableIntType = 'INTEGER';
    const boolType = 'BOOLEAN NOT NULL';
    const dateType = 'TEXT NOT NULL';
    const nullableDateType = 'TEXT';

    // Create Albums table
    await db.execute('''
CREATE TABLE albums (
  id $idType,
  name $textType,
  cover_path $nullableTextType,
  is_premium $boolType,
  created_at $dateType
)
''');

    // Create Medias table
    await db.execute('''
CREATE TABLE medias (
  id $idType,
  original_path $textType,
  filename $textType,
  media_type $textType,
  album_id $nullableIntType,
  deleted_at $nullableDateType,
  FOREIGN KEY (album_id) REFERENCES albums (id) ON DELETE SET NULL
)
''');

    // Insert default albums
    await _insertDefaultAlbums(db);
  }

  Future _insertDefaultAlbums(Database db) async {
    final defaultAlbums = [
      Album(name: 'Favorites', createdAt: DateTime.now(), isPremium: false),
      Album(name: 'Trips', createdAt: DateTime.now(), isPremium: false),
      Album(name: 'Family', createdAt: DateTime.now(), isPremium: false),
    ];

    for (final album in defaultAlbums) {
      await db.insert('albums', {
        'name': album.name,
        'is_premium': album.isPremium ? 1 : 0,
        'created_at': album.createdAt.toIso8601String(),
      });
    }
  }

  // --- Albums CRUD ---

  Future<Album> createAlbum(Album album) async {
    final db = await instance.database;
    final id = await db.insert('albums', album.toMap());
    return album.copyWith(id: id);
  }

  Future<Album?> readAlbum(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'albums',
      columns: ['id', 'name', 'cover_path', 'is_premium', 'created_at'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Album.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Album>> readAllAlbums() async {
    final db = await instance.database;
    final result = await db.query('albums', orderBy: 'created_at DESC');
    return result.map((json) => Album.fromMap(json)).toList();
  }

  Future<int> updateAlbum(Album album) async {
    final db = await instance.database;
    return db.update(
      'albums',
      album.toMap(),
      where: 'id = ?',
      whereArgs: [album.id],
    );
  }

  // --- Media CRUD ---

  Future<Media> createMedia(Media media) async {
    final db = await instance.database;
    final id = await db.insert('medias', media.toMap());
    return media.copyWith(id: id);
  }

  Future<List<Media>> readUnsortedMedia({int limit = 20}) async {
    final db = await instance.database;
    final result = await db.query(
      'medias',
      where: 'album_id IS NULL AND deleted_at IS NULL',
      orderBy: 'id DESC', // Assuming newer media have higher IDs
      limit: limit,
    );
    return result.map((json) => Media.fromMap(json)).toList();
  }

  Future<List<Media>> readMediaByAlbum(int albumId) async {
    final db = await instance.database;
    final result = await db.query(
      'medias',
      where: 'album_id = ? AND deleted_at IS NULL',
      whereArgs: [albumId],
      orderBy: 'id DESC',
    );
    return result.map((json) => Media.fromMap(json)).toList();
  }

  Future<List<Media>> readLastTenTrashedMedia() async {
    final db = await instance.database;
    final result = await db.query(
      'medias',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
      limit: 10,
    );
    return result.map((json) => Media.fromMap(json)).toList();
  }

  Future<int> updateMedia(Media media) async {
    final db = await instance.database;
    return db.update(
      'medias',
      media.toMap(),
      where: 'id = ?',
      whereArgs: [media.id],
    );
  }

  Future<int> deleteMediaPermanently(int id) async {
    final db = await instance.database;
    return await db.delete(
      'medias',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Media?> readOldestTrashedMedia() async {
    final db = await instance.database;
    final result = await db.query(
      'medias',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at ASC', // Oldest first
      limit: 1,
    );
    return result.isNotEmpty ? Media.fromMap(result.first) : null;
  }
}