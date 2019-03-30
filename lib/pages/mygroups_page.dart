import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:nudges_flutter/pages/showgroup_page.dart';
import 'package:nudges_flutter/pages/newgroup_page.dart';
import 'package:nudges_flutter/util/user_data.dart';

class MyGroupsPage extends StatefulWidget {
  @override
  _MyGroupsPageState createState() => new _MyGroupsPageState();
}

class _MyGroupsPageState extends State<MyGroupsPage>
    with AutomaticKeepAliveClientMixin<MyGroupsPage> {
  @override
  bool get wantKeepAlive => UserData.uid != null;

  bool limitQuery = true;

  final List<Group> groups = new List<Group>();
  Group myGroup;

  @override
  initState() {
    super.initState();
    //Firestore.instance.collection('groups').do
    // Add listeners to this class
    //cartItemStream.listen((data) {
    //_updateWidget(data);
    //});
    //print("Init "+FirebaseData().userRef.child(user).child("groups").toString());
    print("Init State");
    Firestore.instance
        .collection('users')
        .document(UserData.uid)
        .collection("groups")
        .orderBy("lastActivity", descending: true)
        .snapshots()
        .listen((querySnapshot) {
        querySnapshot.documentChanges.forEach((change) {
          setState(() {
            if (change.type == DocumentChangeType.added) {
              print('New Group');
              final Group group = Group.fromSnapshot(change.document);
              if (group.reference.documentID == UserData.uid) {
                this.myGroup = group;
              } else {
                groups.add(group);
              }
            }
            if (change.type == DocumentChangeType.modified) {
              print('Modified city: ');
              Group group = Group.fromSnapshot(change.document);
              if (group.reference.documentID == UserData.uid) {
                this.myGroup = group;
              } else {
                groups.removeAt(change.oldIndex);
                groups.insert(change.newIndex, group);
              }
            }
            if (change.type == DocumentChangeType.removed) {
              print('Removed city: ');
              if (change.document.reference.documentID == UserData.uid) {
                this.myGroup = null;
              } else {
                groups.removeAt(change.oldIndex);
                //groups.add(group);
              }
            }

          });
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: Text('Your Groups')),
      body: _buildBody(context),
//      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
//      floatingActionButton: FloatingActionButton(
//        onPressed: () {
//          Navigator.of(context).push(new MaterialPageRoute(
//              builder: (context) => new CreateGroupPage(groupId: null)));
//        },
//        child: Icon(Icons.add),
//        elevation: 4.0,
//      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(children: [
      _showMyGroup(context),
      //Divider(color: Theme.of(context).accentColor),
      Expanded(
          child: groups.length>0?new ListView.builder(
              itemCount: groups.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildListItem(context, groups[index]);
              }):Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text("You are currently in no groups.")])
      )
    ]);
  }

  Widget _showMyGroup(BuildContext context) {
    return this.myGroup == null
        ? new ListTile(
            title: Text("You have not created a group."),
            trailing: RaisedButton(
                child: Text("Create"),
                onPressed: () {
                  Navigator.of(context).push(new MaterialPageRoute(
                      builder: (context) => new NewGroupPage()));
                }),
            contentPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 0.0),
          )
        : new Column(children: [
          SizedBox(height:20.0),
            Text("Your Group",style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            ListTile(
                title: Text(myGroup.name),
                subtitle: Text(
                    "Thomas: Yeah I will be a bit late today, hope I can make it in time tho",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                leading: CircleAvatar(
                    backgroundColor: Theme.of(context).accentColor,
                    backgroundImage: NetworkImage(
                        "https://vignette.wikia.nocookie.net/jamescameronsavatar/images/0/08/Neytiri_Profilbild.jpg/revision/latest?cb=20100107164021&path-prefix=de")),
                //trailing: group.location!=null?Text(group.location):Text("Währinger Straße 12832"),
                onTap: () => Navigator.of(context).push(new MaterialPageRoute(
                    builder: (context) => new ShowGroupPage(
                        groupId: myGroup.reference.documentID)))),
            Divider()
          ]);
  }

  Widget _buildListItem(BuildContext context, Group group) {
    //print("buildingItem "+group.name);
    return Padding(
      key: ValueKey(group.reference.documentID),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ExpansionPanelList(
          expansionCallback: (int index, bool isExpanded) {
            setState(() {
              groups[groups.indexOf(group)].isExpanded = !isExpanded;
            });
          },
          children: [
            ExpansionPanel(
              isExpanded: group.isExpanded,
              headerBuilder: (BuildContext context, bool isExpanded) {
                return ListTile(
                    title: Text(group.name),
                    subtitle: Text(
                        "Thomas: Yeah I will be a bit late today, hope I can make it in time tho",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    leading: CircleAvatar(
                        backgroundColor: Theme.of(context).accentColor,
                        backgroundImage: NetworkImage(
                            "https://vignette.wikia.nocookie.net/jamescameronsavatar/images/0/08/Neytiri_Profilbild.jpg/revision/latest?cb=20100107164021&path-prefix=de")),
                    //trailing: group.location!=null?Text(group.location):Text("Währinger Straße 12832"),
                    onTap: () => Navigator.of(context).push(
                        new MaterialPageRoute(
                            builder: (context) => new ShowGroupPage(
                                groupId: group.reference.documentID))));
              },
              body: Column(children: [
                new Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                  Expanded(
                      flex: 1,
                      child: Icon(Icons.place,
                          color: group.location != null
                              ? Theme.of(context).accentColor
                              : Colors.grey)),
                  Expanded(
                      flex: 3,
                      child: group.location != null
                          ? Text(group.location)
                          : Text("No Location specified")),
                ]),
                new Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                  Expanded(
                      flex: 1,
                      child: Icon(Icons.calendar_today,
                          color: group.time != null
                              ? Theme.of(context).accentColor
                              : Colors.grey)),
                  Expanded(
                      flex: 3,
                      child: group.time != null
                          ? Text(new DateFormat('yyyy-MM-dd – kk:mm')
                              .format(group.time))
                          : Text("No Time specified")),
                ]),
                new Container(
                  height: 20.0,
                ),
              ]),
            )
          ]),
    );
  }
}

class Group {
  String name;
  String location;
  DateTime time;
  bool isPublic = false;
  DocumentReference reference;
  bool isExpanded = true;

  Map<String, dynamic> toJson() =>
      {'name': name, 'location:': location, 'time': time, 'isPublic': isPublic};

  Group.fromMap(Map<String, dynamic> map, {this.reference})
      : name = map['groupName'],
        location = map['location'],
        isPublic = map['isPublic'],
        time = map['time'];

  Group.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);

  @override
  String toString() => "Group <$name> <$location> <$isPublic ><$time>";
}
