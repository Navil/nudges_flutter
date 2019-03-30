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

  TextEditingController _smsCodeController = TextEditingController();
  TextEditingController _phoneNumberController = TextEditingController();
  String verificationId;
  String errorText;

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
    //final image = Image.asset("assets/img/login_image.jpg");
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
      onPressed: () {
        authenticateWithFacebook(context);
      },
    );

    final number = RaisedButton.icon(
      elevation: 4.0,
      color: Theme.of(context).primaryColor,
      icon: new Icon(MdiIcons.send),
      label: const Text('Send SMS Code'),
      textColor: Colors.white,
      onPressed: () {
        _sendCodeToPhoneNumber();
      },
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
           SizedBox(height: 200),
           AnimatedPositioned(
             duration: Duration(seconds:1),
             child: new TextField(
                      decoration: InputDecoration(
                          labelText: 'Enter your number',
                          labelStyle: TextStyle(fontSize: 15),
                          icon: Icon(Icons.phone,size: 40, color: Theme.of(context).primaryColor,),
                          errorText: errorText,
                          errorMaxLines: 6,
                          contentPadding: EdgeInsets.only(bottom: 0),
                          prefixText: "+ ",
                          prefixStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 20),
                      controller: _phoneNumberController,
                    ),
           ),
            number,
            //forgotLabel
          ],
        ),
      ),
      _loading
          ? Stack(children: [
              new Opacity(
                opacity: 0.5,
                child: ModalBarrier(
                    dismissible: false,
                    color: Theme.of(context).primaryColorLight),
              ),
              new Center(
                  child: new Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    new CircularProgressIndicator(
                        valueColor: new AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor)),
                    SizedBox(height: 5.0),
                    Text(
                      "Loading...",
                      style: TextStyle(fontSize: 20.0),
                    )
                  ]))
            ])
          : Container()
    ]));
  }

  authenticateWithNumber(BuildContext context) async {
    final AuthCredential credential = PhoneAuthProvider.getCredential(
      verificationId: verificationId,
      smsCode: _smsCodeController.text,
    );
    final FirebaseUser user =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final FirebaseUser currentUser = await FirebaseAuth.instance.currentUser();
    assert(user.uid == currentUser.uid);
  }

  Future<void> _sendCodeToPhoneNumber() async {
    _loading = true;
    final PhoneCodeAutoRetrievalTimeout autoRetrieve = (String verId) {
      this.verificationId = verId;
    };

    final PhoneCodeSent smsCodeSent = (String verId, [int forceCodeResend]) {
      this.verificationId = verId;
      print("SMSCodeSent");
    };

    final PhoneVerificationCompleted verificationSuccess = (FirebaseUser user) {
      print("Verified");
    };

    final PhoneVerificationFailed verificationFailed =
        (AuthException exception) {
        setState((){
          this.errorText = "The number is in a wrong format.";
        });

        print(exception.message);
    };

    await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: "+"+this._phoneNumberController.text,
        codeAutoRetrievalTimeout: autoRetrieve,
        codeSent: smsCodeSent,
        timeout: const Duration(seconds: 5),
        verificationCompleted: verificationSuccess,
        verificationFailed: verificationFailed);

    _loading = false;
  }

  authenticateWithFacebook(BuildContext context) async {
    print("Facebook Login");
    var facebookLogin = FacebookLogin();
    var facebookLoginResult = await facebookLogin
        .logInWithReadPermissions(['email', "user_birthday", "user_gender"]);
    switch (facebookLoginResult.status) {
      case FacebookLoginStatus.error:
        print("Error");
        onLoginWithFacebookError(context, facebookLoginResult.errorMessage);
        break;
      case FacebookLoginStatus.cancelledByUser:
        print("CancelledByUser");
        break;
      case FacebookLoginStatus.loggedIn:
        print("Got Result: " +
            facebookLoginResult.accessToken.toMap().toString());
        setState(() {
          _loading = true;
        });

        UserData.accessToken = facebookLoginResult.accessToken.token;
        //await FirebaseAuth.instance.signInWithFacebook(accessToken: facebookLoginResult.accessToken.token); TODO

        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        break;
    }
  }
}

onLoginWithFacebookError(BuildContext context, String errorMessage) {
  showDialog(
      context: context,
      builder: (BuildContext context) {
        return new AlertDialog(
          titlePadding: EdgeInsets.all(0.0),
          title: Container(
              padding: EdgeInsets.all(20.0),
              color: Theme.of(context).primaryColor,
              child: Row(children: [
                Text(
                  'Required Data',
                  style: TextStyle(color: Theme.of(context).primaryColorLight),
                )
              ])),
          content: new Text(errorMessage),
          actions: <Widget>[
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      });
}
