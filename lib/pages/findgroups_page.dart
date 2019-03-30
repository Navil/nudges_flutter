import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_helpers/firestore_helpers.dart';
import 'package:nudges_flutter/location_service.dart';
import 'package:nudges_flutter/pages/showgroup_page.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:geocoder/geocoder.dart';

class FindGroupsPage extends StatefulWidget {
  @override
  _FindGroupsState createState() => new _FindGroupsState();
}

class _FindGroupsState extends State<FindGroupsPage> with AutomaticKeepAliveClientMixin<FindGroupsPage>{
  @override
  bool get wantKeepAlive => UserData.uid != null;

  StreamSubscription<LocationData> locationSubscription;
  GoogleMapController mapController;
  StreamSubscription<List<Group>> geoSubscription;
  LocationData currentLocation;
  double radius = 10.0;

  Marker myMarker;
  Map<String, Marker> groupMarkers;

  @override
  initState() {
    // Add listeners to this class
    super.initState();
    print("INITSTATE");

    if(locationSubscription == null){
      print("Starting subscription");
      locationSubscription = LocationService().locationListener.listen( (data) {
        //print("Got Data "+data.toString());
        setState(() {
          this.currentLocation = data;
          setupMap();
        });
      });
    }
  }

  Stream<List<Group>> getGroups(Area area) {
    try {
      return getDataInArea(
          source: Firestore.instance.collection("groups"),
          area: area,
          locationFieldNameInDB: 'geoPoint',
          mapper: (groupDoc) {
            var group = Group.fromSnapshot(groupDoc);
            print(groupDoc.reference.path+" "+groupDoc.exists.toString());
            // if you serializer does not pass types like GeoPoint through
            // you have to add that fields manually. If using `jaguar_serializer`
            // add @pass attribute to the GeoPoint field and you can omit this.
            return group;
          },
          locationAccessor: (groupData) => groupData.geoPoint,
          distanceMapper: (groupData, distance) {
            groupData.distance = distance;
            return groupData;
          },
          distanceAccessor: (groupData) => groupData.distance,
          serverSideConstraints: [
            QueryConstraint(field: "isPublic", isEqualTo: true)
          ]
          // filer only future events
          );
    } on Exception catch (ex) {
      print(ex);
    }
    return null;
  }

  setupMap() async {

    //print("Got Location " + this.currentLocation.toString());
    if (this.groupMarkers == null) {
      this.groupMarkers = new Map();
      this.geoSubscription = this
          .getGroups(Area(this.positionToGeoPoint(), this.radius))
          .listen((data) {
            print("Received new list with size "+data.length.toString());
        data.forEach((group) async {
          print("Got Id: " + group.toString());
          if (this.groupMarkers[group.reference.documentID] == null) {
            print("Adding " + group.reference.documentID);

            this.groupMarkers[group.reference.documentID] = await this
                .mapController
                .addMarker(MarkerOptions(
                    position: LatLng(
                        group.geoPoint.latitude, group.geoPoint.longitude)));
          } else {
            print("Updating " + group.reference.documentID);
            this.groupMarkers[group.reference.documentID] = await this
                .mapController
                .addMarker(MarkerOptions(
                    position: LatLng(
                        group.geoPoint.latitude, group.geoPoint.longitude)));
          }
        });
      }, onDone: () {
        print("Task Done");
      }, onError: (error) {
        print("Some Error");
      });
    }
    this.updatePosition();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: Text('Nearby Groups')),
      body: Column(
          children: [
            SizedBox(height: 5.0),
        Row(children: <Widget>[
          Expanded(child:
            Slider(
              value: this.radius,
              min: 1.0,
              max: 50.0,
              divisions: 49,
              onChanged: (double newValue) {
                setState(() {
                  this.radius = newValue.round().toDouble();
                });
              },
              onChangeEnd: (double newValue) => updateRadius(newValue),)
          ),Text('${radius.toInt()}' + " km "),
        ]),
        FlatButton(child: Text("Change Location"), onPressed: () {},),
        Expanded(
            child: GoogleMap(
                onMapCreated: (GoogleMapController controller) =>
                    _onMapCreated(controller),
                options: GoogleMapOptions(
                    tiltGesturesEnabled: false, rotateGesturesEnabled: false, myLocationEnabled: true)))
      ]),
    );
  }


  void updateRadius(double newRadius) async {
    if (this.myMarker != null) {
      this.mapController.updateMarker(
          this.myMarker,
          MarkerOptions(
            alpha: 1.0,
            position: this.positionToLatLng(),
            infoWindowText: InfoWindowText("Hallo", "Hallo Welt"),
          ));
    } else {
      this.myMarker = await this.mapController.addMarker(MarkerOptions(
            alpha: 1.0,
            position: this.positionToLatLng(),
            infoWindowText: InfoWindowText("Hallo", "Hallo Welt"),
          ));
    }
  }

  LatLng positionToLatLng() {

    return (this.currentLocation == null )?null:LatLng(
        this.currentLocation["latitude"], currentLocation["longitude"]);
  }

  GeoPoint positionToGeoPoint() {
    return (this.currentLocation == null )?null:GeoPoint(
        this.currentLocation["latitude"], currentLocation["longitude"]);
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
      this.updatePosition();
    });
  }

  void updatePosition() {
    if (this.currentLocation != null && this.currentLocation.isNotEmpty) {
      this.moveToLocation();
    }
  }

  moveToLocation() {
    if (this.mapController == null) return;

    //print("Moving to Location!!");
    mapController.moveCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: this.positionToLatLng(),
        tilt: 30.0,
        zoom: 10.0,
      ),
    ));
  }

  @override
  void dispose() {
    print("DISPOSE");
    if(locationSubscription != null) {
      locationSubscription.cancel();
      locationSubscription = null;
    }

    this.mapController?.dispose();

    this.geoSubscription?.cancel();
    super.dispose();

  }
}
