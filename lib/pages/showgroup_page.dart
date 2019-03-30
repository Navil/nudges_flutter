import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:nudges_flutter/util/SecretLoader.dart';

class ShowGroupPage extends StatefulWidget {
  final String groupId;
  ShowGroupPage({Key key, @required this.groupId}) : super(key: key);
  @override
  _ShowGroupPageState createState() => new _ShowGroupPageState();
}

class _ShowGroupPageState extends State<ShowGroupPage>
    with SingleTickerProviderStateMixin {

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  Secret _secret;
  dynamic _places;

  TabController _tabController;
  int _currentSegmentIndex = 0;
  bool _sheetShown = false;
  bool _isEditing = false;
  StreamSubscription<DocumentSnapshot> listener;
  final TextEditingController _textController = new TextEditingController();

  final _pageController = new PageController(viewportFraction: 1.0);
  final _pageDuration = Duration(milliseconds: 300);
  final _pageCurve = Curves.ease;

  Group group = new Group();

  @override
  initState(){
    super.initState();
    // Add listeners to this class
    //cartItemStream.listen((data) {
    //_updateWidget(data);
    //});
    //print("Init "+FirebaseData().userRef.child(user).child("groups").toString());
    _tabController =
        new TabController(vsync: this, length: 2, initialIndex: _currentSegmentIndex);

    listenToChanges(widget.groupId);
    loadKey();
  }

  void loadKey() async{
    _secret = await SecretLoader(secretPath: "secrets.json").load();
    _places = new GoogleMapsPlaces(apiKey:_secret.kGoogleMapsApiKey);
  }

  listenToChanges(String groupId){
    this.listener = Firestore.instance.collection('groups').document(groupId).snapshots().listen((querySnapshot) {
      //print("Got "+querySnapshot.data.toString()+ " for "+groupId);
      if(!querySnapshot.exists){
        Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (Route<dynamic> route) => false);
      }



      if (this.mounted && querySnapshot.exists) {
        setState(() {
          this.group = Group.fromSnapshot(querySnapshot);
          this._textController.text = this.group.name;
        });
      }
    });

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
          leading: new IconButton(
              icon: new Icon(Icons.arrow_back),
              onPressed: (){
                if(_pageController.page == 1){
                  _pageController.animateToPage(
                    0, curve: this._pageCurve, duration: this._pageDuration,
                  );
                }else{
                  Navigator.pop(context);
                }
              }
          ),
          title: Text('Group'),
          actions: !this._isEditing
              ? <Widget>[
                  IconButton(
                    icon:
                        Icon(Icons.edit, color: Theme.of(context).accentColor),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  )
                ]
              : null),
      body: new PageView.builder(
        physics: new NeverScrollableScrollPhysics(),
        controller: _pageController,
        itemBuilder: (BuildContext context, int index) {
          index = index%2;
          return index==0?new Column(
            children: [
              new TextField(
                  enabled: _isEditing,
                  controller: _textController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                      fontSize: 20.0),
                  cursorColor: Theme.of(context).primaryColor,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.only(left: 10.0, top: 15.0),
                    hintText: "Name of the Group"

                  )),
              new ListTile(                      //message:"Groups will automatically deleted 12 hours after the set time."),
                  enabled: _isEditing,
                  leading: Icon(Icons.calendar_today,
                      color: this.group.time != null
                          ? Theme.of(context).accentColor
                          : Colors.grey),
                  title: const Text('Time'),
                  subtitle: this.group.time != null
                      ? Text(new DateFormat('yyyy-MM-dd – kk:mm')
                          .format(this.group.time))
                      : Text("No Time specified"),
                  onTap: () {
                    showDateTimeWindow(context);
                  }),
              new ListTile(
                  enabled: _isEditing,
                  leading: Icon(Icons.place,
                      color: this.group.location != null
                          ? Theme.of(context).accentColor
                          : Colors.grey),
                  title: const Text('Location'),
                  subtitle: this.group.location != null
                      ? Text(this.group.location)
                      : Text("No Location specified"),
                  onTap: () {
                    showPlacesWindow(context);
                  }),
              buildSegments(context),
              new Expanded(
                child: new TabBarView(
                    controller: _tabController,
                    // Restrict scroll by user
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Sign In View
                      new Center(
                        child: new Text("Here are the Members of the Group"),
                      ),
                      // Sign Up View
                      new Center(
                        child: new Text("Here are the Requests of the Group"),
                      )
                    ]),
              )
            ],
          ):Text("Here is the Chat");

        },
      ),
      persistentFooterButtons: _isEditing ? buildFooter(context) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: !_isEditing?FloatingActionButton(
        onPressed: () {
          _pageController.animateToPage(
            1, curve: this._pageCurve, duration: this._pageDuration,
          );
        },
        child: Icon(Icons.chat_bubble_outline),
        elevation: 4.0,
      ):null,
    );
  }

  Widget buildSegments(BuildContext context) {
    return new Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new FlatButton(
                color: _currentSegmentIndex == 0
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).primaryColorLight,
                onPressed: () {
                  _tabController.animateTo(0);
                  setState(() {
                    _currentSegmentIndex = 0;
                  });
                },
                child: new Text("Members"),
                textColor: _currentSegmentIndex == 0
                    ? Theme.of(context).accentColor
                    : Theme.of(context).primaryColor,
              ),
              new FlatButton(
                color: _currentSegmentIndex == 1
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).primaryColorLight,
                onPressed: () {
                  _tabController.animateTo(1);
                  setState(() {
                    _currentSegmentIndex = 1;
                  });
                },
                child: new Text("Requests"),
                textColor: _currentSegmentIndex == 1
                    ? Theme.of(context).accentColor
                    : Theme.of(context).primaryColor,
              )
            ]));
  }

  List<Widget> buildFooter(BuildContext context) {
    return <Widget>[
      new FlatButton(
        child: new Icon(Icons.delete, color: Colors.red),
        onPressed: () {
          return showDialog<Null>(
            context: context,
            barrierDismissible: false, // user must tap button!
            builder: (context) {
              return AlertDialog(
                titlePadding: EdgeInsets.all(0.0),
                title: Container(padding:EdgeInsets.all(20.0),color:Theme.of(context).primaryColor,child:Row(children:[ Text('Delete Group',style: TextStyle(color: Theme.of(context).primaryColorLight),)])),
                content: Text('Are you sure, you want to delete this group?'),
                actions: <Widget>[
                  FlatButton(
                    child: Text('Delete'),
                    onPressed: () async{
                      if (_sheetShown) Navigator.pop(context);
                        await Firestore.instance.collection("users").document(this.group.owner).collection("groups").document(this.group.reference.documentID).delete();
                        await Firestore.instance.collection("groups").document(this.group.reference.documentID).delete();
                        //Navigator.pop(context);
                    },
                  ),
                  FlatButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  )
                ],
              );
            },
          );
        },
      ),
      new FlatButton(
        child: new Icon(_sheetShown ? Icons.cancel : Icons.person_add,
            color: _sheetShown
                ? Theme.of(context).accentColor
                : Theme.of(context).primaryColor),
        onPressed: () {
          if (_sheetShown)
            this.hideAddSheet();
          else
            _scaffoldKey.currentState
                .showBottomSheet<Null>(this.buildAddSheet(context));
        },
      ),
      new FlatButton(
          child: new Icon(Icons.check, color: Theme.of(context).primaryColor),
          onPressed: () {
            this.updateGroup();
          }),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    if(listener != null)
      listener.cancel();
    super.dispose();
  }

  showPlacesWindow(BuildContext context) async {
    Prediction p = await PlacesAutocomplete.show(
        context: context,
        apiKey: _secret.kGoogleMapsApiKey,
        onError: (res) {
          print(res.errorMessage);
        },
        mode: Mode.overlay,
        components: [Component(Component.country, UserData.countryCode)]);
    if (p != null && p.description != null) {
      PlacesDetailsResponse detail = await this._places.getDetailsByPlaceId(p.placeId);
      setState(() {
        this.group.geoPoint = GeoPoint(detail.result.geometry.location.lat,detail.result.geometry.location.lng);
        this.group.location = p.description;
      });
      //this.group
    }
  }

  showDateTimeWindow(BuildContext context) async {
    final DateTime date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(new Duration(minutes: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(new Duration(days: 365)),
        initialDatePickerMode: DatePickerMode.day);
    if (date == null) return;

    final TimeOfDay picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());

    if (picked != null) {
      setState(() {
        this.group.time = new DateTime(
            date.year, date.month, date.day, picked.hour, picked.minute);
      });
    }
  }

  WidgetBuilder buildAddSheet(BuildContext context) {
    setState(() {
      this._sheetShown = true;
    });
    return (context) {
      return Container(
          color: Theme.of(context).primaryColorLight,
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new ListTile(
                leading: new Icon(Icons.add),
                title: new Text('Add by Username'),
                onTap: () {
                  this.hideAddSheet();
                },
              ),
              new ListTile(
                leading: new Icon(MdiIcons.facebook),
                title: new Text('Add by Facebook'),
                onTap: () {
                  this.hideAddSheet();
                },
              ),
              new ListTile(
                leading: new Icon(Icons.phone),
                title: new Text('Add by Number'),
                onTap: () {
                  this.hideAddSheet();
                },
              ),
            ],
          ));
    };
  }

  hideAddSheet() {
    if (!_sheetShown) return;

    Navigator.pop(this._scaffoldKey.currentContext);
    setState(() {
      this._sheetShown = false;
    });
  }
  updateGroup() async{
    this.hideAddSheet();

    setState(() {
      this._sheetShown = false;
      this._isEditing = false;
    });
    if (_textController.text.isEmpty) {
      final wordPair = WordPair.random();
      _textController.text = wordPair.asPascalCase;
    }

    this.group.name = _textController.text;
    await Firestore.instance.collection("groups").document(this.group.reference.documentID).updateData(this.group.toJson());

    this._scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Group successfully updated!'),
        backgroundColor: Theme.of(context).primaryColor));
  }
}
class Group {
  String name;
  String location;
  DateTime time;
  String owner;
  GeoPoint geoPoint;
  double distance;
  DocumentReference reference;

  Group();

  Map<String, dynamic> toJson() =>
      {
        'name': name,
        'location': location,
        'time': time,
        'owner': owner,
        'geoPoint': geoPoint
      };

  Group.fromMap(Map<String, dynamic> map, {this.reference})
      : name = map['name'],
        location = map['location'],
        time = map['time'],
        geoPoint = map['geoPoint'],
        owner = map['owner'];

  Group.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);

  @override
  String toString() => "Group <$name> <$location> <$time> <$owner> <$geoPoint> <$distance>";

}
