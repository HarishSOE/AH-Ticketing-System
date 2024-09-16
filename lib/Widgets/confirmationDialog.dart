import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ConfirmationWidget extends StatefulWidget {
  final String title;
  final String message;
  final List<Widget> actions;

  ConfirmationWidget({
    Key? key,
    required this.title,
    required this.message,
    required this.actions,
  });
  _ConfirmationWidget createState() => _ConfirmationWidget();
}

class _ConfirmationWidget extends State<ConfirmationWidget> {
  Widget build(BuildContext context) {
    return Platform.isAndroid
        ? AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(28))),
            title: Text("${widget.title}"),
            content: Text("${widget.message}"),
            actions: widget.actions)
        : CupertinoAlertDialog(
            title: Text("${widget.title}"),
            content: Text("${widget.message}"),
            actions: widget.actions);
  }
}
