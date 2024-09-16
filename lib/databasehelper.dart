//  db_helper.dart
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:cloud_firestore/cloud_firestore.dart';


class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), 'db_media.db');
    return openDatabase(path, version: 1, onCreate: _createTable);
  }

  Future<void> _createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE media (
        id TEXT PRIMARY KEY,
        FileName TEXT,
        FileExtension TEXT,
        FilePath TEXT
      )
    ''');
  }

  Future<String> insertMedia(Map<String, dynamic> media) async {
    Database db = await database;
    String uuid = Uuid().v4();
    media['id'] = uuid;
    await db.insert('media', media);
    return uuid; 
  }

  Future<List<Map<String, dynamic>>> getAllMedia() async {
    Database db = await database;
    return await db.query('media');
  }

Future<void> uploadToFirebase() async {
  List<Map<String, dynamic>> allMedia = await getAllMedia();

  for (var media in allMedia) {
    String id = media['id'];
    String fileName = _generateFileNameWithDateTime(media['FileName']);
    String fileExtension = media['FileExtension'];
    String filePath = media['FilePath'];

    DocumentSnapshot docSnapshot = await FirebaseFirestore.instance.collection('media').doc(id).get();
    if (!docSnapshot.exists) {
      firebase_storage.Reference ref = firebase_storage
          .FirebaseStorage.instance
          .ref('Nandakumar M/media/$fileName');
      String contentType = _getContentType(fileExtension);

      firebase_storage.UploadTask task =
          ref.putFile(File(filePath), firebase_storage.SettableMetadata(contentType: contentType));

      await task.whenComplete(() async {
         String downloadURL = await ref.getDownloadURL();
        FirebaseFirestore.instance.collection('media').doc().id;
        await FirebaseFirestore.instance.collection('media').doc(id).set({
          'FileName': fileName,
          'FileExtension': fileExtension,
          'FilePath': downloadURL,
        });
      });
    }
  }
}

String _generateFileNameWithDateTime(String originalFileName) {
  String currentDate = DateTime.now().toLocal().toString();
  String formattedDate = currentDate.replaceAll(RegExp(r'[^0-9]'), '');
  return '${originalFileName}_$formattedDate';
}

String _getContentType(String fileExtension) {
  switch (fileExtension.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'pdf':
      return 'application/pdf';
    case 'mp3':
      return 'audio/mp3';
    case 'mp4':
      return 'video/mp4';
    case 'mp4':
      return 'video/HEVC';
    default:
      return 'application/octet-stream';
  }
}

}