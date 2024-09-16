// // ignore_for_file: unused_local_variable, duplicate_ignore, unnecessary_import, use_super_parameters, prefer_const_constructors_in_immutables, avoid_print, prefer_const_constructors, deprecated_member_use, unnecessary_string_interpolations, avoid_function_literals_in_foreach_calls, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures, use_build_context_synchronously

// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:ahticketing/AppServices/UserData.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
// import 'package:ahticketing/AppServices/AppService.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:sqflite/sqflite.dart';

// class Home extends StatefulWidget {
//   final Widget? router;
//   Home({
//     Key? key,
//     this.router
//   }) : super(key: key);

//   @override
//   State<StatefulWidget> createState() {
//     return _HomeState();
//   }
// }

// class _HomeState extends State<Home> with TickerProviderStateMixin {
//   AppService appService = AppService();
//   GlobalKey<ScaffoldState> key = GlobalKey();
//   final FirebaseAuth auth = FirebaseAuth.instance;
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   late FirebaseMessaging firebaseMessaging;
//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
//   StreamSubscription<DocumentSnapshot>? userListener;
//   StreamSubscription? participantDashboardListener;
//   final PageStorageBucket bucket = PageStorageBucket();
//   String? tokenFCM;
//   bool chatXAdmin = false;
//   bool eisChangeagent = false;
//   Map<String, dynamic>? userRoles = {};
//   Map<String, String> userPreferences = {};
//   int screenIndex = 0;
//   StreamSubscription? tokenSubscription;
//   StreamSubscription? queueSubscription;
//   StreamSubscription? queueMessageSubscription;
//   StreamSubscription? studioInvitationSubscription;
//   StreamSubscription? studioSubscription;
//   StreamSubscription? deliverySubscription;
//   StreamSubscription? bigInvitationSubscription;
//   late Database videoaskDB;

//   StreamSubscription? lastWatchedSubscription;

//   userDataListener() async {
//     firestore.collection("notifications").doc(userPreferences['uid']).snapshots().listen((event) {
//       if (event.exists) {
//         appService.notificationAvailable = !(event.data()?["read"] ?? true);
//         if (mounted) setState(() {});
//       }
//     });

//     bool syncStarted = false;
//     participantDashboardListener = firestore.collection("participantdashboard").doc(userPreferences['pid']).snapshots().listen((profileData) {
//       if(profileData.exists){
//         appService.participantDashboard = profileData.data() ?? {};
//       }
//     });
//     userListener = firestore.collection("profile_data").doc(userPreferences['pid']).snapshots().listen((profileData) {
//       print("Profile Listener: ${profileData.id}");
//       Map<String, dynamic> profile = profileData.data() ?? {};
//       if (appService.loggedinProfile["profileid"] == null) {

//         FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//           print('A new onMessage event was published! ${message.data}');
//           RemoteNotification? notification = message.notification;
//           print(notification?.title);
//           print(notification?.body);

//           // AndroidNotification? android = message.notification?.android;
//           if (notification != null) {
//             onMessageNotification(
//               notificationIndex: 0,
//               title: notification.title ?? "",
//               body: notification.body ?? "",
//               payload: json.encode(message.data)
//             );
//           }
//         });
//       }
     
//       firestore.doc(profile['role_ref'].path).snapshots().listen((roleData) {
//         if (mounted) {
//           setState(() {
//             userRoles = roleData.data();
//             appService.loggedinRoles = userRoles ?? {};
//             chatXAdmin = (userRoles?['chatxadmin']) ?? false;
//             eisChangeagent = (userRoles?['eis'] ?? false) ||
//               (userRoles?['changeagent'] ?? false);
//           });
//         }
//           firestore.collectionGroup("messages").where("pending", arrayContains: "user").limit(1).snapshots().listen((messages) {
//             if (mounted) {
//               setState(() {
//                 appService.newMessage = messages.docs.isNotEmpty;
//               });
//             }
//             firestore.collection("notifications").doc(userPreferences['uid']).set({
//               "name": appService.loggedinProfile["name"],
//             }, SetOptions(merge: true));
//           });
//         // }
//       });
//     });
//   }

//   fetchParticipantJourney(Source source) async {
//     List<String> statusList = ["ongoing", "initiated", "completed"];
//     // Active Journey Data
//     try {
//       await firestore.collection("participantjourneyproduct").where("profileid", isEqualTo: userPreferences['pid']).where("journeystatus", whereIn: statusList).where("journeyref", isNotEqualTo: null).get(GetOptions(source: source)).then((journey) async {
//         List<Map<String, dynamic>> journeyList =
//         journey.docs.map((e) => e.data()).toList();
//         journeyList.sort((a, b) => (a["subscriptionstart"]?.toDate()).compareTo(b["subscriptionstart"]?.toDate()));
//         for (int i = 0; i < statusList.length; i++) {
//           Map<String, dynamic> activeJourney = journeyList.lastWhere(
//             (element) => element["journeystatus"] == statusList[i],
//             orElse: () => {}
//           );
//           if (activeJourney.isNotEmpty) {
//             appService.profileJourneyProduct["journeyid"] = activeJourney["journeyref"].id;
//             appService.profileJourneyProduct["subscriptionstart"] = activeJourney["subscriptionstart"]?.toDate();
//             appService.profileJourneyProduct["subscriptionend"] = activeJourney["subscriptionend"]?.toDate();
//             await firestore.doc(activeJourney["journeyref"].path).get(GetOptions(source: source)).then((journeydoc) {
//               Map<String, dynamic> rawJourneyData = journeydoc.data() ?? {};
//               appService.profileJourneyProduct["activejourneyname"] = rawJourneyData["journey"];
//               appService.profileJourneyProduct["activejourneydescription"] = rawJourneyData["description"];
//               appService.profileJourneyProduct["activejourneyimmersive"] = rawJourneyData["immersive"];
//               appService.profileJourneyProduct["activejourneylearning"] = rawJourneyData["learning"];
//               if(mounted) setState(() {});
//             }).catchError((err) {
//               print(err);
//               appService.logException(exception: "$err", stack: "");
//             });
//             break;
//           }
//         }
//       }).catchError((err) {
//         print(err);
//         appService.logException(exception: "$err", stack: "");
//       });
//     } catch (exception) {
//       print("Exception: $exception");
//     }
//   }

//   fetchParticipantProducts(Source source) async {
//     List<String> statusList = ["ongoing", "initiated", "completed"];
//     // Active Product Data - Priority/Big/Event Mode
//     try {
//       firestore.collection("participantsproduct").where("profileid", isEqualTo: userPreferences['pid']).orderBy("sequenceorder").snapshots().listen((participantProduct) async {
//         appService.participantProductList = participantProduct.docs.map((e) => e.data()).toList();
//         List<Map<String, dynamic>> profileProducts = appService.participantProductList.where((element) => statusList.contains(element["status"])).toList();
//         if (profileProducts.isNotEmpty) {
//           List<Map<String, dynamic>> productList = profileProducts;
//           // Store Product Origin Data
//           Map<String, dynamic> productRawData = {};
//           List<String> productid = productList.map((e) => "${e["productref"].id}").toList().cast<String>().toSet().toList();
//           print(productid);
//           for (int i = 0; i < productid.length; i += 10) {
//             List sublist = productid.getRange(i, (i + 10) > productid.length ? productid.length : i + 10).toList();
//             await firestore.collection("products").where("id", whereIn: sublist).get(GetOptions(source: source)).then((productOriginal) {
//               for (int a = 0; a < productOriginal.size; a++) {
//                 QueryDocumentSnapshot<Map<String, dynamic>> productRaw = productOriginal.docs[a];
//                 productRawData[productRaw.id] = productRaw.data();
//               }
//             }).catchError((err) {
//               print(err);
//               appService.logException(exception: "$err", stack: "");
//             });
//           }
//           // Find Mode Product
//           if (appService.loggedinProfile["participantmode"] == null) {
//             appService.profileJourneyProduct["activeproductmode"] = "Exploration Mode";
//           } else if (appService.loggedinProfile["participantmode"] == "Big Mode") {
//             Map<String, dynamic> bigProduct = productList.firstWhere(
//               (element) => productRawData[element["productref"].id]["mode"] == "Big Mode",
//               orElse: () => {}
//             );
//             if (bigProduct.isNotEmpty) {
//               appService.profileJourneyProduct["bigproductid"] = (productRawData[bigProduct["productref"].id] ?? {})["id"];
//               appService.profileJourneyProduct["bigproductname"] = (productRawData[bigProduct["productref"].id] ?? {})["product"];
//               appService.profileJourneyProduct["bigproductmode"] = "Big Mode";
//               appService.profileJourneyProduct["bigparticipantproductid"] = bigProduct["docid"];
//               if(mounted) setState(() {});
//             }
//             Map<String, dynamic> primaryProduct = productList.firstWhere(
//               (element) => element["docid"] != appService.profileJourneyProduct["bigparticipantproductid"] &&
//               (element["mode"] == "Event Mode" || element["mode"] == "Installation Event Mode"),
//               orElse: () => {}
//             );
//             if (primaryProduct.isNotEmpty) {
//               appService.profileJourneyProduct["activeproductid"] = (productRawData[primaryProduct["productref"].id] ?? {})["id"];
//               appService.profileJourneyProduct["activeproductname"] = (productRawData[primaryProduct["productref"].id] ?? {})["product"];
//               appService.profileJourneyProduct["activeproductmode"] = primaryProduct["mode"];
//               appService.profileJourneyProduct["activeparticipantproductid"] = primaryProduct["docid"];
//               appService.profileJourneyProduct["activeparticipantproduct"] = primaryProduct;
//               if(mounted) setState(() {});
//             } else {
//               appService.profileJourneyProduct["activeproductid"] = (productRawData[bigProduct["productref"].id] ?? {})["id"];
//               appService.profileJourneyProduct["activeproductname"] = (productRawData[bigProduct["productref"].id] ?? {})["product"];
//               appService.profileJourneyProduct["activeproductmode"] = "Big Mode";
//               appService.profileJourneyProduct["activeparticipantproductid"] = bigProduct["docid"];
//               appService.profileJourneyProduct["activeparticipantproduct"] = bigProduct;
//               if(mounted) setState(() {});
//             }
//           } else {
//             appService.profileJourneyProduct["activeproductmode"] = appService.loggedinProfile["participantmode"];
//             Map<String, dynamic> primaryProduct = productList.firstWhere(
//               (element) => element["mode"] == appService.loggedinProfile["participantmode"],
//               orElse: () => {}
//             );
//             print("$primaryProduct ${appService.loggedinProfile["participantmode"]}");
//             if (primaryProduct.isNotEmpty) {
//               appService.profileJourneyProduct["activeproductid"] = primaryProduct["productref"].id;
//               appService.profileJourneyProduct["activeproductname"] = productRawData[primaryProduct["productref"].id]["product"];
//               appService.profileJourneyProduct["activeproductmode"] = primaryProduct["mode"];
//               appService.profileJourneyProduct["activeparticipantproductid"] = primaryProduct["docid"];
//               appService.profileJourneyProduct["activeparticipantproduct"] = primaryProduct;
//               if(mounted) setState(() {});
//             }
//           }
//           // Fetch Delivery Sequence
//           if (appService.profileJourneyProduct["activeproductmode"] != null) {
//             deliverySubscription = firestore.collection("participantdeliverysequence").doc(userPreferences["pid"]).snapshots().listen((deliverySequence) {
//               print("Delivery Sequence updated....");
//               if (deliverySequence.exists) {
//                 List<Map<String, dynamic>> deliveryProduct = List<Map<String, dynamic>>.from((deliverySequence.data() ?? {})["products"] ?? []);
//                 // Active Product
//                 print(appService.profileJourneyProduct);
//                 Map<String, dynamic> activeProduct = deliveryProduct.firstWhere(
//                   (element) => element["participantproductid"] == appService.profileJourneyProduct["activeparticipantproductid"],
//                   orElse: () => {}
//                 );
//                 print("Active Product $activeProduct");
//                 appService.profileJourneyProduct["activeproductdelivery"] =(activeProduct["delivery"] ?? []).isEmpty ? null : activeProduct["delivery"];
//                 if(mounted) setState(() {});
//                 if (appService.profileJourneyProduct["activeproductdelivery"] != null) {
//                   // queueMode(Source.cache);
//                   // eventMode(Source.cache);
//                   // queueMode(Source.serverAndCache);
//                   // eventMode(Source.serverAndCache);
//                 }
//               }
//             });
//           }
//         } else {
//           appService.profileJourneyProduct["activeproductmode"] = appService.loggedinProfile["participantmode"] ?? "Exploration Mode";
//           appService.profileJourneyProduct["journeybanner"] = appService.profileJourneyProduct["activejourneydescription"];
//           if(mounted) setState(() {});
//         }
//       });
//     } catch (exception) {
//       print("Exception Products $exception");
//     }
//   }

//   displayMessage(messageData) {
//     return showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         String title = messageData["title"] ?? "Alert!";
//         String subtitle = messageData["subtitle"] ?? "";
//         String description = messageData["description"] ?? "";
//         return WillPopScope(
//           onWillPop: () async {
//             return false;
//           },
//           child: AlertDialog(
//             elevation: 8,
//             titlePadding: EdgeInsets.zero,
//             title: Column(
//               mainAxisSize: MainAxisSize.min,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   width: MediaQuery.of(context).size.width,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(8.0),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.2),
//                         spreadRadius: 2,
//                         blurRadius: 4,
//                         offset: Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       SizedBox(
//                         height: 10,
//                       ),
//                       Row(
//                         children: [
//                           IconButton(
//                             // constraints: BoxConstraints(),
//                             padding: EdgeInsets.zero,
//                             onPressed: () {},
//                             icon: Icon(
//                               Icons.close,
//                               size: 18,
//                               color: Colors.transparent,
//                             )
//                           ),
//                           Expanded(
//                             child: Center(
//                               child: Text("$title",textAlign: TextAlign.center,
//                                 style: GoogleFonts.montserrat(
//                                   color: Colors.orange.shade900,
//                                   fontSize: 19,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               )
//                             )
//                           ),
//                           IconButton(
//                             constraints: BoxConstraints(),
//                             padding: EdgeInsets.zero,
//                             onPressed: () {
//                               Navigator.pop(context);
//                               firestore.collection("participant messages").doc(messageData["id"]).update({"read": true});
//                             },
//                             icon: const Icon(
//                               Icons.close,
//                               size: 18,
//                             )
//                           )
//                         ],
//                       ),
//                       SizedBox(
//                         height: 10,
//                       ),
//                       Container(
//                         margin: EdgeInsets.fromLTRB(5, 0, 5, 5),
//                         width: MediaQuery.of(context).size.width,
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               Colors.green.shade500,
//                               Colors.green.shade300
//                             ],
//                           ),
//                           borderRadius: BorderRadius.circular(8.0),
//                         ),
//                         child: Padding(
//                           padding: EdgeInsets.all(20.0),
//                           child: Column(
//                             children: [
//                               Text(
//                                 "$subtitle",
//                                 textAlign: TextAlign.center,
//                                 style: GoogleFonts.montserrat(
//                                   color: Colors.white,
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               SizedBox(
//                                 height: 30,
//                               ),
//                               Text(
//                                 "$description",
//                                 textAlign: TextAlign.center,
//                                 style: GoogleFonts.montserrat(
//                                   color: Colors.white,
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         )
//                       )
//                     ],
//                   ),
//                 )
//               ],
//             ),
//           )
//         );
//       }
//     );
//   }

//   inAppMessage(String profileid) {
//     firestore.collection("participant messages").get().then((value) {
//       print("IN APP B");
//       print(value.size);
//       value.docs.forEach((element) async {
//         var data = element.data();
//         var profileid = data["profileid"];
//         var uid = ((await firestore.collection("profile_data").doc(profileid).get()).data() ??{})["user_ref"];
//         print("$profileid, ${uid?.id}");
//         if (uid != null) {
//           firestore.collection("notifications").doc(uid.id).collection("logs").add({
//             "date": data["date"].toDate(),
//             "type": "inappmessage",
//             "message": data["description"],
//             "read": true,
//           });
//         }
//       });
//     });
//     firestore.collection("participant messages").where("profileid", isEqualTo: profileid).where("read", isEqualTo: false).orderBy("date", descending: true).limit(1).snapshots().listen((doc) async {
//       if (doc.docs.isNotEmpty) {
//         Map<String, dynamic> messageData = doc.docs.first.data();
//         print(messageData);
//         displayMessage(messageData);
//       }
//     });
//   }

//   @override
//   void initState() {
//     super.initState();
//     UserData().getUserData().then((value) {
//       userPreferences = value;
//       print(userPreferences);
//       userDataListener();
//       // queueListener();
//       try {
//         inAppMessage(userPreferences["pid"] ?? "");
//       } catch (e) {
//         print("Version Error : $e");
//       }

//       firebaseMessaging = FirebaseMessaging.instance;
//       firebaseMessaging.getToken().then((String? token) async {
//         assert(token != null);
//         tokenFCM = token;
//         appService.loggedinProfile["fcmtoken"] = token;
//         print("Push Messaging token: $token");
//         appService.updateFCMToken(userPreferences['email']!, token!, userPreferences['uid']!, userPreferences['pid']!, true);
//       }).catchError((err) {
//         print("unable to fetch FCM");
//         print(err);
//         appService.logException(exception: "$err", stack: "");
//       });

//       firebaseMessaging.subscribeToTopic('ahmember').catchError((err) {
//         print("Topic Error");
//         print(err);
//       });

//       flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//       var android = AndroidInitializationSettings('@drawable/ic_lyl');
//       var ios = DarwinInitializationSettings();
//       var initsetting = InitializationSettings(android: android, iOS: ios);
//       flutterLocalNotificationsPlugin.initialize(
//         initsetting,
//         // onSelectNotification: notificationClick
//       );

//       firebaseMessaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//       );
//     });
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     userListener?.cancel();
//     participantDashboardListener?.cancel();
//     tokenSubscription?.cancel();
//     queueSubscription?.cancel();
//     queueMessageSubscription?.cancel();
//     studioInvitationSubscription?.cancel();
//     deliverySubscription?.cancel();
//     bigInvitationSubscription?.cancel();
//     studioSubscription?.cancel();
//   }

//   // Init Local DB
//   syncLocalDB(){
//     // Chat Media
//     appService.initChatSQLite().then((db) {
//       print("Init DB $db");
//       appService.uploadMedia(db, "chatmedia", "messagepath", callBack: (){
//         ("Chat Upload Progress ${appService.uploadProcessing}");
//       });
//     });

//     // Video Ask
//     appService.initVideoAskSQLite().then((db) {
//       videoaskDB = db;
//       print("Init DB $db");
//       appService.uploadVideoAsk(db, "videoask", callBack: (){
//         ("VideoAsk Upload Progress ${appService.uploadProcessing}");
//       });
//     });
//   }

//   onMessageNotification(
//     {required int notificationIndex,
//     required String title,
//     required String body,
//     required String payload}
//   )
//   {
//     var android = AndroidNotificationDetails(
//     "channelId", "channelName",
//     channelDescription: "channelDescription"
//     );
//     var ios = DarwinNotificationDetails();
//     var platform = NotificationDetails(android: android, iOS: ios);
//     flutterLocalNotificationsPlugin.show(notificationIndex, "$title", "$body", platform, payload: payload).then((onValue) {
//       print("Success");
//     }).catchError((onError) {
//       print("Notification Error:  $onError");
//       appService.logException(exception: "$onError", stack: "");
//     }).catchError((err) {
//       print(err);
//       appService.logException(exception: "$err", stack: "");
//     });
//   }

//   notificationClick(String? payload) async {
//     Map message = jsonDecode(payload!);
//     print("navigateclick ------- $message");
//     // Navigator.push(
//     //   context,
//     //   MaterialPageRoute(
//     //     builder: (BuildContext context) {
//     //       return NotificationLog();
//     //     },
//     //     maintainState: false
//     //   )
//     // );
//   }

//   launchURL(String url) async {
//     if (await canLaunchUrl(Uri.parse(url))) {
//       // await launchUrl(Uri.parse(url));
//       await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
//     } else {
//       await showDialog<String>(
//         context: context,
//         barrierDismissible: false,
//         builder: (BuildContext context) {
//           String title = "Something Wrong";
//           String message = "Could not able to launch $url";
//           return Platform.isIOS ? CupertinoAlertDialog(
//             title: Text(title),
//             content: Text(message),
//               actions: <Widget>[
//                 CupertinoDialogAction(
//                   child: Text("OK"),
//                   onPressed: () => Navigator.pop(context),
//                 ),
//               ],
//           )
//           : AlertDialog(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//             title: Text(title),
//             content: Text(message),
//             actions: <Widget>[
//               TextButton(
//                 child: Text("OK"),
//                 onPressed: () => Navigator.pop(context),
//               ),
//             ],
//           );
//         },
//       );
//     }
//   }

//   // logoutUser() async {
//   //   Navigator.of(context).pop(false);
//   //   // WidgetService().loadingdialog(context, "Signing out.....");
//   //   await appService.logoutUser(tokenFCM, context);
//   // }

//   Future<bool> _onWillPop() async {
//     if (screenIndex > 1) {
//       setState(() {
//         screenIndex = screenIndex - 1;
//       });
//       return false;
//     } else {
//       return await showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
//           title: Text('Are you sure?'),
//           content: Text('Do you want to exit an App'),
//           actions: <Widget>[
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: Text('No'),
//             ),
//             TextButton(
//               onPressed: () => exit(0),
//               child: Text('Yes'),
//             ),
//           ],
//         ),
//       );
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     // TODO: implement build
//     throw UnimplementedError();
//   }
// }
