import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserData{
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Future<SharedPreferences> sharedPreferences = SharedPreferences.getInstance();

  // Store user data
  storeUserids({required String uid, required String pid, required String email})async{
    SharedPreferences preferences = await sharedPreferences;
    preferences.setString("useremail", email);
    preferences.setString("useruid", uid);
    preferences.setString("userpid", pid);
  }

  // Get user data
  Future<Map<String, String>> getUserData()async{
    SharedPreferences preferences = await sharedPreferences;

    String email = preferences.getString("useremail") ?? "";
    String uid = preferences.getString("useruid") ?? "";
    String pid = preferences.getString("userpid") ?? "";

    if(email.isEmpty && uid.isEmpty && pid.isEmpty){
      print("Storing....");
      email = auth.currentUser!.email.toString();
      uid = auth.currentUser!.uid;
      await firestore.collection("profile_data").where("email", isEqualTo: email).where("user_ref", isEqualTo: firestore.collection("user_data").doc(uid)).limit(1).get().then((profileData)async{
        pid = profileData.docs[0].id;
      });
      await storeUserids(uid: uid, pid: pid, email: email);
    }

    Map<String, String> user = {
      "email" : email,
      "uid" : uid,
      "pid" : pid,
    };

    return user;
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

}

// class AppService {
//   final FirebaseAuth auth = FirebaseAuth.instance;

//   logoutUser(uid, email, BuildContext context) async {
//     await auth.signOut();
//     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Login()));
//     print("Logged Out .. :(");
//   }
// }