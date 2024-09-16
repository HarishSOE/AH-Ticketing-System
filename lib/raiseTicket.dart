import 'dart:async';
import 'dart:io';

import 'package:ahticketing/TicketChat.dart';
import 'package:ahticketing/databasehelper.dart';
import 'package:ahticketing/AppServices/AppService.dart';
import 'package:ahticketing/Themes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ignore: must_be_immutable
class RaiseTicket extends StatefulWidget {
  Map category = {};
  String? subcategory = '';
  List message = [];
  String profileId = '';
  String userId = '';
  Map profileData = {};
  RaiseTicket({Key? key, required this.category, required this.subcategory, required this.message, required profileId, required userId, required profileData}): super(key: key);

  @override
  State<RaiseTicket> createState() => _RaiseTicket();
}

class _RaiseTicket extends State<RaiseTicket> {

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  AppService appService = AppService();
  AppTheme localTheme = AppTheme();
  int ticketnumber = 0;

  TextEditingController message = TextEditingController();

  bool loading = true;
  bool success = false;

  String profileId = '';
  late DocumentReference currentjourney;

  late Database chatDB;

  Map mapprofiledata = {};

  List selectedMedia = [];
  List<String> supportedImageFormat = ["jpg", "jpeg", "png"];
  List<String> supportedVideoFormat = ["mp4", "mov", "3gp"];
  List<String> supportedDocFormat = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'xls', 'xlsx', 'ppt', 'pptx', 'csv', 'html', 'htm', 'xml', 'epub', 'md', 'json', 'latex'];
  List<String> supportedAudioFormat = ['mp3', 'wav', 'aac', 'flac', 'ogg', 'wma', 'aiff', 'm4a', 'amr', 'mid', 'midi', 'ac3', 'opus', 'mka','octet-stream'];
  
  @override
  void initState() {
    super.initState();
    
    appService.initChatSQLite().then((db) {
      chatDB = db;
      db.query("chatmedia",).then((value) {});
    });

    setState(() {
      profileId = widget.profileId;
    });

    firestore.collection("profile_data").where("user_ref", isNull: false).get().then((profile) {
      for (var element in profile.docs) {
        Map<String, dynamic> data = element.data();
        mapprofiledata[data['profileid']] = data;
      }
      if(mounted) setState(() {});
    });

    firestore.collection("participantjourneyproduct").where("profileid",isEqualTo: profileId).get().then((pjpDocs) {
      if(pjpDocs.docs.length != 0){
        setState(() {
          currentjourney = pjpDocs.docs.first.data()['journeyref'];
        });
      }else{
        print("No Current Journey Found :(");
      }
    });

    firestore.collection("clientissue").orderBy("reporteddate",descending: true).limit(1).get().then((ciDocs) {
      if(ciDocs.docs.length != 0){
        setState(() {
          ticketnumber = ciDocs.docs.first.data()['issueno'] + 1;
          loading = false;
        });
      }else{
        setState(() {
          ticketnumber = 1001;
          loading = false;
        });
        print("client Issue Not found");
      }
    });

  }

  submitTicket()async{

    setState(() {
      success = true;
    });

    List<String> utubeURL = [];
    RegExp linkPattern = RegExp(r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+');
    Iterable<RegExpMatch> matches = linkPattern.allMatches(message.text);
    for (var match in matches) {
      RegExp youtubePattern = RegExp(r'^((?:https?:)?\/\/)?((?:www|m)\.)?((?:youtube(-nocookie)?\.com|youtu.be))(\/(?:[\w\-]+\?v=|embed\/|v\/)?)([\w\-]+)(\S+)?$');
      if(youtubePattern.hasMatch(message.text.substring(match.start, match.end))){
        utubeURL.add(message.text.substring(match.start, match.end));
      }
    }

    DocumentReference issueRef = firestore.collection("clientissue").doc();
    DocumentReference firstMessageRef = issueRef.collection("messages").doc();
    DocumentReference messageRef = issueRef.collection("messages").doc();

    await storeChatMedia(issueRef.path);
    await storeChatMedia(firstMessageRef.path);
    setState(() {
      selectedMedia.clear();
    });
    
    Map<String,dynamic> issueData = {
      "id" : issueRef.id,
      "issueno" : ticketnumber,
      "clientid" : profileId,
      "reporteddate" : DateTime.now(),
      "product" : '',
      "journey" : currentjourney,
      "assign" : widget.category['assignto'],
      "issueReportedBy" : profileId,
      "reportedBy" : profileId,
      "status" : {
        "date" : DateTime.now(),
        "editedBy" : null,
        "status" : 'Action yet to be taken'
      },
      "issue" : message.text,
      "category" : widget.category['category'],
      "subcategory" : widget.subcategory,
      "email" : widget.profileData['email'],
      "issueimages" : [],
      "mobile" : widget.profileData['number'],
      "name" : widget.profileData['name'],
    };

    Map<String,dynamic> firstMessageData = {
      "time": DateTime.now(),
      "sender_uid": null,
      "sender_profileid": profileId,
      "sender_email": null,
      "issueno" : ticketnumber,
      "message": message.text,
      "messageid": firstMessageRef.id,
      "read_by": ["user","admin"],
      "pending": [],
      "links": utubeURL.isEmpty ? null : utubeURL,
      "files" : [],
    };

    Map<String,dynamic> messageData = {
      "time": DateTime.now(),
      "sender_uid": null,
      "sender_profileid": profileId,
      "sender_email": null,
      "message": widget.message[0]['message'],
      "messageid": messageRef.id,
      "read_by": ["user","admin"],
      "pending": [],
      "links": utubeURL.isEmpty ? null : utubeURL,
      "files" : [],
    };

    await issueRef.set(issueData).then((_)async{
      print("Ticket Created Successfully");
      await firstMessageRef.set(firstMessageData);
      for (var assigned in issueData['assign']) {
        await createNotification(issueData,assigned);
      }
      Timer(Duration(seconds: 2), () {
        messageRef.set(messageData);
        successwidget(issueData,issueRef,messageData,messageRef);
      });
    }).catchError((error){
      print("${error},Error");
    });
  }
  
  successwidget(issueData,issueRef,messageData,messageRef){
    setState(() {
      success = false;
      loading = true;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (BuildContext context) {
          return TicketChat(
            chatIndex : 0,
            issueid : issueData['id'],
            userUid : widget.userId,
            userName : widget.profileData['name'],
            userEmail : widget.profileData['email'],
            userProfileID : profileId,
            messageRef : firestore.collection("clientissue").doc(issueData['id']).collection("messages"),
            issueref : issueRef,
          );
        })
      );
    });
  }

  createNotification(issueData,receiverId)async{

    var sendTo = '';
    await firestore.collection("profile_data").doc(receiverId).get().then((value) {
      setState(() {
        sendTo = value.data()?['user_ref'].id; 
      });
    });

    var docId = firestore.collection("notifications").doc().id;
    issueData['date'] = DateTime.now();
    issueData['message'] = 'New Ticket is Generated';
    issueData['read'] = false;
    issueData['type'] = "inappmessage";
    await firestore.collection('notifications').doc(sendTo).collection('logs').doc(docId).set(issueData).then((_){
      print('Notofication Log has been created');
    }).catchError((error){
      print("${error}, Error while adding Notification");
    });

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
          "senderprofileid": profileId,
          "uploaded": 0
        }).then((value) {
          print("Stored DB $value");
        }).catchError((err){
          print("Error DB $err");
          appService.logException(exception: "$err", stack: "");
        });
      }
      appService.uploadMedia(chatDB, "chatmedia", "messagepath", callBack: (){
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: success ? AppBar(automaticallyImplyLeading: false,) : AppBar(
        title: Text(
          "Ticket No : ${ticketnumber}",
          style: GoogleFonts.poppins(
            fontSize:16,
            fontWeight:FontWeight.w500
          ),
        ),
        actions: [
          IconButton(
            onPressed: (){
              _pickFiles(FileType.media); //, allowedExtensions: [...supportedImageFormat, ...supportedVideoFormat]
            },
            icon: Icon(Icons.attach_file)
          )
        ],
      ),
      body: success ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Spacer(),
            Icon(Icons.check_circle_sharp,size: 150,color: Colors.green,),
            SizedBox(
              height: 30,
            ),
            Text(
              "Ticket Generated",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20
              ),
            ),
            Spacer(),
          ],
        ),
      ) : loading ? Center(
        child: SpinKitCubeGrid(
          color: localTheme.hexToColor("#ED048D"),
          size: 50.0,
        )
      ) : SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextFormField(
                keyboardType: TextInputType.multiline,
                minLines: 12,
                maxLines: 18,
                onChanged: (value) {
                  setState(() {
                    message.text = value;
                  });
                },
                style: GoogleFonts.poppins(

                ),
                decoration: InputDecoration(
                  hintText: 'Describe your Query',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                ),
              ),
              SizedBox(height: 10),
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
                              supportedImageFormat.contains(media["extension"]) ? Icons.image :
                              supportedVideoFormat.contains(media["extension"]) ? Icons.video_camera_back_sharp :
                              supportedAudioFormat.contains(media["extension"]) ? Icons.audio_file :
                              Icons.file_copy
                            ),
                            
                            // child: supportedImageFormat.contains(media["extension"]) ? Container(
                            //   child: Image.network(media['file']),
                            // ) : SizedBox(),
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
              Container(
                width: MediaQuery.of(context).size.width,
                child: ElevatedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: localTheme.hexToColor("#f90497"),
                    padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                    side: BorderSide(color: localTheme.hexToColor("#ED048D"),),
                  ),
                  onPressed: (){
                    if(message.text != ''){
                      submitTicket();
                    }
                  }, child: Text(
                    "Submit Ticket",
                    style: GoogleFonts.poppins(
                      fontWeight:FontWeight.bold,
                      fontSize:14,
                      color:Colors.white
                    ),
                  )
                ),
              ),
            ],
          )
        ),
      )
    );
  }
}