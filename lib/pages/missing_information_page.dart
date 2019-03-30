import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nudges_flutter/pages/Config.dart';
import 'package:nudges_flutter/util/user_data.dart';

class MissingInformationPage extends StatefulWidget {
  @override
  _MissingInformationPageState createState() =>
      new _MissingInformationPageState();
}

class _MissingInformationPageState extends State<MissingInformationPage> {
  DateTime birthday;

  int currentStep = 0;
  String _radioValue;
  final firstnameController = new TextEditingController();

  bool showGenderError = false;
  bool showBirthdayError = false;
  bool showNameError = false;
  @override
  void initState() {
    super.initState();
    Firestore.instance
        .collection("users")
        .document(UserData.uid)
        .get()
        .then((userData) {
      setState(() {
        firstnameController.text = userData.data["firstname"];
        _radioValue = userData.data["gender"].toString()[0].toUpperCase() +
            userData.data["gender"].toString().substring(1);
        birthday = userData.data["birthday"];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        appBar: new AppBar(title: Text("About You")),
        body: createStepper(context),
      ),
      onWillPop: () {
        _onWillPop();
      },
    );
  }

  bool _onWillPop() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    } else {
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
                      style:
                          TextStyle(color: Theme.of(context).primaryColorLight),
                    )
                  ])),
              content: new Text(
                  "For this app to work, we need some very basic information about you. Please fill out all the required information."),
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
    return true;
  }

  List<Step> steps() {
    return [
      Step(
          title: Text("Firstname"),
          subtitle: firstnameController.text != ""
              ? Text(firstnameController.text)
              : null,
          state: firstnameController.text == ""
              ? StepState.indexed
              : StepState.complete,
          content: Column(children: [
            TextField(
                textCapitalization: TextCapitalization.words,
                controller: firstnameController),
            showNameError
                ? (Text("Please provide your firstname.",
                    style: TextStyle(color: Colors.red)))
                : Container()
          ]),
          isActive: currentStep >= 0),
      Step(
          title: Text("Gender"),
          subtitle: _radioValue != null ? Text(_radioValue) : null,
          state: _radioValue == null ? StepState.indexed : StepState.complete,
          content: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              new Container(
                  child: Row(children: [
                new Text('Female:'),
                new Radio(
                  value: "Female",
                  groupValue: _radioValue,
                  onChanged: _handleRadioValueChange,
                ),
              ])),
              new Container(
                  child: Row(children: [
                new Text('Male:'),
                new Radio(
                  value: "Male",
                  groupValue: _radioValue,
                  onChanged: _handleRadioValueChange,
                ),
              ])),
            ]),
            showGenderError
                ? (Text("Please provide your gender.",
                    style: TextStyle(color: Colors.red)))
                : Container(),
          ]),
          isActive: currentStep >= 1),
      Step(
          title: Text("Birthday"),
          subtitle: birthday != null
              ? Text(Config.toDate(birthday), overflow: TextOverflow.fade)
              : null,
          state: birthday == null ? StepState.indexed : StepState.complete,
          content: Column(children: [
            FlatButton(
            child: birthday != null
            ? Text(Config.toDate(birthday))
                : Text("Set Birthday"),
            onPressed: () {
            this.showDateTimeWindow(context);
            }),
            showBirthdayError
                ? (Text("Please provide your birthday.",
                style: TextStyle(color: Colors.red)))
                : Container(),
          ]),
          isActive: currentStep >= 2),
    ];
  }

  void _handleRadioValueChange(String value) {
    setState(() {
      _radioValue = value;
      print(value);
      showGenderError = false;
      switch (_radioValue) {
      }
    });
  }

  Widget createStepper(BuildContext context) {
    return new Stepper(
        currentStep: this.currentStep,
        controlsBuilder: (BuildContext context,
            {VoidCallback onStepContinue, VoidCallback onStepCancel}) {
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
          _onWillPop();
        },
        onStepContinue: () {
          setState(() {
            if (currentStep == 0) {
              if (firstnameController.text != "") {
                currentStep++;
                showNameError = false;
              } else
                showNameError = true;
            } else if (currentStep == 1) {
              if (_radioValue != null)
                currentStep++;
              else
                showGenderError = true;
            } else if (currentStep == 2) {
              if (birthday != null)
                this.submitData(context);
              else
                showBirthdayError = true;
            }
          });
        },
        steps: this.steps());
  }

  submitData(BuildContext context) async {
    await Firestore.instance
        .collection("users")
        .document(UserData.uid)
        .updateData({
      "gender": _radioValue.toLowerCase(),
      "firstname": firstnameController.text.toString(),
      "birthday": birthday
    });
    Navigator.pop(context);
  }

  showDateTimeWindow(BuildContext context) async {
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().subtract(new Duration(days: 366 * 16)),
        firstDate: DateTime.now().subtract(new Duration(days: 366 * 100)),
        lastDate: DateTime.now().subtract(new Duration(days: 366 * 16)),
        initialDatePickerMode: DatePickerMode.day);

    if (date != null) {
      setState(() {
        this.birthday = date;
        this.showBirthdayError = false;
      });
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    firstnameController.dispose();
    super.dispose();
  }
}
