import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:ojol_customer_app/helper/general_helper.dart';

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
  BitmapDescriptor startLocationIcon;
  BitmapDescriptor destinationIcon;
  BitmapDescriptor pinMarkerIcon;
  
  Location location = Location();
  LocationData currentLocation;
  LocationData originLocation;
  LocationData destinationLocation;

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
    // destinationLocation = LocationData.fromMap({
    //   "latitude": DEST_LOCATION.latitude,
    //   "longitude": DEST_LOCATION.longitude
    // });
  }

  void setMarkerIcon() async {
    driverIcon = await getBitmapDescriptorFromAssetBytes("assets/marker_driver.png", 100);
  
    startLocationIcon = await getBitmapDescriptorFromAssetBytes("assets/marker_start.png", 100);
    
    destinationIcon = await getBitmapDescriptorFromAssetBytes("assets/marker_destination.png", 100);
    
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
                  Text("Lokasi kamu sekarang"),
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
                  destinationLocation != null ? Text("Lokasi Antar") : Text("Cari lokasi tujuan", style: TextStyle(color: Colors.grey)),
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
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      // setDriverMarker();
                    },
                    onCameraMove: (position) {
                      print(position.target.latitude);
                      print(position.target.longitude);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => moveToCurrentLocation(),
        mini: true,
        backgroundColor: Colors.white,
        child: Icon(Icons.my_location, color: Colors.blue),
        elevation: 1,
      ),
    );
  }

  moveToCurrentLocation() async {
    currentLocation = await location.getLocation();
    CameraPosition cPosition = CameraPosition(
      zoom: CAMERA_ZOOM,
      target: LatLng(currentLocation.latitude, currentLocation.longitude),
    );

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(cPosition));

    setState(() {
      var pinPosition = LatLng(currentLocation.latitude, currentLocation.longitude);
      _markers.removeWhere((m) => m.markerId.value == "pinMarker");
      _markers.add(Marker(
        markerId: MarkerId("pinMarker"),
        anchor: Offset(0,0),
        position: pinPosition,
        icon: pinMarkerIcon
      ));
    });
  }

}