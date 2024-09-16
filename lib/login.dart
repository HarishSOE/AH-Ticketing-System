// ignore_for_file: unused_import, deprecated_member_use

import 'dart:io';
import 'package:ahticketing/AppServices/UserData.dart';
import 'package:ahticketing/Themes.dart';
import 'package:ahticketing/chatQuery.dart';
import 'package:ahticketing/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Login extends StatefulWidget {
  @override
  _Login createState() => _Login();
}

class _Login extends State<Login> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  AppTheme localTheme = AppTheme();
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  FocusNode emailfield = FocusNode();
  FocusNode passwordfield = FocusNode();
  bool isLoading = false;
  var blank = FocusNode();
  bool hidepassword = true;

  // Error Alert
  errorAlert(title, message) {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return Platform.isAndroid
        ? AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28))
          ),
          title: Text("$title"),
          content: Text("$message"),
          actions: <Widget>[
            TextButton(
              child: Text("Ok"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        )
        :CupertinoAlertDialog(
          title: Text("$title"),
          content: Text("$message"),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text("Ok"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      }
    );
  }

  writeUserData(String uid, String pid) async {
    await UserData().storeUserids(
      uid: uid, pid: pid, email: email.text.toLowerCase().trim());
  }

  // Logut Function
  logoutUser() async {
    await auth.signOut();
  }

  // Login User
  Future<void> login() async {
    setState(() {
      hidepassword = true;
    });
    print("Login => Email: ${email.text.toLowerCase().trim()} & Password: ${password.text} ");
    try {
      FocusScope.of(context).requestFocus(blank);
      if (email.text.toLowerCase().trim().isEmpty) {
        errorAlert("Oops", "Please enter the registered email");
        FocusScope.of(context).requestFocus(emailfield);
      } else if (password.text == '') {
        errorAlert("Oops", "Please enter your password");
        FocusScope.of(context).requestFocus(passwordfield);
      } else {
        setState(() {
          isLoading = true;
        });
        await firestore.collection("profile_data").where("email", isEqualTo: email.text.toLowerCase().trim()).limit(1).get().then((profileData) async {
          if (profileData.docs.isNotEmpty && profileData.docs.first.data()["user_ref"] != null) {
            Map<String, dynamic> profileValue = profileData.docs.first.data();
            bool userEnabled = profileValue['enable'] ?? false;
            bool userBlocked = profileValue['block'] ?? false;
            if (userBlocked) {
              errorAlert("Unauthorized","Your Email ID Have Been Blocked From Login Temporarily, Contact Your Adminstrator");
            } else if (!userEnabled) {
              errorAlert("Unauthorized","Your Email ID Not Approved Yet, Please Contact Your Adminstrator");
            } else {
              String rolePath = profileValue["role_ref"].path;
              await firestore.doc(rolePath).get().then((role) async {
                if ((role.data()?["ah"] ?? false) || (role.data()?["developer"] ?? false)) {
                  await signInUser(pid: profileValue["profileid"]);
                } else {
                  errorAlert("Unauthorized","You currently don't have the access to login.");
                }
              });
            }
          } else {
            errorAlert("User Not Found","The given Email ID is not found. Make sure you have registered in Breakthroughs");
          }
        });
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print(e);
      errorAlert("Something Went Wrong", "$e");
    }
  }

  // Sign In Lyrics
  signInUser({required pid}) async {
    await auth.signInWithEmailAndPassword(email: email.text.toLowerCase().trim(), password: password.text).then((user) async {
      await writeUserData(user.user!.uid, pid);
    }).then((value) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (BuildContext context) => ChatQueryAdmin())
      );
    }).catchError((e) {
      setState(() {
        isLoading = false;
      });
      switch (e.code) {
        case "ERROR_INVALID_EMAIL":
          errorAlert("Email-ID Badly formatted","Make sure you are using the registered email-id");
          break;
        case "ERROR_USER_NOT_FOUND":
          errorAlert("User Not Found","Make sure you are using the registered email-id");
          break;
        case "ERROR_WRONG_PASSWORD":
          errorAlert("Incorrect Password","The password you entered doesn't match with the Email");
          break;
        case "ERROR_TOO_MANY_REQUESTS":
          errorAlert("Too Many Request", "Try again later");
          break;
        case "ERROR_NETWORK_REQUEST_FAILED":
          errorAlert("Unable To Connect Server","Check your internet connection and try again");
          break;
        case "Error performing get":
          errorAlert("Unable to connect to server","Try again, Make sure your interner connection is fine.");
          break;
        default:
          errorAlert("${e.code}", "${e.message}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
            title: Text('Are you sure?'),
            content: Text('Do you want to exit the App'),
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
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(children: [
          Center(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(36.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.all(20),
                        child: Text(
                          "A&H TICKETING",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 25.0),
                      TextField(
                        focusNode: emailfield,
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (val) {
                          FocusScope.of(context).requestFocus(passwordfield);
                        },
                        obscureText: false,
                        style: style,
                        textCapitalization: TextCapitalization.none,
                        decoration: InputDecoration(
                          contentPadding:EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                          labelText: "Email",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))
                        ),
                      ),
                      SizedBox(height: 25.0),
                      TextField(
                        focusNode: passwordfield,
                        controller: password,
                        onSubmitted: (val) {
                          login();
                        },
                        obscureText: hidepassword,
                        style: style,
                        decoration: InputDecoration(
                          contentPadding:
                              EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                          labelText: "Password",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32.0)),
                          suffixIcon: IconButton(
                            padding: EdgeInsets.zero,
                            color: Colors.grey,
                            icon: hidepassword
                                ? Icon(Icons.visibility_off)
                                : Icon(Icons.visibility),
                            onPressed: () {
                              setState(() {
                                hidepassword = hidepassword ? false : true;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 25.0,
                      ),
                      isLoading ? SpinKitCubeGrid(
                        color: localTheme.hexToColor("#ED048D"),
                        size: 50.0,
                      )
                      :ButtonTheme(
                        minWidth: MediaQuery.of(context).size.width,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            // primary: Colors.black,
                            // onPrimary: Colors.white,
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius:BorderRadius.circular(18.0)
                            ),
                            padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                          ),
                          onPressed: login,
                          child: Text(
                            "Login",
                            textAlign: TextAlign.center,
                            style: style.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold
                            )
                          ),
                        )
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ])
      )
    );
  }
}

TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);
