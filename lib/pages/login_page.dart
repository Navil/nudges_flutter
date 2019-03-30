import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => new _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    final logo = Hero(
      tag: 'hero',
      child: CircleAvatar(
        backgroundColor: Colors.transparent,
        radius: 48.0,
        child: Image.asset('assets/logo.png'),
      ),
    );

    final email = TextFormField(
      keyboardType: TextInputType.emailAddress,
      autofocus: false,
      decoration: InputDecoration(
        hintText: 'Email',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
      ),
    );

    final password = TextFormField(
      autofocus: false,
      obscureText: true,
      decoration: InputDecoration(
        hintText: 'Password',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
      ),
    );

    final loginButton = Material(
      borderRadius: BorderRadius.circular(30.0),
      shadowColor: Colors.teal,
      elevation: 10.0,
      child: MaterialButton(
        minWidth: 200.0,
        height: 50.0,
        onPressed: () {
          //Navigator.of(context).pushNamed(HomePage.tag);
        },
        color: Theme.of(context).primaryColor,
        child: Text('Login', style: TextStyle(color: Colors.white)),
      ),
    );

    final facebook = RaisedButton.icon(
          elevation: 4.0,
          color: Colors.blue,
          icon: new Icon(MdiIcons.facebook),
          label: const Text('Login with Facebook'),
          textColor: Colors.white,
          onPressed: () {authenticateWithFacebook(context);},
        );

    final forgotLabel = FlatButton(
      child: Text(
        'Forgot password?',
        style: TextStyle(color: Colors.black54),
      ),
      onPressed: () {},
    );

    return Scaffold(
      body: Stack(children: [
        Center(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(left: 24.0, right: 24.0),
            children: <Widget>[
              logo,
              SizedBox(height: 48.0),
              email,
              SizedBox(height: 8.0),
              password,
              SizedBox(height: 24.0),
              loginButton,
              SizedBox(height: 24.0),
              facebook,
              forgotLabel
            ],
          ),
        ),
     _loading?Stack(children: [new Opacity(
        opacity: 0.5,
        child: ModalBarrier(dismissible: false, color: Theme.of(context).primaryColorLight),
        ),
        new Center(
        child: new Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        new CircularProgressIndicator(valueColor: new AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
        SizedBox(height:5.0),
        Text("Loading...",style: TextStyle(fontSize: 20.0),)])
        )]):Container()

      ])
    );
  }

  authenticateWithFacebook(BuildContext context) async {
    print("Facebook Login");
    var facebookLogin = FacebookLogin();
    var facebookLoginResult =
    await facebookLogin.logInWithReadPermissions(['email',"user_birthday","user_gender"]);
    switch (facebookLoginResult.status) {
      case FacebookLoginStatus.error:
        print("Error");
        onLoginWithFacebookError(context,facebookLoginResult.errorMessage);
        break;
      case FacebookLoginStatus.cancelledByUser:
        print("CancelledByUser");
        break;
      case FacebookLoginStatus.loggedIn:
        print("Got Result: "+facebookLoginResult.accessToken.toMap().toString());
        setState(() {
          _loading = true;
        });

        UserData.accessToken = facebookLoginResult.accessToken.token;
        await FirebaseAuth.instance.signInWithFacebook(accessToken: facebookLoginResult.accessToken.token);


        if(mounted){
          setState(() {
            _loading = false;
          });
        }
        break;
    }
  }
}

onLoginWithFacebookError(BuildContext context,String errorMessage) {
  showDialog(
      context: context,
      builder: (BuildContext context) {
        return new AlertDialog(
          titlePadding: EdgeInsets.all(0.0),
          title: Container(padding:EdgeInsets.all(20.0),color:Theme.of(context).primaryColor,child:Row(children:[ Text('Required Data',style: TextStyle(color: Theme.of(context).primaryColorLight),)])),
          content: new Text(errorMessage),
          actions: <Widget>[
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )],
        );
      }
  );
}
