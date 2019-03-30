import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:nudges_flutter/pages/Config.dart';
import 'package:nudges_flutter/pages/showgroup_page.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:nudges_flutter/util/SecretLoader.dart';

class NewGroupPage extends StatefulWidget {
  @override
  _NewGroupPageState createState() => new _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {

  final nameController = new TextEditingController();

  bool showNameError = false;
  bool showLocationError = false;
  bool showTimeError = false;

  Secret _secret;
  dynamic _places;
  int currentStep = 0;

  Group group = new Group();

  void initState(){
    super.initState();
    loadKey();
  }

  void loadKey() async{
    _secret = await SecretLoader(secretPath: "secrets.json").load();
    _places = new GoogleMapsPlaces(apiKey:_secret.kGoogleMapsApiKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(title: Text("Creating a new Group")),
        body: createStepper(context),
    );
  }
  List<Step> steps() {
    return [Step(
        title: Text("Name of the Group"),
        subtitle: nameController.text!=""?Text(nameController.text):null,
        state: nameController.text==""?StepState.indexed:StepState.complete,
        content: Column(children:[

        TextField(
        textCapitalization: TextCapitalization.words,
            controller: nameController),
        showNameError
            ? (Text("Please provide a groupname.",
            style: TextStyle(color: Colors.red)))
            : Container()
        ]),

        isActive: currentStep >= 0
    ),
    Step(
        title: Text("Location"),
        subtitle: group.location!=null?Text(group.location,overflow: TextOverflow.fade):null,
        state: group.location==null?StepState.indexed:StepState.complete,
        content: Column(children: [
        FlatButton(child:group.location!=null?Text(group.location):Text("Change Location"), onPressed: () {
          this.showPlacesWindow(context);
          }),
        showLocationError?(Text("Please provide a location.",style: TextStyle(color: Colors.red))):Container(),
        ]

        ),
        isActive: currentStep >= 1
    ),
    Step(
        title: Text("Time"),
        subtitle: group.time!=null?Text(Config.toDateTime(group.time),overflow: TextOverflow.fade):null,
        state: group.time==null?StepState.indexed:StepState.complete,
        content: Column(
          children: [
          FlatButton(child:group.time!=null?Text(Config.toDateTime(group.time)):Text("Change Time"), onPressed: () {
          this.showDateTimeWindow(context);
          }),
          showTimeError?(Text("Please provide a time.",style: TextStyle(color: Colors.red))):new Container(),
          ]

        ),
        isActive: currentStep >= 2
    ),
    ];
  }

  Widget createStepper(BuildContext context){
    return new Stepper(
        currentStep: this.currentStep,
        controlsBuilder: (BuildContext context, {VoidCallback onStepContinue, VoidCallback onStepCancel}) {
          return Row(
            children: <Widget>[
              RaisedButton(
                onPressed: onStepContinue,
                child: const Text('Continue'),
              ),
              FlatButton(
                onPressed: onStepCancel,
                child: const Text('Back'),
              ),
            ],
          );
        },
        onStepCancel: () {
          setState(() {
            if(currentStep > 0)
              currentStep--;
            else
              Navigator.pop(context);
          });
        },
        onStepContinue: () {
          setState(() {
            if (currentStep == 0){
              if(nameController.text != ""){
                currentStep++;
                showNameError = false;
              }
              else
                showNameError = true;
            } else if(currentStep == 1){
              if(group.location != null)
                currentStep++;
              else
                showLocationError = true;
            }else if(currentStep == 2){
              if(group.time != null)
                this.submitGroup();
              else
                showTimeError = true;
            }
          });
        },
        steps: this.steps()
    );
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
        showLocationError = false;
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
        this.showTimeError = false;
      });
    }
  }

  submitGroup() async{
    this.group.name = nameController.text;
    await Firestore.instance.collection("groups").document(UserData.uid).setData(this.group.toJson());
    await Firestore.instance.collection("users").document(UserData.uid).collection("groups").document(UserData.uid).setData(
        {
          "lastActivity":new DateTime.now(),
          "lastMessage": null,
          "isPublic": this.group.isPublic,
          "location":this.group.location,
          "time":this.group.time,
          "senderName":UserData.name,
          "groupName":nameController.text
        }
    );
    await Firestore.instance.collection("groups").document(UserData.uid).collection("members").document(UserData.uid).setData({
      "numMessages":0,
      "dateJoined":new DateTime.now(),
      "lastActivity":new DateTime.now(),
      "name": UserData.name,
      "imageURL": UserData.photoURL
    });
    Navigator.pop(context);
    Navigator.of(context).push(new MaterialPageRoute(
        builder: (context) => new ShowGroupPage(groupId: UserData.uid)));
  }

  @override
  void dispose() {
    // TODO: implement dispose
    nameController.dispose();
    _places.dispose();
    super.dispose();
  }
}
class Group {
  String name;
  String location;
  DateTime time;
  bool isPublic = false;
  GeoPoint geoPoint;
  double distance;
  DocumentReference reference;

  Group();

  Map<String, dynamic> toJson() =>
      {
        'name': name,
        'location': location,
        'time': time,
        'isPublic': isPublic,
        'geoPoint': geoPoint
      };

  Group.fromMap(Map<String, dynamic> map, {this.reference})
      : name = map['name'],
        location = map['location'],
        isPublic = map['isPublic'],
        time = map['time'],
        geoPoint = map['geoPoint'];

  Group.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);

  @override
  String toString() => "Group <$name> <$location> <$isPublic ><$time> <$geoPoint> <$distance>";

}
