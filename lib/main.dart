import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ahticketing/AppServices/AppService.dart';
import 'package:ahticketing/AppServices/UserData.dart';
import 'package:ahticketing/Themes.dart';
import 'package:ahticketing/chatQuery.dart';
import 'package:ahticketing/firebase_options.dart';
import 'package:ahticketing/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';


Future <void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A & H Ticketing',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  AppService appService = AppService();
  AppTheme localTheme = AppTheme();
  GlobalKey<ScaffoldState> key = GlobalKey();
  late FirebaseMessaging firebaseMessaging;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  StreamSubscription<DocumentSnapshot>? userListener;
  StreamSubscription? participantDashboardListener;
  final PageStorageBucket bucket = PageStorageBucket();
  String? tokenFCM;
  bool chatXAdmin = false;
  bool eisChangeagent = false;
  Map<String, dynamic>? userRoles = {};
  Map<String, String> userPreferences = {};
  int screenIndex = 0;
  StreamSubscription? tokenSubscription;
  StreamSubscription? queueSubscription;
  StreamSubscription? queueMessageSubscription;
  StreamSubscription? studioInvitationSubscription;
  StreamSubscription? studioSubscription;
  StreamSubscription? deliverySubscription;
  StreamSubscription? bigInvitationSubscription;
  late Database videoaskDB;

  StreamSubscription? lastWatchedSubscription;

  @override
  void initState() {
    super.initState();

    UserData().getUserData().then((value)async {
      userPreferences = value;
    });
    Future.delayed(Duration(seconds: 0), (){
      if(auth.currentUser == null){
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (BuildContext context) => Login()
        ));
      }
      else{
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (BuildContext context) => ChatQueryAdmin()
        ));
      }
    });
  }

  userDataListener() async {
    firestore.collection("notifications").doc(userPreferences['uid']).snapshots().listen((event) {
      if (event.exists) {
        appService.notificationAvailable = !(event.data()?["read"] ?? true);
        if (mounted) setState(() {});
      }
    });

    participantDashboardListener = firestore.collection("participantdashboard").doc(userPreferences['pid']).snapshots().listen((profileData) {
      if(profileData.exists){
        appService.participantDashboard = profileData.data() ?? {};
      }
    });
    userListener = firestore.collection("profile_data").doc(userPreferences['pid']).snapshots().listen((profileData) {
      print("Profile Listener: ${profileData.id}");
      Map<String, dynamic> profile = profileData.data() ?? {};
      if (appService.loggedinProfile["profileid"] == null) {

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('A new onMessage event was published! ${message.data}');
          RemoteNotification? notification = message.notification;
          print(notification?.title);
          print(notification?.body);

          // AndroidNotification? android = message.notification?.android;
          if (notification != null) {
            onMessageNotification(
              notificationIndex: 0,
              title: notification.title ?? "",
              body: notification.body ?? "",
              payload: json.encode(message.data)
            );
          }
        });
      }
     
      firestore.doc(profile['role_ref'].path).snapshots().listen((roleData) {
        if (mounted) {
          setState(() {
            userRoles = roleData.data();
            appService.loggedinRoles = userRoles ?? {};
            chatXAdmin = (userRoles?['chatxadmin']) ?? false;
            eisChangeagent = (userRoles?['eis'] ?? false) ||
              (userRoles?['changeagent'] ?? false);
          });
        }
          firestore.collectionGroup("messages").where("pending", arrayContains: "admin").limit(1).snapshots().listen((messages) {
            if (mounted) {
              setState(() {
                appService.newMessage = messages.docs.isNotEmpty;
              });
            }
            firestore.collection("notifications").doc(userPreferences['uid']).set({
              "name": appService.loggedinProfile["name"],
            }, SetOptions(merge: true));
          });
        // }
      });
    });
  }

  onMessageNotification(
    {required int notificationIndex,
    required String title,
    required String body,
    required String payload}
  )
  {
    var android = AndroidNotificationDetails(
    "channelId", "channelName",
    channelDescription: "channelDescription"
    );
    var ios = DarwinNotificationDetails();
    var platform = NotificationDetails(android: android, iOS: ios);
    flutterLocalNotificationsPlugin.show(notificationIndex, "$title", "$body", platform, payload: payload).then((onValue) {
      print("Success");
    }).catchError((onError) {
      print("Notification Error:  $onError");
      appService.logException(exception: "$onError", stack: "");
    }).catchError((err) {
      print(err);
      appService.logException(exception: "$err", stack: "");
    });
  }

  inAppMessage(String profileid) {
    firestore.collection("participant messages").get().then((value) {
      print("IN APP B");
      print(value.size);
      value.docs.forEach((element) async {
        var data = element.data();
        var profileid = data["profileid"];
        var uid = ((await firestore.collection("profile_data").doc(profileid).get()).data() ??{})["user_ref"];
        print("$profileid, ${uid?.id}");
        if (uid != null) {
          firestore.collection("notifications").doc(uid.id).collection("logs").add({
            "date": data["date"].toDate(),
            "type": "inappmessage",
            "message": data["description"],
            "read": true,
          });
        }
      });
    });
    firestore.collection("participant messages").where("profileid", isEqualTo: profileid).where("read", isEqualTo: false).orderBy("date", descending: true).limit(1).snapshots().listen((doc) async {
      if (doc.docs.isNotEmpty) {
        Map<String, dynamic> messageData = doc.docs.first.data();
        print(messageData);
        displayMessage(messageData);
      }
    });
  }

  displayMessage(messageData) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String title = messageData["title"] ?? "Alert!";
        String subtitle = messageData["subtitle"] ?? "";
        String description = messageData["description"] ?? "";
        return WillPopScope(
          onWillPop: () async {
            return false;
          },
          child: AlertDialog(
            elevation: 8,
            titlePadding: EdgeInsets.zero,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          IconButton(
                            // constraints: BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () {},
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.transparent,
                            )
                          ),
                          Expanded(
                            child: Center(
                              child: Text("$title",textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  color: Colors.orange.shade900,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            )
                          ),
                          IconButton(
                            constraints: BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.pop(context);
                              firestore.collection("participant messages").doc(messageData["id"]).update({"read": true});
                            },
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                            )
                          )
                        ],
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Container(
                        margin: EdgeInsets.fromLTRB(5, 0, 5, 5),
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade500,
                              Colors.green.shade300
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Text(
                                "$subtitle",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                height: 30,
                              ),
                              Text(
                                "$description",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        );
      }
    );
  }

  // Init Local DB
  syncLocalDB(){
    // Chat Media
    appService.initChatSQLite().then((db) {
      print("Init DB $db");
      appService.uploadMedia(db, "chatmedia", "messagepath", callBack: (){
        ("Chat Upload Progress ${appService.uploadProcessing}");
      });
    });
  }

  launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      // await launchUrl(Uri.parse(url));
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          String title = "Something Wrong";
          String message = "Could not able to launch $url";
          return Platform.isIOS ? CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
              actions: <Widget>[
                CupertinoDialogAction(
                  child: Text("OK"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
          )
          : AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                child: Text("OK"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (screenIndex > 1) {
      setState(() {
        screenIndex = screenIndex - 1;
      });
      return false;
    } else {
      return await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
          title: Text('Are you sure?'),
          content: Text('Do you want to exit an App'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => exit(0),
              child: Text('Yes'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    userListener?.cancel();
    participantDashboardListener?.cancel();
    tokenSubscription?.cancel();
    queueSubscription?.cancel();
    queueMessageSubscription?.cancel();
    studioInvitationSubscription?.cancel();
    deliverySubscription?.cancel();
    bigInvitationSubscription?.cancel();
    studioSubscription?.cancel();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SpinKitCubeGrid(
          color: localTheme.hexToColor("#ED048D"),
          size: 50.0,
        )
      ),
    );
  }
}
