import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:nudges_flutter/location_service.dart';
import 'package:nudges_flutter/pages/missing_information_page.dart';
import 'package:nudges_flutter/pages/mygroups_page.dart';
import 'package:nudges_flutter/pages/findgroups_page.dart';
import 'package:nudges_flutter/pages/account_page.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TabsPage extends StatefulWidget {
  final Widget groupsPage = new MyGroupsPage();
  final Widget findGroupsPage = new FindGroupsPage();
  final Widget accountPage = new AccountPage();

  @override
  _TabsPageState createState() => new _TabsPageState();
}

class _TabsPageState extends State<TabsPage> {

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        body: TabBarView(children: [widget.groupsPage, widget.findGroupsPage,widget.accountPage], physics: NeverScrollableScrollPhysics()),
        bottomNavigationBar: new Material(
            color: Theme.of(context).primaryColor,
            child: new TabBar(
                indicatorColor: Theme.of(context).accentColor,
                labelColor: Theme.of(context).accentColor,
                unselectedLabelColor: Theme.of(context).primaryColorLight,
                tabs: [
                Tab(
                  icon: new Icon(Icons.group),
                ),
                Tab(
                  icon: new Icon(MdiIcons.earth),
                ),
                Tab(icon: new Icon(Icons.account_circle))
              ],
            )),
      ),
    );
  }

  @override
  void initState(){
    super.initState();
    LocationService();
    setupListener();
  }
  setupListener() async{
    if(UserData.accessToken != null)
      await getFacebookData();

    Firestore.instance.collection("users").document(UserData.uid).get().then((userData){
      if(!userData.exists || userData.data["firstname"]==null || userData.data["gender"]==null || userData.data["birthday"]==null){
        Navigator.of(context).push(new MaterialPageRoute(
            builder: (context) => MissingInformationPage()));
      }
    });
  }

  getFacebookData() async{
    var graphResponse = await http.get(
        'https://graph.facebook.com/v3.2/me?fields=birthday,gender,first_name&access_token=${UserData.accessToken}');
    final data = json.decode(graphResponse.body);
    DateTime date;
    if(data["birthday"] != null){
      final dateParts = data["birthday"].toString().split("/");
      //print(dateParts[2]+":"+dateParts[1]+":"+dateParts[0]);
      date = new DateTime(int.tryParse(dateParts[2]),int.tryParse(dateParts[0]),int.tryParse(dateParts[1]));
    }
    //Date test = dateFormat.parse(t);
    await Firestore.instance.collection("users").document(UserData.uid).updateData(
        {"fbAccessToken":UserData.accessToken,
          "gender": data["gender"],
          "firstname": data["first_name"],
          "birthday": date
        });
  }

  @override
  dispose(){
    LocationService().shutdown();
    super.dispose();
  }
}
