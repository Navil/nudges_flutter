import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nudges_flutter/pages/editprofile_page.dart';
import 'package:nudges_flutter/pages/options_page.dart';
import 'package:nudges_flutter/util/user_data.dart';

class AccountPage extends StatefulWidget {
  @override
  _AccountPageState createState() => new _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with AutomaticKeepAliveClientMixin<AccountPage> {
  @override
  bool get wantKeepAlive => UserData.uid != null;
  String name;
  String description;
  String photoURL;
  @override
  initState() {
    super.initState();
    // Add listeners to this class
    Firestore.instance
        .collection("users")
        .document(UserData.uid)
        .snapshots()
        .forEach((DocumentSnapshot snapshot) {
      print("Userdata Updated");
      if(mounted){
        setState(() {
          this.name = snapshot.data["firstname"];
          this.description = snapshot.data["description"];
          this.photoURL = snapshot.data["images"][0]["downloadURL"];
          UserData.accessToken = snapshot.data["fbAccessToken"];
          print("URL: "+this.photoURL);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
        body: new Stack(
      children: <Widget>[
        ClipPath(
            child: Container(color: Theme.of(context).primaryColor),
            clipper: GetClipper()),
        Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                new Column(children: [
                  SizedBox(height: MediaQuery.of(context).size.height / 5),
                  new Container(
                    width: 150.0,
                    height: 150.0,

                    decoration: BoxDecoration(
                        color: Theme.of(context).accentColor,
                        image: DecorationImage(
                            image: (photoURL==null||photoURL=="")?AssetImage("assets/img/default_user.png"):NetworkImage(photoURL),
                            fit: BoxFit.cover),
                        borderRadius: BorderRadius.all(Radius.circular(25.0)),
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 7.0,
                              color: Theme.of(context).accentColor)
                        ]),
                  ),
                  FlatButton.icon(
                      label: Text("Edit Images"),
                      onPressed: () {
                        Navigator.of(context).push(new MaterialPageRoute(
                            builder: (context) => new EditProfilePage()));
                      },
                      icon: Icon(Icons.add_a_photo)),
                ]),
                //SizedBox(height: 30.0),
                new Column(children: [
                  Text(this.name!=null?this.name:"Name",
                      style: TextStyle(
                          fontSize: 30.0, fontWeight: FontWeight.bold)),
                  Text(this.description!=null?this.description:"No Description Provided.",
                      style: TextStyle(
                          fontSize: 17.0, fontStyle: FontStyle.italic)),
                  FlatButton.icon(
                      label: Text("Edit Account"),
                      onPressed: () {
                        Navigator.of(context).push(new MaterialPageRoute(
                            builder: (context) => new OptionsPage()));
                      },
                      icon: Icon(Icons.account_circle)),
                ]),
                //SizedBox(height: 60.0),
                //SizedBox(height: 15.0),
                  new Container()
              ]),
        ),
      ],
    ));
  }
}

class GetClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = new Path();

    path.lineTo(0.0, size.height / 2);
    path.lineTo(size.width + size.width / 3, 0.0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}
