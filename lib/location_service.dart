import 'dart:async';

import 'package:geocoder/geocoder.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:rxdart/rxdart.dart';
import 'package:location/location.dart';

class LocationService{
  static final LocationService _singleton = new LocationService._internal();
  int _countryCodeCounter = 10;
  final Location _locationService = new Location();

  final _locationController = BehaviorSubject<LocationData>();
  BehaviorSubject<LocationData> get locationListener => _locationController.stream;



  factory LocationService() {
    return _singleton;
  }

  Timer updateTimer;
  LocationService._internal() {
    const time = const Duration(seconds: 10);
    updateTimer = new Timer.periodic(time, (Timer t) {
      _updateLocation();
    });
  }

  _updateLocation() async{
    LocationData currentLocation = await _locationService.getLocation();
    if(_countryCodeCounter >= 10 || UserData.countryCode == null){
      List<Address> addresses = await Geocoder.local.findAddressesFromCoordinates(new Coordinates(currentLocation.latitude,currentLocation.longitude));
      UserData.countryCode = addresses.first.countryCode;
      _countryCodeCounter = 0;
    }
    _countryCodeCounter++;

    _locationController.add(await _locationService.getLocation());
    //_updateLocationSink.add(null);
    //_location.
  }

  shutdown(){
    updateTimer?.cancel();
    _locationController?.close();
  }

}