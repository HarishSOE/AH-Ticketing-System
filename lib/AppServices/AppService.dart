import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
// import 'package:intl/intl.dart' as format;
import 'package:path/path.dart' as path;

class AppService {
  // Create Single Instance for Entire App
  static final AppService _instance = AppService._internal();
  AppService._internal();
  factory AppService() => _instance;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  Map<String, dynamic> participantDashboard = {};
  Map<String, dynamic> loggedinProfile = {};
  Map<String, dynamic> loggedinRoles = {};
  bool notificationAvailable = false;
  bool newMessage = false;
  Map<String, dynamic> profileJourneyProduct = {};
  List<Map<String, dynamic>> participantProductList = [];

  // Map Data
  Map<String, dynamic> profiledataMap = {};
  // Mode
  Map<String, dynamic> modes = {};
  ValueNotifier appdataNotifier = ValueNotifier(true);

  // Video Player
  bool muteVideo = true;

  // Continue Watching
  List<Map<String, dynamic>> lastWatched = [];


  // Flutter Local Notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  Future<void> initializeNotifications() async {
    final InitializationSettings initializationSettings = InitializationSettings(android: AndroidInitializationSettings('app_icon'));
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Return Profile Map
  Future<Map<String, dynamic>> mapProfile() async {
    Map<String, dynamic> profileMap = {};
    Map<String, String> map = {};
    List<Map<String, dynamic>> list = [];
    await firestore.collection("profile_data").orderBy("name").get().then((profile) {
      for (var element in profile.docs) {
        Map<String, dynamic> data = element.data();
        map[element.id] = data["name"];
        profileMap[element.id] = data;
        list.add(element.data());
      }
    });
    return {"map": map, "list": list, "profile": profileMap};
  }

  Future<Map<String, dynamic>> mapProcedure() async {
    Map<String, dynamic> map = {};
    await firestore.collection("procedures").get().then((profile) {
      for (var element in profile.docs) {
        map[element.id] = element.data()["name"];
      }
    });
    return map;
  }

  Future<void> showNotification(int id, String title, String body, int? progress) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'channel id', 'channel name',
      importance: Importance.max,
      // priority: Priority.high,
      autoCancel: true,
      onlyAlertOnce: true,
      showProgress: progress != null,
      maxProgress: 100, 
      progress: progress ?? 0,
    );
    NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(id, title, body, platformChannelSpecifics);
  }

  Future<void> showNotificationNoDismiss(int id, String title, String body, int progress) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, 
      onlyAlertOnce: true,
      showProgress: true, 
      maxProgress: 100, 
      progress: progress,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(id, title, body, platformChannelSpecifics);
  }

  updateFCMToken(String email, String token, String uid, String pid, bool value) async {
    await firestore.collection("FCM_token").where("email", isEqualTo: email).where('FCM_id', isEqualTo: token).get().then((QuerySnapshot query) async {
      final PackageInfo info = await PackageInfo.fromPlatform();
      String version = info.version;
      String build = info.buildNumber;
      if (query.docs.length == 0) {
        firestore.collection("FCM_token").add({
          "FCM_id": token,
          "email": email,
          "uid": uid,
          "user_ref": firestore.collection("user_data").doc(uid),
          "profile_ref": firestore.collection("profile_data").doc(pid),
          "active": value,
          "device_os": Platform.operatingSystem,
          "created": FieldValue.serverTimestamp(),
          "last_modified": FieldValue.serverTimestamp(),
          "current_version": version + "." + build
        });
      } else {
        for (var data in query.docs) {
          data.reference.update({
            "active": value,
            "device_os": Platform.operatingSystem,
            "last_modified": FieldValue.serverTimestamp(),
            "current_version": version + "." + build
          });
        }
      }
    });
  }

  // Return Product Map
  Future<Map<String, dynamic>> mapProduct() async {
    Map<String, dynamic> map = {};
    await firestore.collection("products").get().then((profile) {
      for (var element in profile.docs) {
        map[element.id] = element.data();
      }
    });
    return map;
  }

  // Return Journey Map
  Future<Map<String, dynamic>> mapJourney() async {
    Map<String, dynamic> map = {};
    await firestore.collection("journey").get().then((profile) {
      for (var element in profile.docs) {
        map[element.id] = element.data();
      }
    });
    return map;
  }

  // Chat Media
  Future<Database> initChatSQLite() async {
    String path = join(await getDatabasesPath(), 'db_chat_media.db');
    try {
      Reference storageReference = FirebaseStorage.instance.ref().child('flutterSqlite/${loggedinProfile["profileid"]}/${DateTime.now().toString()}_db_chat_media.db');
      File file = File(path);
      String contentType ='application/db';
      UploadTask uploadTask = storageReference.putFile(file, SettableMetadata(contentType: contentType),);
      uploadTask.whenComplete(() async{
        String url = "";
        await storageReference.getDownloadURL().then((value) {
          url = value;
        }).catchError((err){
          logException(exception: "$err", stack: "$path");
        });
        firestore.collection("profiledb").doc(loggedinProfile["profileid"]).set({
          "chat": url,
          "lastupdated": FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
      });
    } catch (err) {
      print("VA DB Upload err $err");
    }
    return openDatabase(path, version: 4, onCreate: chatMediaTable);
  }

  // Create Table
  Future<void> chatMediaTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chatmedia (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT,
        fileextension TEXT,
        filepath TEXT,
        messagepath TEXT,
        senderprofileid TEXT,
        uploaded INTEGER 
      )
    ''');
  }

  // Upload Process
  Map<String, Map> uploadProcessing = {};
  List<String> supportedImageFormat = ["jpg", "jpeg", "png"];
  List<String> supportedVideoFormat = ["mp4", "mov", "3gp"];
  List<String> supportedDocFormat = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'xls', 'xlsx', 'ppt', 'pptx', 'csv', 'html', 'htm', 'xml', 'epub', 'md', 'json', 'latex'];
  List<String> supportedAudioFormat = ['mp3', 'wav', 'aac', 'flac', 'ogg', 'wma', 'aiff', 'm4a', 'amr', 'mid', 'midi', 'ac3', 'opus', 'mka','octet-stream'];

  uploadMedia(Database db, String table, String docpathField, {Function()? callBack}){
    print("${db},'dddddddbbbb");
    print(table);
    print(docpathField);

    db.query("$table", where: "uploaded = ?", whereArgs: ["0"]).then((value) async {
      List pendingMedia = value;
      print("Media to Upload $pendingMedia");
      if(pendingMedia.isNotEmpty){
        // showNotification(300, 'Uploading', 'Please wait while your file is being uploaded.', 0);
      }
      for (int i = 0; i < pendingMedia.length; i++) {
        dynamic media = pendingMedia[i];
        //  non-dismissible
        // showNotificationNoDismiss(i, 'Uploading', 'Please wait while your file is being uploaded.', 0);
        // Create Job
        String messageid = firestore.doc(media["messagepath"]).id;
        uploadProcessing[messageid] = uploadProcessing[messageid] ?? {};
        if(uploadProcessing[messageid]![media["id"]] == null){
          try {
            // Storage Reference
            Reference storageReference = FirebaseStorage.instance.ref().child('$table/media/${DateTime.now().toString()}_${media['filename']}');
            File file = File(media["filepath"]);
            String? contentType;
            File? compressedFile;
            if(supportedImageFormat.contains(media["fileextension"].toLowerCase())){
              contentType = 'image/${media["fileextension"]}';
              await compressImage(media["filepath"], "image", media["fileextension"]).then((value) {
                if(value != null){
                  compressedFile = File(value);
                }
              }).catchError((err){
                print("Image Compression Failed -- $err");
                logException(exception: "$err", stack: "");
              });
            }
            else if(supportedVideoFormat.contains(media["fileextension"].toLowerCase())){
              contentType = 'video/${media["fileextension"]}';
              await compressImage(media["filepath"], "video", media["fileextension"]).then((value) {
                if(value != null){
                  compressedFile = File(value);
                }
              }).catchError((err){
                print("Video Compression Failed -- $err");
                logException(exception: "$err", stack: "");
              });
            }
            else if(supportedDocFormat.contains(media["fileextension"].toLowerCase())){
              contentType = 'application/${media["fileextension"]}';
            }
            else if(supportedAudioFormat.contains(media["fileextension"].toLowerCase())){
              contentType = 'audio/${media["fileextension"]}';
            }
            print("${compressedFile},compressed file");
            print("${file},FILE");

            UploadTask uploadTask = storageReference.putFile(compressedFile ?? file, SettableMetadata(contentType: contentType),);
            StreamSubscription progress = uploadTask.snapshotEvents.listen((event) {
              double percentage = event.bytesTransferred.toDouble() / event.totalBytes.toDouble();
              // int progress = (percentage * 100).toInt();
              // showNotification(i, 'Uploading', 'Please wait while your file is being uploaded.', progress);
              uploadProcessing[messageid]![media["id"]] = percentage;
              if(percentage == 1.0){
                uploadProcessing[messageid]?.remove(media["id"]);
              }
              print("Upload Progress ---- ${uploadProcessing[messageid]![media["id"]]}");
              if(callBack != null) callBack();
            });
            uploadTask.whenComplete(() async{
              progress.cancel();
              uploadProcessing[messageid]?.remove(media["id"]);
              if(callBack != null) callBack();
              String url = await storageReference.getDownloadURL();
              print("${url}, FILE URL");
              String? filethumbnail;
              if(contentType?.split("/")[0] == "video"){
                try {
                  String? thumbnailFile = await VideoThumbnail.thumbnailFile(
                    video: url,
                    thumbnailPath: (await getTemporaryDirectory()).path,
                    imageFormat: ImageFormat.JPEG,
                    quality: 50,
                  );
                  if(thumbnailFile != null){
                    print(thumbnailFile);
                    String thumbnailName = thumbnailFile.split('/').last;
                    Reference thumbnailReference = FirebaseStorage.instance.ref().child('$table/media/${DateTime.now().toString()}_$thumbnailName}');
                    UploadTask uploadThumbnailTask = thumbnailReference.putFile(File(thumbnailFile), SettableMetadata(contentType: "image/jpeg"),);
                    await uploadThumbnailTask.whenComplete(() async{
                      filethumbnail = await thumbnailReference.getDownloadURL();
                    });
                  }
                } catch (exception) {
                  print("Thumbnail Exception $exception");
                  logException(exception: "$exception", stack: "");
                }
              }
              firestore.doc(media["$docpathField"]).update({
                "files": FieldValue.arrayUnion([{
                  "filename": media["filename"],
                  "filetype": media["fileextension"],
                  "fileurl": url,
                  "mediatype": contentType?.split("/")[0],
                  "filethumbnail": filethumbnail
                }])
              }).then((_) {
                db.update(table, {"uploaded": 1}, where: "id = ?", whereArgs: [media["id"]]);
                showNotification(i, 'Upload Completed', 'Your file has been uploaded successfully.', null);
              }).catchError((err){
                logException(exception: "$err", stack: "");
              });
            });
          } catch (err) {
            logException(exception: "$err", stack: "");
          }
        }
      }
    });
  }

  Future<String> getOutputPath(String format) async {
    final directory = await (Platform.isIOS ? getApplicationDocumentsDirectory() : getExternalStorageDirectory());
    final uniqueId = const Uuid().v4();
    return path.join(directory!.path, 'compressed_$uniqueId.$format'); 
  }

  // Compress Media
  Future<String?> compressImage(String filePath, String filetype, String format) async {
    final outputPath = await getOutputPath(format);
    print("Compressed Path $outputPath");
    if(outputPath.isNotEmpty){
      late Future<FFmpegSession> ffmpeg;
      if(filetype == "image"){
        ffmpeg = FFmpegKit.execute('-y -i $filePath -vf "scale=720:-2" -b:v 500k -update 1 $outputPath');
      }
      else{
        ffmpeg = FFmpegKit.execute('-i $filePath -vf "scale=1080:-2" -vcodec h264 -update 1 $outputPath');
      }
      await ffmpeg; 
      if (await File(outputPath).exists()) {
        print("File exists at ${outputPath}");
        return outputPath;
      } else {
        print("File does not exist at $outputPath");
        return null; 
      }
    }
    else{
      return null;
    }
  }

  // Workshop Task Update
  updateWorkshopTaskStatus({required String currentTask, required String? value, required Map<String, dynamic> participantChallenge}){
    Map<String, dynamic> newValue = {
      "taskproperty.$currentTask.status": "completed",
    };
    if(value != null){
      newValue["taskproperty.$currentTask.value"] = firestore.doc(value);
    }
    try {
      List participantTask = participantChallenge["tasks"];
      int index = participantTask.indexOf("$currentTask");
      print("Task Order ${participantTask} --- $index");
      if((participantTask.length > index + 1) && index != -1){
        List subTask = participantTask.sublist(index + 1).toList();
        for (int i = 0; i < subTask.length; i++) {
          dynamic element = subTask[i];
          if(participantChallenge["taskproperty"][element]["type"] != "livecall"){
            if(participantChallenge["taskproperty"][element]["status"] == null){
              newValue["taskproperty.$element.status"] = "ready";
            }
            break;
          }
        }
        // String nextTask = participantTask[index + 1];
        // if(participantChallenge["taskproperty"][nextTask]["status"] == null){
        //   newValue["taskproperty.$nextTask.status"] = "ready";
        // }
      }
    } catch (err) {
      print("Catch ** $err");
    }
    print("New Value $newValue");
    firestore.collection("eiflix participant workshop").doc(participantChallenge["docid"]).update(newValue);
  }

  logException({required String exception, required String stack}){
    try {
      firestore.collection("app exception log").add({
        "exception": exception,
        "stack": stack,
        "date": FieldValue.serverTimestamp(),
        "profileid": "${loggedinProfile["profileid"]}",
        "device_os": "${Platform.operatingSystem}",
        "version": "${Platform.operatingSystemVersion}"
      }).then((value) {}).catchError((err) {
        print(err);
        logException(exception: "$err", stack: "");
      });
    } catch (error) {
      print("catch error: $error");
    }
  }
}