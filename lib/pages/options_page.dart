import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nudges_flutter/util/user_data.dart';


class OptionsPage extends StatefulWidget {
  @override
  _OptionsPageState createState() => new _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage>{

  @override
  Widget build(BuildContext context) {
    //super.build(context);
    return Scaffold(
        appBar: AppBar(title: Text('Options')),
        body: FlatButton(child: Text("Logout"), onPressed: () {
          FirebaseAuth.instance.signOut();
        },)
    );
  }
}