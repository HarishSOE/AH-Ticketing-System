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
import 'package:ahticketing/watiQuery.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  FocusNode blank = FocusNode();
  bool isLoading = false;
  bool hidepassword = true;

    @override
  void initState() {
    super.initState();
  }

  Future<void> writeUserData(String uid, String pid) async {
    // Implementation for writing user data
    // This is just a placeholder - replace with your actual implementation
    await SharedPreferences.getInstance().then((prefs) {
      prefs.setString('uid', uid);
      prefs.setString('pid', pid);
    });
  }

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

  // Logut Function
  logoutUser() async {
    await auth.signOut();
  }

  // Login User
    Future<void> login() async {
    setState(() {
      hidepassword = true;
    });
    
    try {
      FocusScope.of(context).requestFocus(blank);
      
      // Check if email is empty
      if (email.text.trim().isEmpty || email.text == null) {
        errorAlert("Oops", "Please enter the registered email");
        FocusScope.of(context).requestFocus(emailfield);
        return;
      }
      
      // Check if password is empty
      if (password.text.isEmpty || password.text == null) {
        errorAlert("Oops", "Please enter your password");
        FocusScope.of(context).requestFocus(passwordfield);
        return;
      }
      
      setState(() {
        isLoading = true;
      });
      
      // Query Firestore for user profile
      try {
        var profileData = await firestore
            .collection("profile_data")
            .where("email", isEqualTo: email.text.toLowerCase().trim())
            .limit(1)
            .get();
        
        if (profileData.docs.isNotEmpty && profileData.docs.first.data().containsKey("user_ref")) {
          Map<String, dynamic> profileValue = profileData.docs.first.data();
          bool userEnabled = profileValue['enable'] ?? false;
          bool userBlocked = profileValue['block'] ?? false;
          
          if (userBlocked) {
            errorAlert("Unauthorized", "Your Email ID Have Been Blocked From Login Temporarily, Contact Your Administrator");
          } else if (!userEnabled) {
            errorAlert("Unauthorized", "Your Email ID Not Approved Yet, Please Contact Your Administrator");
          } else {
            String rolePath = profileValue["role_ref"].path;
            var role = await firestore.doc(rolePath).get();
            
            if ((role.data()?["ah"] ?? false) || (role.data()?["developer"] ?? false)) {
              await signInUser(pid: profileValue["profileid"]);
            } else {
              errorAlert("Unauthorized", "You currently don't have the access to login.");
            }
          }
        } else {
          errorAlert("User Not Found", "The given Email ID is not found. Make sure you have registered in Breakthroughs");
        }
      } catch (firestoreError) {
        print("Firestore error: $firestoreError");
        errorAlert("Database Error", "Unable to verify user credentials. Please try again later.");
      }
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Login error: $e");
      errorAlert("Something Went Wrong", e.toString());
    }
  }
  
  // Fixed sign in function
  Future<void> signInUser({required String pid}) async {
    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email.text.toLowerCase().trim(),
        password: password.text,
      );
      
      await writeUserData(userCredential.user!.uid, pid);
      
      if (mounted) { // Check if widget is still mounted before navigation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (BuildContext context) => InboxScreen()),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      // Updated error codes for new Firebase SDK
      final error = e as FirebaseAuthException;
      switch (error.code) {
        case "invalid-email":
          errorAlert("Email-ID Badly formatted", "Make sure you are using the registered email-id");
          break;
        case "user-not-found":
          errorAlert("User Not Found", "Make sure you are using the registered email-id");
          break;
        case "wrong-password":
          errorAlert("Incorrect Password", "The password you entered doesn't match with the Email");
          break;
        case "too-many-requests":
          errorAlert("Too Many Requests", "Try again later");
          break;
        case "network-request-failed":
          errorAlert("Unable To Connect Server", "Check your internet connection and try again");
          break;
        default:
          errorAlert(error.code, error.message ?? "Authentication failed");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(fontFamily: 'Poppins', fontSize: 16.0,color: Colors.white70,);
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
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4A0080), // Deep Purple
                Color.fromARGB(255, 0, 0, 0), // Lighter Purple or any shade you like
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [              
              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          // Logo and Title
                          Container(
                            padding: EdgeInsets.only(bottom: 60.0),
                            child: Column(
                              children: [
                                Text(
                                  "A&H",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                SizedBox(height: 4.0),
                                Text(
                                  "Communications",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Username field
                          Container(
                            margin: EdgeInsets.only(bottom: 16.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: TextField(
                              focusNode: emailfield,
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              onSubmitted: (val) {
                                FocusScope.of(context).requestFocus(passwordfield);
                              },
                              style: style,
                              decoration: InputDecoration(
                                hintText: "Email",
                                hintStyle: TextStyle(color: Colors.white54),
                                contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          
                          // Password field
                          Container(
                            margin: EdgeInsets.only(bottom: 16.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: TextField(
                              focusNode: passwordfield,
                              controller: password,
                              obscureText: hidepassword,
                              style: style,
                              decoration: InputDecoration(
                                hintText: "Password",
                                hintStyle: TextStyle(color: Colors.white54),
                                contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  padding: EdgeInsets.zero,
                                  color: Colors.white54,
                                  icon: hidepassword
                                      ? Icon(Icons.visibility_off)
                                      : Icon(Icons.visibility),
                                  onPressed: () {
                                    setState(() {
                                      hidepassword = !hidepassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          
                          // Login button
                          Container(
                            width: double.infinity,
                            height: 48,
                            margin: EdgeInsets.only(top: 8.0),
                            child: ElevatedButton(
                              onPressed: (){
                                login();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF8000FF), // Bright purple
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading ? SpinKitThreeBounce(
                                color: Colors.white,
                                size: 20.0,
                              ) : Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
}

// Custom painter for the X pattern background
class XPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Diagonal line from top-left to bottom-right
    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, size.height),
      paint,
    );

    // Diagonal line from top-right to bottom-left
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}