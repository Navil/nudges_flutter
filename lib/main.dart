import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nudges_flutter/pages/login_page.dart';
import 'package:nudges_flutter/pages/missing_information_page.dart';
import 'package:nudges_flutter/pages/tabs_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nudges_flutter/util/user_data.dart';


void main() async {
  ///
  /// Force the layout to Portrait mode
  ///
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown
  ]);
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {

  final routes = <String, WidgetBuilder>{
    '/login': (context) => new LoginPage(),
    '/tabs': (context) => new TabsPage(),
  };

  Widget getLandingPage() {
    return StreamBuilder<FirebaseUser>(
      stream: FirebaseAuth.instance.onAuthStateChanged,
      builder: (BuildContext context, snapshot) {
        print("Updated Login: "+snapshot.toString());
        if (snapshot.hasData) {
          UserData.uid = snapshot.data.uid;
          return TabsPage();
        } else {
          if(UserData.uid != null){
            while(Navigator.canPop(context)){
              Navigator.pop(context);
            }
          }
          UserData.uid = null;
          print("Redirect to Login");

          return LoginPage();
        }
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    var mainColor = Colors.teal;
    var accent = Colors.orangeAccent;
    return MaterialApp(
        title: 'Nudges',
        //showPerformanceOverlay: true,
        theme: new ThemeData(
            // Add the 3 lines from here...
            primarySwatch: mainColor,
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
            buttonColor: mainColor,
            primaryColorLight: mainColor.shade50,
            scaffoldBackgroundColor: mainColor.shade50,
            accentColor: accent,
            dialogBackgroundColor: mainColor.shade100,
            textSelectionHandleColor: accent,
            disabledColor: Colors.black87,
            dividerColor: mainColor,
            cursorColor: mainColor,
            cardColor: mainColor.shade200, //used for ExpansionPanel
            fontFamily: 'OpenSans'),
        home: getLandingPage(),
        routes: this.routes);
  }
}
