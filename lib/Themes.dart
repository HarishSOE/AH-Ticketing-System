

import 'package:flutter/material.dart';

class AppTheme {
  String dummyProfile = "https://firebasestorage.googleapis.com/v0/b/fir-sample-aae4a.appspot.com/o/profile-image-png-14.png?alt=media&token=ce6361d2-690c-4742-bba7-dbb90e193080";
  String ahWhiteLogo = "assets/images/AH_White_Logo_Only.png";
  String ahBlackLogo = "assets/images/AH_Black_Logo_Only.png";
  Color barBGcolor = Colors.white;
  Color barElementcolor = Colors.black;
  double barElevation = 1.5;
  bool barCenterTitle = false;

  Color hexToColor(String code) {
    return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
  }

}