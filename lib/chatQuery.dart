import 'dart:async';

import 'package:ahticketing/AppServices/AppService.dart';
import 'package:ahticketing/AppServices/UserData.dart';
import 'package:ahticketing/Themes.dart';
import 'package:ahticketing/TicketChat.dart';
import 'package:ahticketing/raiseTicket.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as format;

class ChatQueryAdmin extends StatefulWidget {
  const ChatQueryAdmin({super.key});

  @override
  State<ChatQueryAdmin> createState() => _ChatQueryAdminState();
}

class _ChatQueryAdminState extends State<ChatQueryAdmin> {

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  AppService appService = AppService();
  final formKey = GlobalKey<FormState>();
  AppTheme localTheme = AppTheme();

  TextEditingController notes = TextEditingController();

  Map<String,dynamic> chatConfigData = {};
  Map<String,dynamic> loginProfileRoles = {};
  Map<String,dynamic> mapProfile = {};
  Map<String,dynamic> category = {};
  Map<String,dynamic> profileData = {};

  bool loading = true;

  String profileId = '';
  String userId = '';
  String status = '';

  List clientIssues = [];

  int itemsToShow = 3; 
  
  StreamSubscription? clientIssueSubscription;

  @override
  void initState() {
    super.initState();

    UserData().getUserData().then((value) async {
      setState(() {
        profileId = value['pid']!;
        userId = value['uid']!;
      });

      await appService.mapProfile().then((data) {
        setState(() {
          mapProfile = data['map'];
        });
      });

      await firestore.collection("profile_data").doc(profileId).get().then((profile) async {
        await firestore.doc(profile.data()?["role_ref"].path).get().then((role) {
          setState(() {
            profileData = profile.data()!;
            loginProfileRoles = role.data()!;
            print("${profileData},profileData");
          });
        });
      });

      Query collection;
      if(loginProfileRoles['chatxadmin']){
        collection = firestore.collection("clientissue").where("assign",arrayContains: profileId).orderBy("reporteddate",descending: true);
      }else{
        collection = firestore.collection("clientissue").where("clientid",isEqualTo: profileId).orderBy("reporteddate",descending: true);
      }

      clientIssueSubscription = collection.snapshots().listen((ciDocs)async{
        if(ciDocs.docs.length != 0){
          setState(() {
            clientIssues = ciDocs.docs;
            loading = false;
          });
        }else{
          setState(() {
            clientIssues = [];
            loading = false;
          });
          print("No Client Issues Found :) 75");
        }
      });

      // fetching categories
      firestore.collection("chat config").snapshots().listen((chatConfigDoc) {
        if(chatConfigDoc.docs.length != 0){
          setState(() {
            chatConfigData = chatConfigDoc.docs.first.data();
          });
        }else{
          print("No Categories Found :( 57");
        }
      });

    });

  }

  @override
  void dispose(){
    super.dispose();
    clientIssueSubscription?.cancel();
  }

  void showMore() {
    setState(() {
      itemsToShow  = clientIssues.length;
    });
  }

  void showLess() {
    setState(() {
      itemsToShow  = 3;
    });
  }

  changeStatus(ticketData){
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(20), topLeft: Radius.circular(20))
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context,
            void Function(void Function()) sheetState) {
            return Container(
              padding: EdgeInsets.all(10),
              height: MediaQuery.of(context).size.height / 1.1,
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 20,),
                    Text(
                      "Edit Ticket",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20,),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildRichText("Name : ", ticketData['name']),
                        buildRichText("Reported By : ", mapProfile[ticketData['reportedBy']]),
                        buildRichText("Ticket Description : ", ticketData['issue']),
                      ],
                    ),
                    Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 10,),
                          Text(
                            "Category",
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(top: 0, bottom: 9),
                            padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 0.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black, width: 1.0),
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                value: category,
                                isExpanded: true,
                                onChanged: (Map<String, dynamic>? newValue) {
                                  sheetState((){
                                    category = newValue!;
                                  });
                                },
                                items: chatConfigData['categories'].map<DropdownMenuItem<Map<String, dynamic>>>((dynamic item) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: item,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${item["category"]}",
                                          style: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: item["assignto"].map<Widget>((name) => 
                                            Text(
                                            " ${mapProfile[name]}, ",
                                            style: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 15,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          )).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              )
                            ),
                          ),
                          SizedBox(height: 10,),
                          Text(
                            "Status",
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(top: 0, bottom: 9),
                            padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 0.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black, width: 1.0),
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: status,
                                isExpanded: true,
                                onChanged: (String? newValue) {
                                  sheetState(() {
                                    status = newValue!;
                                  });
                                },
                                items: chatConfigData['status'].map<DropdownMenuItem<String>>((dynamic item) {
                                  return DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(
                                      "${item}",
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 15,
                                        color: Colors.black,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              )
                            ),
                          ),
                          SizedBox(height: 10,),
                          Text(
                            "Add Notes",
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                          TextFormField(
                            maxLines:2,
                            controller: notes,
                            textCapitalization:TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText:"Type Notes",
                              contentPadding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0),borderSide: BorderSide())
                            ),
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 10,),
                          Text(
                            "Previous Notes",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 10,),
                          ticketData['notes'].length != 0 ? ListView.builder(
                            padding: EdgeInsets.zero,
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: ticketData['notes'].length,
                            itemBuilder: (BuildContext context, index) {
                              Map note = ticketData['notes'][index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${mapProfile[note['writtenBy']]}",
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        "${format.DateFormat("EEE MMM d, yyyy").format(note["date"].toDate())}",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5,),
                                  Text(
                                    "${note['remarks']}",
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.start,
                                  ),
                                  SizedBox(
                                    child: Divider(),
                                  )
                                ],
                              );
                            }
                          ) : Container(
                            child: Text(
                              "No Notes",
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ), 
                    SizedBox(height: 10,),
                    Container(
                      alignment: Alignment.center,
                      margin: EdgeInsets.only(bottom: 50),
                      width: 200,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 246, 84, 168),
                          textStyle: const TextStyle(fontSize: 14),
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        ),
                        onPressed: () {
                          print(ticketData);
                          updateTicket(ticketData,status);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Submit',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ]
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  updateTicket(ticketData,selectedstatus){

    List notesList = ticketData['notes'];
    if(notes.text.isNotEmpty){
      Map<String,dynamic> note = {
        "date" : DateTime.now(),
        "remarks" : notes.text,
        "writtenBy" : profileId 
      };
      notesList.add(note);
    }

    firestore.collection("clientissue").doc(ticketData['id']).update({
      "category" : category['category'],
      "status" : {
        "date" : DateTime.now(),
        "editedBy" : profileId,
        "status" : selectedstatus,
      },
      "last_modification" : DateTime.now(),
      "assign" : category['assignto'],
      "notes" : notesList
    }).then((_){
      print("Ticket Updated Successfully");
      setState(() {
        notes.text = '';
      });
      Navigator.pop(context);
    }).catchError((error){
      print("${error}Oops error while updating Ticket");
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: loading ? Colors.white : localTheme.hexToColor("#ED048D"),
      ),
      body: loading ? Center(
        child: SpinKitCubeGrid(
          color: localTheme.hexToColor("#ED048D"),
          size: 50.0,
        )
      ) : clientIssues.length == 0 || clientIssues.isEmpty ? Container(
        child: Center(
          child: Container(
            child: Text(
              "No Tickets Assigned to You .. :)",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black,
              ),
            ),
          )
        ),
      ) : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget> [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    localTheme.hexToColor("#ED048D"),
                    localTheme.hexToColor("#ED048D"),
                    localTheme.hexToColor("#f90497"),
                    Colors.white,
                  ],
                )
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    alignment: Alignment.bottomLeft,
                    margin: EdgeInsets.only(left: 10,top: 15),
                    height: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tickets",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "${profileData['name'] == '' || profileData['name'] == null ? '...' : 'Assigned to you ' + profileData['name'] }",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            clientIssues.length != 0 && clientIssues.isNotEmpty ? Container(
              margin: EdgeInsets.only(left: 10,right: 10,top: 10),
              alignment: Alignment.bottomLeft,
              child: Text(
                "Recent Queries",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
            ) : SizedBox(),
            clientIssues.length != 0 && clientIssues.isNotEmpty ? Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.only(top:10,left: 10,right: 10),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: clientIssues.length > 3 ? itemsToShow : clientIssues.length,
                    itemBuilder: (BuildContext context, index) {
                      Map issueData = clientIssues[index].data();
                      issueData['category'] = chatConfigData['categories'].where((e) => e['category'] == issueData['category']).toList()[0];
                      return GestureDetector(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                blurRadius: 5,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          margin: EdgeInsets.only(bottom: 10),
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(),
                                    padding: EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        buildRichText("Ticket No : ", issueData['issueno']),
                                        loginProfileRoles['chatxadmin'] == true ?
                                        buildRichText("Name : ", issueData['name']) : SizedBox(),
                                        SizedBox(height: 5,),
                                        Container(
                                          width: MediaQuery.of(context).size.width / 1.3,
                                          child: Text(
                                            "${issueData['issue']}",
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 5,),
                                        Text(
                                          "${format.DateFormat("EEE MMM d, yyyy").format(issueData["reporteddate"].toDate())}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StreamBuilder(
                                    stream: firestore.collection("clientissue").doc(issueData['id']).collection('messages').where('pending',arrayContains:'admin').snapshots(), 
                                    builder: (BuildContext context,AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot){
                                      if(snapshot.data?.docs.length != 0){
                                        issueData['unread'] = snapshot.data?.docs.length;
                                      }
                                      if(snapshot.hasData){
                                        return snapshot.data?.docs.length != 0 ? Container(
                                          margin: EdgeInsets.only(right: 10,top: 5),
                                          padding:EdgeInsets.all(5),
                                          child: Text(
                                            "${snapshot.data?.docs.length}",
                                            style: TextStyle(color:Colors.white),
                                          ),
                                          decoration:BoxDecoration(color: Colors.red,shape:BoxShape.circle,),
                                        ) : SizedBox();
                                      }
                                      return SizedBox();
                                    }
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: (){
                                  if(loginProfileRoles['chatxadmin'] == true){
                                    setState(() {
                                      category = issueData['category'];
                                      status = issueData['status']['status']; 
                                      issueData['notes'] = issueData['notes'].length != 0 ? issueData['notes'] : []; 
                                    });
                                    changeStatus(issueData);
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    // color: issueData['status']['status'] == 'Closed' || issueData['status']['status'] == 'Resolved' ? Colors.red[200] :  issueData['status']['status'] == 'Open' ? Colors.green : issueData['status']['status'] == 'Action yet to be taken' ? Colors.orange : Colors.grey,
                                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10),bottomRight: Radius.circular(10))
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                      "${issueData['status']['status']}",
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      Icon(Icons.navigate_next_rounded,color: Colors.white,)
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: (){
                          Navigator.push(context, MaterialPageRoute(
                            builder: (BuildContext context) {
                              return TicketChat(
                                chatIndex : issueData['unread'] ?? 0,
                                issueid : issueData['id'],
                                userUid : userId,
                                userName : profileData['name'],
                                userEmail : profileData['email'],
                                userProfileID : profileId,
                                messageRef : firestore.collection("clientissue").doc(issueData['id']).collection("messages"),
                                issueref : firestore.collection("clientissue").doc(issueData['id']),
                              );
                            })
                          );
                          setState(() {
                            clientIssueSubscription?.cancel();
                          });
                        },
                      );
                    },
                  ),
                ),
                if (itemsToShow < clientIssues.length)
                TextButton(
                  onPressed: showMore,
                  child: Text('Show More',style: TextStyle(color: Colors.grey),),
                ),
                if(itemsToShow >= clientIssues.length && itemsToShow != 3)
                TextButton(
                  onPressed: showLess,
                  child: Text('Show Less',style: TextStyle(color: Colors.grey),),
                ),
              ],
            ) : SizedBox(),
            SizedBox(height: 10,),
            !loginProfileRoles['chatxadmin'] ?
            Container(
              margin: EdgeInsets.only(left: 10,right: 10,bottom: 10),
              alignment: Alignment.bottomLeft,
              child: Text(
                "Help with Queries",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3
                ),
              ),
            ) : SizedBox(),
            !loginProfileRoles['chatxadmin'] ? Container(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: chatConfigData['categories'].length ?? 0,
                itemBuilder: (BuildContext context, index) {
                  var category = chatConfigData['categories'];
                  return category[index]['subcategories'].length == 0 ? Container(
                    color: Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: index == 0 ? BorderSide(width: 0.5, color: Colors.grey.shade300) : BorderSide(width: 0,color:Colors.grey.shade300),
                          bottom: BorderSide(width: 0.5, color: Colors.grey.shade300),
                        ),
                      ),
                      child : ListTile( 
                        title: Text(
                          "${category[index]['category']}",
                          style: TextStyle(
                            fontWeight: FontWeight.w400
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded,size: 16,),
                        onTap: (){
                          Navigator.push(context, MaterialPageRoute(
                            builder: (BuildContext context) {
                              return RaiseTicket(
                                category : category[index],
                                subcategory : null,
                                message : chatConfigData['messages'],
                                profileId : profileId,
                                userId : userId,
                                profileData : profileData
                              );
                            })
                          );
                        },
                      )
                    )
                    
                  ) : Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(width: 0.5, color: Colors.grey.shade300),
                      ),
                    ),
                    child: ExpansionTile(
                      shape: Border.fromBorderSide(BorderSide.none),
                      collapsedBackgroundColor: Colors.white,
                      backgroundColor: Colors.white,
                      title: Text("${category[index]['category']}"),
                      children: [
                        Column(
                          children: _buildItemsList(category[index]['subcategories'],category[index],context,chatConfigData,profileId,userId,profileData)
                        ),
                      ],
                    ),
                  );
                }
              ),
            ) : SizedBox(),
            SizedBox(height: 10,),
          ],
        ),
      )
    );
  }
}

List<Widget> _buildItemsList(List<dynamic> items,category,context,chatConfigData,profileId,userId,profileData) {
  List<Widget> itemList = [];
  for (var item in items) {
    itemList.add(
      ListTile(
        trailing: Icon(Icons.arrow_forward_ios_rounded,size: 16,),
        title: Text(item['subcategory'],style: TextStyle(fontWeight: FontWeight.w400,fontSize: 14),),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (BuildContext context) {
              return RaiseTicket(
                category : category,
                subcategory : item['subcategory'],
                message : chatConfigData['messages'],
                profileId : profileId,
                userId : userId,
                profileData : profileData
              );
            })
          );
        },
      ),
    );
  }
  return itemList;
}

RichText buildRichText(first,second){
  return RichText(
    text: TextSpan(
      children: [
        TextSpan(
          text: '${first}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        TextSpan(
          text:"${second}",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
      ]
    ),
  );
}