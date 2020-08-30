import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:ojol_customer_app/helper/general_helper.dart';
import 'package:geocoder/geocoder.dart';

const double CAMERA_ZOOM = 16;
const double CAMERA_TILT = 80;
const double CAMERA_BEARING = 30;
const LatLng SOURCE_LOCATION = LatLng(-5.332469,105.285986);

class MapArea extends StatefulWidget {
  @override
  _MapAreaState createState() => _MapAreaState();
}

class _MapAreaState extends State<MapArea> {

  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPIKey = "AIzaSyCbEHsXGfuijWMzS2YxPk8Tls8BdqWVwaA";

  // for my custom marker pins
  BitmapDescriptor driverIcon;
  BitmapDescriptor originLocationIcon;
  BitmapDescriptor destinationLocationIcon;
  BitmapDescriptor pinMarkerIcon;

  bool isShowPinMarker = false;
  
  Location location = Location();
  LocationData currentLocation;

  LocationData originLocation;
  String originAddress;
  bool isOriginSearchingAddress = false;
  bool isSelectingOrigin = false;

  LocationData destinationLocation;
  String destinationAddress;
  bool isDestinationSearchingAddress = false;
  bool isSelectingDestination = false;

  @override
  void initState() {
    super.initState();
    setMarkerIcon();
    location.changeSettings(accuracy: LocationAccuracy.high);
    setInitialLocation();
  }
  
  void setInitialLocation() async {
    currentLocation = await location.getLocation();
    originLocation = await location.getLocation();
  }

  void setMarkerIcon() async {
    driverIcon = await getBitmapDescriptorFromAssetBytes("assets/marker_driver.png", 100);
    originLocationIcon = await getBitmapDescriptorFromAssetBytes("assets/marker_start.png", 100);
    destinationLocationIcon = await getBitmapDescriptorFromAssetBytes("assets/marker_destination.png", 100);
    pinMarkerIcon = await getBitmapDescriptorFromAssetBytes("assets/marker_pin.png", 100);
  }
  
  @override
  Widget build(BuildContext context) {
    CameraPosition initialCameraPosition = CameraPosition(
      zoom: CAMERA_ZOOM,
      tilt: CAMERA_TILT,
      bearing: CAMERA_BEARING,
      target: currentLocation != null ? LatLng(currentLocation.latitude, currentLocation.longitude) : SOURCE_LOCATION
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  isOriginSearchingAddress 
                    ? Text("Mencari Lokasi ...", style: TextStyle(color: Colors.grey))
                    : (originLocation != null 
                      ? Expanded(child: Text(originAddress ?? "", maxLines: 1, overflow: TextOverflow.ellipsis)) 
                      : Text("Cari lokasi jemput", style: TextStyle(color: Colors.grey)))
                ],
              ),
            ),
            Divider(height: 0),
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  isDestinationSearchingAddress 
                    ? Text("Mencari Lokasi ...", style: TextStyle(color: Colors.grey))
                    : (destinationLocation != null 
                      ? Expanded(child: Text(destinationAddress ?? "", maxLines: 1, overflow: TextOverflow.ellipsis)) 
                      : Text("Cari lokasi tujuan", style: TextStyle(color: Colors.grey)))
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    top: 20,
                    right: 20,
                    child: FloatingActionButton(
                      onPressed: (){},
                      mini: true,
                      child: Icon(Icons.my_location),
                    )
                  ),
                  GoogleMap(
                    mapType: MapType.normal,
                    zoomControlsEnabled: false,
                    initialCameraPosition: initialCameraPosition,
                    markers: _markers,
                    tiltGesturesEnabled: true,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      moveToCurrentLocation();
                    },
                    onCameraIdle: () async {
                      if(isSelectingOrigin) {
                        originAddress = await getCurrentAddress();
                        originLocation = LocationData.fromMap({
                          "latitude": currentLocation.latitude,
                          "longitude": currentLocation.longitude
                        });
                      }
                      if(isSelectingDestination) {
                        destinationAddress = await getCurrentAddress();
                        destinationLocation = LocationData.fromMap({
                          "latitude": currentLocation.latitude,
                          "longitude": currentLocation.longitude
                        });
                      }
                      setState(() {
                        isOriginSearchingAddress= false;
                        isDestinationSearchingAddress = false;
                      });
                    },
                    onCameraMoveStarted: () {
                      setState(() {
                        if(isSelectingOrigin) isOriginSearchingAddress = true;
                        if(isSelectingDestination) isDestinationSearchingAddress = true;
                      });
                    },
                    onCameraMove: (CameraPosition position) {
                      if(isShowPinMarker) {
                        setState(() {
                          currentLocation = LocationData.fromMap({
                            "latitude": position.target.latitude,
                            "longitude": position.target.longitude
                          });
                          var pinPosition = LatLng(position.target.latitude, position.target.longitude);
                          _markers.removeWhere((m) => m.markerId.value == "pinMarker");
                          _markers.add(Marker(
                            markerId: MarkerId("pinMarker"),
                            position: pinPosition,
                            icon: pinMarkerIcon
                          ));
                        });
                      }
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      color: Colors.white,
                      padding: EdgeInsets.all(8),
                      child: isSelectingOrigin || isSelectingDestination ? RaisedButton(
                        onPressed: () {
                          if(isSelectingOrigin) {
                            setState(() {
                              isSelectingOrigin = false;
                              isSelectingDestination = true;
                              setOriginMarker();
                            });
                          } else if(isSelectingDestination) {
                            setState(() {
                              isSelectingDestination = false;
                              setDestinationMarker();
                            });
                          }
                        },
                        color: Colors.orange,
                        textColor: Colors.white,
                        elevation: 0,
                        child: Text(isSelectingOrigin ? "SET LOKASI JEMPUT" : "SET LOKASI ANTAR"),
                      ) : RaisedButton(
                        onPressed: () => setState(() {
                          isSelectingOrigin = true;
                          isShowPinMarker = true;
                          moveToCurrentLocation();
                        }),
                        color: Colors.blue,
                        textColor: Colors.white,
                        elevation: 0,
                        child: Text("BUAT ORDER BARU"),
                      ),
                    )
                  )
                ],
              ),
            ),
          ],
        ),
      )
    );
  }

  moveToCurrentLocation({LocationData locationData}) async {
    currentLocation = await location.getLocation();

    if(locationData == null) locationData = currentLocation;
    CameraPosition cPosition = CameraPosition(
      zoom: CAMERA_ZOOM,
      target: LatLng(locationData.latitude, locationData.longitude),
    );

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(cPosition));

    if(isShowPinMarker) {
      setState(() {
        var pinPosition = LatLng(locationData.latitude, locationData.longitude);
        _markers.removeWhere((m) => m.markerId.value == "pinMarker");
        _markers.add(Marker(
          markerId: MarkerId("pinMarker"),
          position: pinPosition,
          icon: pinMarkerIcon
        ));
      });
    }
  }

  Future<String> getCurrentAddress() async {
    final coordinates = new Coordinates(currentLocation.latitude, currentLocation.longitude);
    var addresses = await Geocoder.local.findAddressesFromCoordinates(coordinates);
    var first = addresses.first;
    return first.addressLine;
  }

  void setOriginMarker() async {
    _markers.removeWhere((m) => m.markerId.value == "originMarker");
    _markers.add(Marker(
      markerId: MarkerId("originMarker"),
      position: LatLng(currentLocation.latitude, currentLocation.longitude),
      icon: originLocationIcon
    ));
  }
  
  void setDestinationMarker() async {
    _markers.removeWhere((m) => m.markerId.value == "destinationMarker");
    _markers.add(Marker(
      markerId: MarkerId("destinationMarker"),
      position: LatLng(currentLocation.latitude, currentLocation.longitude),
      icon: destinationLocationIcon
    ));
  }

}