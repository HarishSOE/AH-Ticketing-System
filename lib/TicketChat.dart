import 'dart:async';
import 'dart:io';

import 'package:ahticketing/AppServices/UserData.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:better_player/better_player.dart';
import 'package:ahticketing/databasehelper.dart';
import 'package:ahticketing/AppServices/AppService.dart';
import 'package:ahticketing/Widgets/shimmerLoading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:ahticketing/Themes.dart';
import 'package:ahticketing/Widgets/confirmationDialog.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:wakelock/wakelock.dart';
import 'package:sqflite/sqflite.dart';

class TicketChat extends StatefulWidget {
  final int chatIndex;
  final String issueid;
  final String userUid;
  final String userName;
  final String userEmail;
  final String userProfileID;
  final CollectionReference messageRef;
  final DocumentReference? issueref;

  // ignore: use_super_parameters
  const TicketChat({
    Key? key,
    required this.chatIndex,
    required this.issueid,
    required this.userUid,
    required this.userName,
    required this.userEmail,
    required this.userProfileID,
    required this.messageRef,
    this.issueref,
  }) : super(key: key);

  @override
  _TicketChat createState() => _TicketChat();
}

class _TicketChat extends State<TicketChat> {
    double sliderValue(double value, double min, double max) {
    return value.clamp(min, max);
  }
  TextEditingController message = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool sendingSms = false;
  StreamSubscription<QuerySnapshot>? streamListener;
  AutoScrollController scrollcontroller = AutoScrollController();
  bool newMessage = true;
  AppTheme localTheme = AppTheme();
  bool selectMode = false;
  List<Map> selectedMessages = [];
  Map<String, dynamic> mapprofiledata = {};
  AppService appService = AppService();
  Map<String,dynamic> issueData = {};
  Map<String,dynamic> mapProfile = {};
  Map profileData = {};
  Map loginProfileRoles = {};

  // Chat Media
  List selectedMedia = [];
  List<String> supportedImageFormat = ["jpg", "jpeg", "png"];
  List<String> supportedVideoFormat = ["mp4", "mov", "3gp"];
  List<String> supportedDocFormat = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'xls', 'xlsx', 'ppt', 'pptx', 'csv', 'html', 'htm', 'xml', 'epub', 'md', 'json', 'latex'];
  List<String> supportedAudioFormat = ['mp3', 'wav', 'aac', 'flac', 'ogg', 'wma', 'aiff', 'm4a', 'amr', 'mid', 'midi', 'ac3', 'opus', 'mka','octet-stream'];
  late Database chatDB;
  late AudioPlayer _audioPlayer;
  String? currentlyPlayingUrl;
  BetterPlayerController? betterPlayerController;
  int totalBytes = 0;
  int downloadedBytes = 0;
  bool loading = true;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  List localarraydata = [];

  @override
  void initState() {
    super.initState();
    initializeNotifications();

    UserData().getUserData().then((value) async {
      await firestore.collection("profile_data").doc(widget.userProfileID).get().then((profile) async {
        await firestore.doc(profile.data()?["role_ref"].path).get().then((role) {
          setState(() {
            profileData = profile.data()!;
            loginProfileRoles = role.data()!;
          });
        });
      });
      
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _audioPlayer = AudioPlayer();
    _audioPlayer.durationStream.listen((duration) {
      if(duration != null && mounted){
        setState(() {
          duration = duration;
        });
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if(mounted){
        setState(() {
          position = position;
        });
      }
      if(_audioPlayer.position == _audioPlayer.duration){
        if(mounted){
          setState(() {
            _audioPlayer.pause();
          });
        }
      }
    });

    appService.initChatSQLite().then((db) {
      chatDB = db;
      db.query("chatmedia",).then((value) {
        print(value);
      });
    });

    await firestore.collection("profile_data").where("user_ref", isNull: false).get().then((profile) {
      for (var element in profile.docs) {
        Map<String, dynamic> data = element.data();
        mapprofiledata[data["user_ref"].id] = data;
      }
      if(mounted) setState(() {});
    });

    await appService.mapProfile().then((value) { mapProfile = value['profile'];});

    scrollcontroller.scrollToIndex(widget.chatIndex, duration: Duration(seconds: 1), preferPosition: AutoScrollPosition.middle);
    firestore.collection("clientissue").doc(widget.issueid).update({
      "last_read_by": FieldValue.arrayUnion(["admin"]),
      "last_pending": FieldValue.arrayRemove(["admin"])
    });
    setState(() {
      streamListener = firestore.collection("clientissue").doc(widget.issueid).collection("messages").where("pending", arrayContains: "admin").snapshots().listen((newData) {
        for (var data in newData.docs) {
          updateSupportDesk(data.reference, widget.userUid);
        }
      });
    });

    widget.issueref?.get().then((issueDoc) {
      setState(() {
        issueData = issueDoc.data() as Map<String,dynamic>;
        loading = false;
      });
    });

    });

  }
  
  void initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var android = AndroidInitializationSettings('@drawable/ic_lyl');
    var ios = DarwinInitializationSettings();
    final InitializationSettings initializationSettings = InitializationSettings(android: android, iOS: ios);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void showNotification(String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails('channelId', 'channelName',importance: Importance.max, priority: Priority.high,);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      '$message',
      '',
      platformChannelSpecifics,
      payload: '',
    );
  }

  Future<void> downloadFile(fileurl) async {
    // ignore: unused_local_variable
    final response = (Uri.parse(fileurl), onReceiveProgress: (count, total) {
      totalBytes = total;
      downloadedBytes = count;

      // Calculate the percentage
      double percentage = (downloadedBytes / totalBytes) * 100;

      // Update notification with the download percentage
      updateNotification(percentage.round());

      setState(() {}); // Trigger a rebuild to update UI if needed
    });
  }

  Future<void> updateNotification(int percentage) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails('download_channel', 'Download',);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Download Progress',
      '$percentage%',
      platformChannelSpecifics,
    );
  }

  Future<void> _addToFirebase() async {
    DatabaseHelper().uploadToFirebase(); 
  }

  void _pickFiles(FileType fileType, {List<String>? allowedExtensions}) async {
    print("Allowed Extension $allowedExtensions");
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowMultiple: true,
      allowedExtensions: allowedExtensions,
      allowCompression: true,
    );

    if (result != null) {
      print("picked file");
      print("result $result");

      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      Directory customFolder = Directory('${documentsDirectory.path}/chatMedia');
      if (!await customFolder.exists()) {
        await customFolder.create(recursive: true);
      }
      
      for (PlatformFile file in result.files) {
        String extension = file.extension!;

        // Copy File to Temporary Folder
        File newFile = File(file.path!);
        File cloneFile = await newFile.copy('${customFolder.path}/${newFile.path.split('/').last}');

        selectedMedia.add({
          "file": cloneFile,
          "extension": extension
        });
      }
      if(mounted) setState(() {});
      print("Media Selected $selectedMedia");

    } else {
      print('No files picked');
    }
  }

  downloadFilebyURL(url)async{
     Directory? documents = await (Platform.isIOS ? getApplicationDocumentsDirectory() : getExternalStorageDirectory());
     print(documents?.path);

    if(documents != null){
      await FlutterDownloader.enqueue(
        url: url,
        headers: {}, // optional: header send with url (auth token etc)
        savedDir: '${documents.path}',
        showNotification: true, // show download progress in status bar (for Android)
        openFileFromNotification: true, // click on notification to open downloaded file (for Android)
        saveInPublicStorage: true
      ).then((value){
        print("Download Task $value");
      });
    }
  }

  updateSupportDesk(DocumentReference msgRef, String uid) {
    msgRef.update({
      "read_by": ['admin'],
      "pending":  ['user'],
    });

    firestore.collection("clientissue").doc(widget.issueid).update({
      "last_modified" : DateTime.now() 
    });

  }

  submittoMessages(String sms) async {
    List<String> utubeURL = [];
    RegExp linkPattern = RegExp(r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+');
    Iterable<RegExpMatch> matches = linkPattern.allMatches(sms);
    for (var match in matches) {
      RegExp youtubePattern = RegExp(r'^((?:https?:)?\/\/)?((?:www|m)\.)?((?:youtube(-nocookie)?\.com|youtu.be))(\/(?:[\w\-]+\?v=|embed\/|v\/)?)([\w\-]+)(\S+)?$');
      if(youtubePattern.hasMatch(sms.substring(match.start, match.end))){
        utubeURL.add(sms.substring(match.start, match.end));
      }
    }
    setState(() {
      newMessage = false;
    });
    DateTime time = DateTime.now();
    String docID = firestore.collection("messages").doc().id;
    // Store Media in Local DB
    await storeChatMedia(firestore.collection("clientissue").doc(widget.issueid).collection("messages").doc(docID).path);
    firestore.collection("clientissue").doc(widget.issueid).collection("messages").doc(docID).set({
      "time": time,
      "sender_uid": widget.userUid,
      "sender_email": widget.userEmail,
      "sender_profileid" : widget.userProfileID,
      "message": sms,
      "messageid": docID,
      "read_by": loginProfileRoles['chatxadmin'] ? ['admin'] : ["user"],
      "pending": loginProfileRoles['chatxadmin'] ? ['user'] : ["admin"],
      "links": utubeURL.isEmpty ? null : utubeURL,
      "files" : [],
      // "type" : uploadedFiles.length == 0 ? 'text' : uploadedFiles[0]['filetype']
    }).then((_) async{
      await firestore.collection("clientissue").doc(widget.issueid).update({
        "last_modification": time,
        "last_read_by": loginProfileRoles['chatxadmin'] ? ['admin'] : ["user"],
        "last_pending": loginProfileRoles['chatxadmin'] ? ['user'] : ["admin"],
      });

      if(loginProfileRoles['chatxadmin']){
        print(loginProfileRoles['chatxadmin']);
        await sendNotification(issueData, sms, mapProfile[issueData['clientid']]['user_ref'].id);
      }
      if (mounted) {
        setState(() {
          sendingSms = false;
        });
      }
    });
  }

  sendNotification(issueData,message, receiverId) async {
    var docId = firestore.collection("notifications").doc().id;
    issueData['date'] = DateTime.now();
    issueData['message'] = message;
    issueData['read'] = false;
    issueData['type'] = "inappmessage";
    await firestore.collection('notifications').doc(receiverId).collection('logs').doc(docId).set(issueData).then((_){
      print('Notofication Log has been created');
    }).catchError((error){
      print("'Error Creating Notification Log',${error}");
    });
  }

  storeChatMedia(String messagePath)async{
    if(selectedMedia.isNotEmpty){
      for (var media in selectedMedia) {
        File mediaFile = media["file"];
        String extension = media["extension"];
        await chatDB.insert("chatmedia", {
          "filename": mediaFile.path.split("/").last,
          "fileextension": extension,
          "filepath": mediaFile.path,
          "messagepath": messagePath,
          "senderprofileid": widget.userProfileID,
          "uploaded": 0
        }).then((value) {
          print("Stored DB $value");
        }).catchError((err){
          print("Error DB $err");
          appService.logException(exception: "$err", stack: "");
        });
      }
      await appService.uploadMedia(chatDB, "chatmedia", "messagepath", callBack: (){
        print("Callback Progress ${appService.uploadProcessing}");
        for (var key in appService.uploadProcessing.keys) {
          appService.uploadProcessing[key]?.keys.forEach((mediaid) {
            if(appService.uploadProcessing[key]![mediaid] == 1.0){
              appService.uploadProcessing[key]?.remove(mediaid);
            }
          });
        }
        if(mounted) setState(() {});
      });
      setState(() {
        selectedMedia.clear();
      });
    }
  }

  deleteMessages() {
    for (int i = 0; i < selectedMessages.length; i++) {
      firestore.doc(selectedMessages[i]["messagepath"]).delete();
    }
    setState(() {
      selectMode = false;
      selectedMessages.clear();
    });
    Navigator.of(context).pop();
  }

  confirmationdialog() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationWidget(
          title: "Confirmation",
          message:
              "Once you delete, the message will be deleted permenantly. Do you want to delete?",
          actions: Platform.isAndroid ? <Widget>[
            TextButton(
              child: Text("Return"),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () async {
                deleteMessages();
              },
            )
          ] : <Widget>[
            CupertinoDialogAction(
              child: Text("Return"),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            CupertinoDialogAction(
              child: Text("Delete"),
              onPressed: () async {
                deleteMessages();
              },
            )
          ],
        );
      }
    );
  }

  importMediaToChat() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select File Type'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                onTap: () {
                  _pickFiles(FileType.custom, allowedExtensions: supportedDocFormat);
                  Navigator.of(context).pop();
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Color.fromARGB(160, 160, 32, 240),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.pink,
                    child: Icon(Icons.file_open_rounded,color: Colors.white,),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  _pickFiles(FileType.audio); // , allowedExtensions: supportedAudioFormat
                  Navigator.of(context).pop();
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.audiotrack_rounded,color: Colors.white,),
                ),
              ),
              InkWell(
                onTap: () {
                  _pickFiles(FileType.media); //, allowedExtensions: [...supportedImageFormat, ...supportedVideoFormat]
                  Navigator.of(context).pop();
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Color.fromARGB(255, 6, 224, 244),
                  child: Icon(Icons.panorama_rounded,color: Colors.white,),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  GestureDetector filebuttoncreater(filetype){
    return GestureDetector(
      onTap: (){
        _pickFile(filetype);
        Navigator.pop(context);
      },
      child:AlertDialog(
        title: Text('Select File Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                _pickFiles(FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'xls', 'xlsx', 'ppt', 'pptx', 'csv', 'html', 'htm', 'xml', 'epub', 'md', 'json', 'latex'],);
                Navigator.of(context).pop();
              },
              child: Text('Document'),
            ),
            ElevatedButton(
              onPressed: () {
                _pickFiles(FileType.custom, allowedExtensions: ['mp3', 'wav', 'aac', 'flac', 'ogg', 'wma', 'aiff', 'm4a', 'amr', 'mid', 'midi', 'ac3', 'opus', 'mka'],);
                Navigator.of(context).pop();
              },
              child: Text('Audio'),
            ),
            ElevatedButton(
              onPressed: () {
                _pickFiles(FileType.media);
                Navigator.of(context).pop();
              },
              child: Text('Image and Video'),
            ),
          ],
        ),
      ),
    );
  }

  List _pickedFile = [];
  List uploadedFiles = [];
  bool fileloading = false;
  bool progress = false;
  String? localFilePath;

  Future<void> _pickFile(fileType) async {

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // allowedExtensions: ['mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a', 'wma'],
      allowMultiple: ['pdf'].contains(fileType) ? false : true,
      allowedExtensions: fileType,
      allowCompression: true
    );
    
    if (result != null) {

      setState(() {
        _pickedFile = result.
        files.map((file) => File(file.path!)).toList();
      });
      
      var file = true;
      for (int i = 0; i < _pickedFile.length; i++) {
        // var type = _pickedFile[i];
        if(["jpg","jpeg"].contains(fileType)){
          file = true;
        }else if([_pickedFile[0].path.split('.').last].contains(fileType)){
          file = false;
        }else{
          file = true;
        }
      }
      if(file){
        await _uploadFiles();
        file = true;
      }else{
        final snackBar = SnackBar(
          content: Text("Select only ${fileType} files"),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } else {
      print('User canceled the file picking');
    }
  }

  Future<void> _uploadFiles() async {

    fileloading = true;

    FirebaseStorage storage = FirebaseStorage.instance;
    Reference storageReference = storage.ref();
    uploadedFiles = [];
    var list = [];
    for (File file in _pickedFile) {
      String fileName = file.path.split('/').last;
      String filetype = file.path.split('.').last;
      String downloadURL = '';
      Reference fileReference = storageReference.child('uploads/$fileName');
      UploadTask uploadTask = fileReference.putFile(file);

      await uploadTask.whenComplete(() async {
        // Access the download link of the uploaded file
        downloadURL = await fileReference.getDownloadURL();
      });
      var files = {};
      files['filename'] = fileName;
      files['filetype'] = filetype;
      files['fileurl'] = downloadURL;
      list.add(files);
      print("listlistlistlist${list}");
    }
    setState(() {
      uploadedFiles = list;
      print('uploadedFiles.length');
      print(uploadedFiles.length);
      fileloading = false;
    });
  }

  _removeFile(_uploadedFileUrl ,index)async {
    print('_uploadedFileUrl');
    print(_uploadedFileUrl);
    print(index);
    if(_uploadedFileUrl != null){
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference storageReference = storage.refFromURL(_uploadedFileUrl!);

      await storageReference.delete();
      print('File Deleted');
      setState(() {
        uploadedFiles.removeAt(index);
      });
    } else {
      print('No file to delete');
    }
  }
  playAudio(List<dynamic> files) async {
    String fileUrl = files[0]['fileurl'];
    ConcatenatingAudioSource playlist = ConcatenatingAudioSource(children: [
      AudioSource.uri(
        Uri.parse(fileUrl),
        tag: MediaItem(
          id: fileUrl,
          title: "${files[0]['filename']}",
          artist: 'Antano & Harini',
        ),
      )
    ]);
        setState(() {
      currentlyPlayingUrl = fileUrl;
    });
    _audioPlayer.setAudioSource(playlist);
    await _audioPlayer.play();
  }

  //
  @override
  void dispose() {
    _audioPlayer.dispose();
    streamListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: selectMode ? AppBar(
          elevation: 2,
          leading: IconButton(
            icon: Icon(Icons.close, color: localTheme.barElementcolor,),
            onPressed: () {
              setState(() {
                selectMode = false;
                selectedMessages.clear();
              });
            },
          ),
          backgroundColor: localTheme.barBGcolor,
          centerTitle: localTheme.barCenterTitle,
          iconTheme: IconThemeData(
            color: localTheme.barElementcolor
          ),
          title: Text("${selectedMessages.length} Message Selected",
            style: TextStyle(
              color: localTheme.barElementcolor
            ),
          ),
          titleSpacing: Navigator.canPop(context) ? 0 : NavigationToolbar.kMiddleSpacing,
          actions: [
            selectedMessages.length == selectedMessages.where((message) =>message.containsValue(widget.userUid)).toList().length ? 
            IconButton(
              icon: Icon(Icons.delete_outline, color: localTheme.barElementcolor),
              onPressed: () {
                if (selectedMessages.length == 0) {
                  final snackBar = SnackBar(
                    content: Text("No message is selected"),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                } else {
                  confirmationdialog();
                }
              },
            ) : SizedBox(),
            IconButton(
              icon: Icon(Icons.content_copy),
              onPressed: () {
                if (selectedMessages.length == 0) {
                  final snackbar = SnackBar(
                    content: Text("No message is selected"),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackbar);
                } else {
                  if (selectedMessages.length == 1) {
                    Clipboard.setData( ClipboardData(text: selectedMessages[0]["message"]));
                  } else {
                    selectedMessages.sort((a, b) => a["date"].compareTo(b["date"]));
                    String copiedMessage = "";
                    for (int i = 0; i < selectedMessages.length; i++) {
                      copiedMessage = copiedMessage + 
                      "[${selectedMessages[i]["sendername"]}]: " +
                      selectedMessages[i]["message"] + "\n";
                    }
                    Clipboard.setData(ClipboardData(text: copiedMessage));
                  }
                  setState(() {
                    selectMode = false;
                    selectedMessages.clear();
                  });
                  final snackBar = SnackBar(
                    content: Text("Copied"),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
              },
            ),
          ],
      ) : AppBar(
        elevation: 2,
        backgroundColor: localTheme.barBGcolor,
        centerTitle: localTheme.barCenterTitle,
        iconTheme: IconThemeData(
          color: localTheme.barElementcolor
        ),
        title: GestureDetector(
          onTap: (){
          },
          child: Text(
            "Support",
            style: TextStyle(
              color: localTheme.barElementcolor
            ),
          ),
        ),
        titleSpacing: Navigator.canPop(context) ? 0 : NavigationToolbar.kMiddleSpacing,
        leading: IconButton(
          onPressed: (){
            Navigator.pop(context);
          }, 
          icon: Icon(Icons.arrow_back)
        ),
      ),
      body: loading ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SpinKitCubeGrid(
              color: localTheme.hexToColor("#ED048D"),
              size: 50.0,
            ),
            SizedBox(height: 30,),
            Text("Fetching Chats...."),
          ],
        )
      ) : WillPopScope(
        onWillPop: ()async {
          Navigator.pop(context);
          return true;
          // if (selectMode) {
          //   setState(() {
          //     selectMode = false;
          //     selectedMessages.clear();
          //   });
          // } else {
          //   // streamListener!.cancel();
          //   // if (widget.chatType == "supportdesk") {
          //   //   Navigator.popUntil(context, ModalRoute.withName("/home"));
          //   // } else {
          //   //   Navigator.of(context).pop();
          //   // }
          // }
          // return true;
        },
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).requestFocus( FocusNode());
                  },
                  child: Container(
                    color: Colors.white,
                    child: StreamBuilder(
                      stream: firestore.collection(widget.messageRef.path).orderBy("time", descending: true).snapshots(),
                      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> message) {
                        if (!message.hasData) {
                          return Center(
                            child: SpinKitFadingCube(
                              color: Colors.white,
                              size: 50,
                            ),
                          );
                        }
                        if (message.data?.docs.length == 0) {
                          return Center(
                            child: Text(
                              "Start Your Conversation Here.....",
                              style: TextStyle(
                                color: Colors.grey,
                              )
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          controller: scrollcontroller,
                          reverse: true,
                          shrinkWrap: true,
                          itemCount: message.data?.docs.length,
                          itemBuilder: (BuildContext context, index) {
                            DocumentSnapshot<Map<String, dynamic>> msgdoc = (message.data?.docs[index] ?? {}) as DocumentSnapshot<Map<String, dynamic>>;
                            Map<String, dynamic> msgdata = msgdoc.data() ?? {};
                            return AutoScrollTag(
                              controller: scrollcontroller,
                              index: index,
                              key: ValueKey(index),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  index == (message.data?.docs.length ?? 0) - 1 || 
                                  DateFormat("EEE, MMM d, yyyy").format(message.data?.docs[index].data()["time"].toDate()) != DateFormat("EEE, MMM d, yyyy").format(message.data?.docs[index + 1].data()["time"].toDate()) ? 
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      Container(
                                        padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                                        margin: EdgeInsets.fromLTRB(5, 10, 5, 10),
                                        child: Text("${DateFormat("EEE MMM d, yyyy").format(msgdata["time"].toDate())}"),
                                        decoration: BoxDecoration(
                                          color: Colors.lightBlue[100],
                                          borderRadius: BorderRadius.all(Radius.circular(10))
                                        ),
                                      )
                                    ],
                                  ) : SizedBox(),
                                  widget.chatIndex != 0 && widget.chatIndex - 1 == index && newMessage ? 
                                  Container(
                                    margin: EdgeInsets.fromLTRB(0, 5, 0, 5),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: <Widget>[
                                        Expanded(
                                          child: Divider(
                                            color: Colors.red,
                                          ),
                                        ),
                                        Text(
                                          "New messages",
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Colors.red,
                                          ),
                                        )
                                      ],
                                    ),
                                  ) : SizedBox(),
                                  // Message Widget
                                  GestureDetector(
                                    child: Container(
                                      color: selectedMessages.any((message) => message.containsValue(msgdoc.reference.path)) ? Colors.lightBlue[100] : Colors.transparent,
                                      child: Row(
                                        mainAxisAlignment: msgdata["sender_uid"] == widget.userUid ? MainAxisAlignment.end : MainAxisAlignment.start,
                                        children: <Widget>[
                                          Container(
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context).size.width / 1.5
                                            ),
                                            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                            margin: EdgeInsets.only(left: 10, right: 10, top: 2.5, bottom: 2.5),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                              color: msgdata["sender_uid"] == widget.userUid ? AppTheme().hexToColor("#e4d3e2") : AppTheme().hexToColor("#efefef"),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: msgdata["sender_uid"] == widget.userUid ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                              children: <Widget>[
                                                (msgdata["links"] ?? []).isNotEmpty ?
                                                Container(
                                                  margin: EdgeInsets.only(bottom: 10),
                                                  child: AnyLinkPreview(
                                                    urlLaunchMode: LaunchMode.externalApplication,
                                                    link: msgdata["links"][0],
                                                    displayDirection: UIDirection.uiDirectionHorizontal,
                                                    cache: Duration(hours: 1),
                                                    backgroundColor: Colors.white,
                                                    errorWidget: SizedBox(),
                                                    // errorImage: _errorImage,
                                                  ),
                                                ) : SizedBox(),
                                                ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  physics: NeverScrollableScrollPhysics(),
                                                  itemCount: (msgdata["files"] ?? []).length,
                                                  itemBuilder: (BuildContext context, int index) {
                                                    Map file = msgdata["files"][index];
                                                    if(file["mediatype"] == "image"){
                                                      return Container(
                                                        margin: EdgeInsets.only(bottom: 10),
                                                        child: GestureDetector(
                                                          onTap: (){
                                                            List<ImageProvider<Object>> images = msgdata["files"].where((element) => element["mediatype"] == "image").toList().map((e) => CachedNetworkImageProvider(e["fileurl"])).toList().cast<ImageProvider<Object>>();
                                                            print("$index ${images.length - 1}");
                                                            MultiImageProvider multiImageProvider = MultiImageProvider(images,initialIndex: index > (images.length - 1) ? 0 : index);
                                                            showImageViewerPager(context, multiImageProvider,
                                                            swipeDismissible: true, doubleTapZoomable: true);
                                                          },
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(12),
                                                            child: AspectRatio(
                                                              aspectRatio: 1,
                                                              child: CachedNetworkImage(
                                                                filterQuality: FilterQuality.medium,
                                                                imageUrl: file['fileurl'],
                                                                fit: BoxFit.cover,
                                                                placeholder: (BuildContext context, url) {
                                                                  return ShimmerLoading(height: double.minPositive, width: double.minPositive);
                                                                },
                                                                errorWidget: (context, url, error) => Center(
                                                                  child: Icon(Icons.error, color: Colors.grey,),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    else if(file["mediatype"] == "video"){
                                                      return Container(
                                                        margin: EdgeInsets.only(bottom: 10),
                                                        child: Column(
                                                          children: [
                                                            GestureDetector(
                                                              onTap: ()async{
                                                                Navigator.push(context, MaterialPageRoute(builder: (context) => Betterplayerscreen(
                                                                    fileurl: file['fileurl'], ratio: 9/16,
                                                                  )),
                                                                ).then((value) {
                                                                  print("router done");
                                                                });                        
                                                              },
                                                              child: AspectRatio(
                                                                aspectRatio: 1,
                                                                child: Stack(
                                                                  alignment: Alignment.center,
                                                                  children: [
                                                                    Container(
                                                                      child: ClipRRect(
                                                                        borderRadius: BorderRadius.circular(12),
                                                                        child: AspectRatio(
                                                                          aspectRatio: 1,
                                                                          child: file['filethumbnail'] == null ? Container(color: Colors.black,) :
                                                                          CachedNetworkImage(
                                                                            filterQuality: FilterQuality.medium,
                                                                            imageUrl: "${file['filethumbnail']}",
                                                                            fit: BoxFit.cover,
                                                                            placeholder: (BuildContext context, url) {
                                                                              return ShimmerLoading(height: double.minPositive, width: double.minPositive);
                                                                            },
                                                                            errorWidget: (context, url, error) => Center(
                                                                              child: Icon(Icons.error, color: Colors.grey,),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Center(
                                                                      child: Icon(Icons.play_circle, size: 55, color: Colors.white,),
                                                                    )
                                                                  ],
                                                                ),
                                                              ),
                                                            )
                                                          ],
                                                        )
                                                      );
                                                    }
                                                    else if(file["mediatype"] == "audio"){
                                                      return Container(
                                                        margin: EdgeInsets.only(bottom: 10),
                                                        padding: EdgeInsets.all(5),
                                                        decoration: BoxDecoration(
                                                          color: msgdata["sender_uid"] == widget.userUid ? AppTheme().hexToColor("#d1b6ce") : AppTheme().hexToColor("#cfcfcf"),
                                                          borderRadius: BorderRadius.all(Radius.circular(12)),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              offset: Offset(1, 1),
                                                              color: Color.fromARGB(255, 199, 199, 199),
                                                              blurRadius: 6,
                                                              spreadRadius: 0.5
                                                            )
                                                          ],
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            Container(
                                                              child: Row(
                                                                children: [
                                                                  IconButton(
                                                                    onPressed: () {
                                                                      if (currentlyPlayingUrl == file['fileurl']) {
                                                                        if (_audioPlayer.playing) {
                                                                          _audioPlayer.pause();
                                                                          print("paused");
                                                                        } else {
                                                                          playAudio([file]);
                                                                          print("playing");
                                                                        }
                                                                      } else {
                                                                        playAudio([file]);
                                                                        print("playing");
                                                                      }
                                                                    },
                                                                    icon: Icon(
                                                                      currentlyPlayingUrl == file['fileurl'] && _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                                                                      size: 40,
                                                                    ),
                                                                  ),
                                                                  Column(
                                                                    children: [
                                                                      SliderTheme(
                                                                        data: SliderThemeData(
                                                                          activeTrackColor: Colors.black,
                                                                          inactiveTrackColor: Colors.grey,
                                                                          thumbColor: Colors.black,
                                                                          overlayShape: SliderComponentShape.noOverlay,
                                                                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                                                                        ),
                                                                        child: Slider(
                                                                          value: sliderValue(currentlyPlayingUrl == file['fileurl'] ? (_audioPlayer.position.inSeconds.toDouble()) : 0, 0, currentlyPlayingUrl == file['fileurl'] ? (_audioPlayer.duration?.inSeconds.toDouble() ?? 0) : 0),
                                                                          min: 0.0,
                                                                          max: currentlyPlayingUrl == file['fileurl'] ? (_audioPlayer.duration?.inSeconds.toDouble() ?? 0) : 0,
                                                                          onChanged: (double value) async {
                                                                            setState(() {
                                                                              _audioPlayer.pause();
                                                                              _audioPlayer.seek(Duration(seconds: value.toInt())).then((_) {
                                                                                print("SEEK $value"); 
                                                                                if (currentlyPlayingUrl == file['fileurl']) {
                                                                                  _audioPlayer.play();
                                                                                }
                                                                              });
                                                                            });
                                                                          },
                                                                        ),
                                                                      ),
                                                                      SizedBox(height: 4,),
                                                                      Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                                        children: [
                                                                          if (currentlyPlayingUrl == file['fileurl']) 
                                                                            Text(
                                                                              '${_formatDuration(_audioPlayer.position)} ',
                                                                              style: TextStyle(
                                                                                fontSize: 10,
                                                                                color: Colors.grey,
                                                                              ),
                                                                            ),
                                                                          SizedBox(width: 90,),
                                                                          if (currentlyPlayingUrl == file['fileurl'])
                                                                            Text(
                                                                              '${_formatDuration(_audioPlayer.duration ?? Duration(seconds: 0))}',
                                                                              style: TextStyle(
                                                                                fontSize: 10,
                                                                                color: Colors.black,
                                                                              ),
                                                                            ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      );
                                                    }
                                                    else {
                                                      return Container(
                                                        margin: EdgeInsets.only(bottom: 10),
                                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                        decoration: BoxDecoration(
                                                          color: msgdata["sender_uid"] == widget.userUid ? AppTheme().hexToColor("#d1b6ce") : AppTheme().hexToColor("#cfcfcf"),
                                                          borderRadius: BorderRadius.all(Radius.circular(12)),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              offset: Offset(1, 1),
                                                              color: Color.fromARGB(255, 199, 199, 199),
                                                              blurRadius: 6,
                                                              spreadRadius: 0.5
                                                            )
                                                          ],
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.start,
                                                              children: [
                                                                Icon(Icons.file_present_outlined,size: 30,) ,
                                                                Expanded(
                                                                  child:Text(
                                                                    "${file['filename']}",
                                                                    maxLines: 2,
                                                                    style:TextStyle(
                                                                      fontSize: 12,
                                                                      fontWeight: FontWeight.w500,
                                                                    ),
                                                                  ),
                                                                ),
                                                                GestureDetector(
                                                                  child: Icon(Icons.download),
                                                                  onTap: ()async{
                                                                    print("touch");
                                                                    var url = file['fileurl'];
                                                                    downloadFile(url);
                                                                    showNotification("Download Started.");
                                                                    await downloadFilebyURL(url);
                                                                    showNotification("Download Completed");
                                                                  },
                                                                )
                                                              ],
                                                            ),
                                                          ],
                                                        )
                                                      );
                                                    }
                                                  },
                                                ),
                                                ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  physics: NeverScrollableScrollPhysics(),
                                                  itemCount: (appService.uploadProcessing[msgdata["messageid"]] ?? {}).values.length,
                                                  itemBuilder: (BuildContext context, int index){
                                                    dynamic progress = appService.uploadProcessing[msgdata["messageid"]]?.values.toList()[index] ?? 0;
                                                    return Text(
                                                      "Uploading 1 - ${(progress * 100).toStringAsFixed(1)}%",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey
                                                      ),
                                                    );
                                                  },
                                                ),
                                                msgdata['issueno'] != null ? RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: "Ticket No : ",
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 0.3
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:"${msgdata['issueno']}",
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontWeight: FontWeight.w500
                                                        ),
                                                      ),
                                                    ]
                                                  ),
                                                ) : SizedBox(),
                                                (msgdata["message"] ?? "").isNotEmpty ? SelectableLinkify(
                                                  text: "${msgdata["message"] ?? ""}",
                                                  // textScaleFactor: 4.0,
                                                  onOpen: (value)async{
                                                    print(value.url);
                                                    if (await canLaunchUrl(Uri.parse(value.url))) {
                                                      // await launchUrl(Uri.parse(url));
                                                      await launchUrl(Uri.parse(value.url), mode: LaunchMode.externalApplication);
                                                    }
                                                  },
                                                ) : SizedBox(),
                                                Row(
                                                  children: [
                                                    Text(
                                                      "${DateFormat("h:mm a").format(msgdata["time"].toDate())}",
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize:12
                                                      )
                                                    ),
                                                    if(msgdata['sender_uid'] == profileData['user_ref']?.id && msgdata['sender_uid'] != null)
                                                    Icon(Icons.check),
                                                    if(msgdata['sender_uid'] == profileData['user_ref']?.id && msgdata['read_by'] == 'user' && msgdata['read_by'] == 'user')
                                                    Icon(Icons.double_arrow),
                                                  ],
                                                )
                                              ],
                                            )
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        );
                      },
                    )
                  ),
                )
              ),
              // Preview Media
              selectedMedia.isEmpty ? SizedBox() : 
              Container(
                width: MediaQuery.of(context).size.width,
                margin: EdgeInsets.only(left:10, right: 10, bottom: 10),
                height: 60,
                decoration:BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[100],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedMedia.length,
                  itemBuilder: (BuildContext context, int index){
                    dynamic media = selectedMedia[index];
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration:BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey,
                          ),
                          margin: EdgeInsets.all(5),
                          child: Icon(
                            // TODO replace Icons to Preview
                            supportedImageFormat.contains(media["extension"]) ? Icons.image :
                            supportedVideoFormat.contains(media["extension"]) ? Icons.video_camera_back_sharp :
                            supportedAudioFormat.contains(media["extension"]) ? Icons.audio_file :
                            Icons.file_copy
                          ),
                        ),
                        Positioned(
                          top: -12,
                          right: -12,
                          child: IconButton(
                            icon: Icon(Icons.cancel, color: Colors.white,size: 20,),
                            onPressed: ()async{
                              setState(() {
                                selectedMedia.removeAt(index);
                              });
                            },
                          )
                        ),
                      ],
                    );
                  },
                ),
              ),
              issueData['status']?['status'].toString().toLowerCase() != 'resolved' || issueData['status']?['status'].toString().toLowerCase() != 'closed'  ? Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(10, 10, 15, 25),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconButton(
                      onPressed: ()async{
                        await importMediaToChat();
                      }, 
                      icon: Icon(Icons.add,size: 18,)
                    ),
                    Expanded(
                      child: Container(
                        child: TextFormField(
                          controller: message,
                          maxLines: 6,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(25.0)),
                            ),
                            hintText: "Message as ${widget.userName}",
                            contentPadding: EdgeInsets.fromLTRB(10, 15, 0, 0),
                          ),
                        )
                      ),
                    ),
                    SizedBox(width: 10,),
                    fileloading == true ? Container(
                      width:30,
                      height: 30,
                      child: SpinKitCubeGrid(
                        color: localTheme.hexToColor("#ED048D"),
                        size: 50.0,
                      )
                    ): IconButton(
                      icon: Icon(Icons.send),
                      padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                      constraints: BoxConstraints(),
                      onPressed: sendingSms ? null : () async {
                        if (message.text.isNotEmpty || selectedMedia.isNotEmpty) {
                          setState(() {
                            sendingSms = true;
                          });
                          submittoMessages(message.text);
                          WidgetsBinding.instance.addPostFrameCallback((_) => message.clear());
                        }
                      },
                    )
                  ],
                ),
              ) : Container(
                margin: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.yellow[200],
                  borderRadius: BorderRadius.all(Radius.circular(10))
                ),
                padding: EdgeInsets.all(10),
                alignment: Alignment.center,
                child: Text(
                  "The Conversation has been closed as the Ticked is Resolved",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.pink[900]
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String twoDigitHours = twoDigits(duration.inHours) == '00' ? '' : "${twoDigits(duration.inHours)}:";
    return "$twoDigitHours$twoDigitMinutes:$twoDigitSeconds";
  }
  
}

// ignore: must_be_immutable
class Betterplayerscreen extends StatefulWidget {
  String fileurl;
  double ratio;
  Betterplayerscreen({
    required this.fileurl,
    required this.ratio
  });
  @override
  _BetterplayerscreenState createState() => _BetterplayerscreenState();
}

class _BetterplayerscreenState extends State<Betterplayerscreen> {
  BetterPlayerController? betterPlayerController;
  @override
  void initState() {
    super.initState();
    Wakelock.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
     getContent();
  }

  @override
  void dispose(){
    super.dispose();
    Wakelock.disable();
  }

  getContent() {
    String url =widget.fileurl;
    print(url.contains("m3u8") ? "HLS" : url);
    BetterPlayerDataSource betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
    );
    betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        allowedScreenSleep: false,
        // autoPlay: true,
        aspectRatio:widget.ratio,
        fit: BoxFit.contain,
        fullScreenByDefault: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(),
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
        eventListener: (event) {
          print("EVent ${event.betterPlayerEventType}");
          if (event.betterPlayerEventType.name == "hideFullscreen" || event.betterPlayerEventType.name == "finished") {
            Navigator.pop(context);
          }
          // ("Better player event ${event.betterPlayerEventType.name}");
        },
      ),
      betterPlayerDataSource: betterPlayerDataSource
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(
          color: Colors.white
        ),
      ),
      body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
          AspectRatio(
            aspectRatio: widget.ratio,
            child: betterPlayerController != null ? BetterPlayer(controller: betterPlayerController!) : CircularProgressIndicator(),
          )
        ],
      ),
    );
  }
}