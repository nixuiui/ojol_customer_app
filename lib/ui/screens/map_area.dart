import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:indonesia/indonesia.dart';
import 'package:location/location.dart';
import 'package:ojol_customer_app/helper/general_helper.dart';
import 'package:geocoder/geocoder.dart';
import 'package:ojol_customer_app/ui/screens/search_location_page.dart';
import 'package:search_map_place/search_map_place.dart';

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
  Set<Polyline> polylines = Set<Polyline>();
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPIKey = "AIzaSyCbEHsXGfuijWMzS2YxPk8Tls8BdqWVwaA";

  // for my custom marker pins
  BitmapDescriptor driverIcon;
  BitmapDescriptor originLocationIcon;
  BitmapDescriptor destinationLocationIcon;
  BitmapDescriptor pinMarkerIcon;

  double distance = 0;
  int cost = 0;
  bool isShowPinMarker = false;
  bool isReadyToCreateNewOrder = true;
  bool isReviewRouteBeforeOrder = false;
  
  Location location = Location();
  LocationData currentLocation;

  LocationData originLatLng;
  String originAddress;
  bool isOriginSearchingAddress = false;
  bool isSelectingOrigin = false;

  LocationData destinationLatLng;
  String destinationAddress;
  bool isDestinationSearchingAddress = false;
  bool isSelectingDestination = false;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    setMarkerIcon();
    setInitialLocation();
  }
  
  void setInitialLocation() async {
    currentLocation = await location.getLocation();
    originLatLng = await location.getLocation();
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
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.normal,
                    zoomControlsEnabled: false,
                    initialCameraPosition: initialCameraPosition,
                    markers: _markers,
                    tiltGesturesEnabled: true,
                    polylines: polylines,
                    myLocationEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      moveToCurrentLocation();
                    },
                    onCameraIdle: () async {
                      print("CAMERA IDLE");
                      if(isSelectingOrigin) {
                        originAddress = await getCurrentAddress();
                        originLatLng = LocationData.fromMap({
                          "latitude": currentLocation.latitude,
                          "longitude": currentLocation.longitude
                        });
                      }
                      if(isSelectingDestination) {
                        destinationAddress = await getCurrentAddress();
                        destinationLatLng = LocationData.fromMap({
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
                      currentLocation = LocationData.fromMap({
                        "latitude": position.target.latitude,
                        "longitude": position.target.longitude
                      });
                      if(isShowPinMarker) {
                        var pinPosition = LatLng(position.target.latitude, position.target.longitude);
                        _markers.removeWhere((m) => m.markerId.value == "pinMarker");
                        _markers.add(Marker(
                          markerId: MarkerId("pinMarker"),
                          position: pinPosition,
                          icon: pinMarkerIcon
                        ));
                      }
                      setState(() {});
                    },
                  ),
                  isSelectingOrigin || isSelectingDestination ? Container(
                    padding: EdgeInsets.all(16),
                    width: MediaQuery.of(context).size.width,
                    child: SearchMapPlaceWidget(
                      apiKey: googleAPIKey,
                      onSelected: (Place place) async {
                        final geolocation = await place.geolocation;
                        currentLocation = LocationData.fromMap({
                          "latitude": geolocation.coordinates.latitude,
                          "longitude": geolocation.coordinates.longitude
                        });
                        moveToCurrentLocation();
                      },
                    ),
                  ) : Container(),
                  isSelectingOrigin || isSelectingDestination ? Positioned(
                    bottom: 0,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      color: Colors.white,
                      padding: EdgeInsets.all(8),
                      child: RaisedButton(
                        onPressed: () async {
                          if(isSelectingOrigin) {
                            setState(() {
                              isSelectingOrigin = false;
                              isSelectingDestination = true;
                              setOriginMarker();
                            });
                          } else if(isSelectingDestination) {
                            distance = await countDistance();
                            cost = await countCost();
                            setState(() {
                              isLoading = true;
                              isSelectingDestination = false;
                              isShowPinMarker = false;
                              isReviewRouteBeforeOrder = true;
                              deleteMarkerById("pinMarker");
                              setDestinationMarker();
                              setPolylineOrder();
                            });
                          }
                        },
                        color: Colors.orange,
                        textColor: Colors.white,
                        elevation: 0,
                        child: Text(isSelectingOrigin ? "SET LOKASI JEMPUT" : "SET LOKASI ANTAR"),
                      ),
                    )
                  ) : Container(),
                  isReadyToCreateNewOrder ? Positioned(
                    bottom: 0,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      color: Colors.white,
                      padding: EdgeInsets.all(8),
                      child: RaisedButton(
                        onPressed: () => createNewOrder(),
                        color: Colors.blue,
                        textColor: Colors.white,
                        elevation: 0,
                        child: Text("BUAT ORDER BARU"),
                      ),
                    )
                  ) : Container(),
                  isReviewRouteBeforeOrder ? Positioned(
                    bottom: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: FloatingActionButton(
                            onPressed: () => cancelOrder(), 
                            child: Icon(Icons.close, color: Colors.black),
                            mini: true,
                            backgroundColor: Colors.white,
                            elevation: 1,
                          ),
                        ),
                        Container(
                          width: MediaQuery.of(context).size.width,
                          padding: EdgeInsets.all(16),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Icon(Icons.place, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Expanded(child: Text(originAddress ?? "", maxLines: 1, overflow: TextOverflow.ellipsis))
                            ],
                          ),
                        ),
                        Divider(height: 0),
                        Container(
                          width: MediaQuery.of(context).size.width,
                          padding: EdgeInsets.all(16),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Icon(Icons.place, size: 16, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(child: Text(destinationAddress ?? "", maxLines: 1, overflow: TextOverflow.ellipsis))
                            ],
                          ),
                        ),
                        Container(
                          width: MediaQuery.of(context).size.width,
                          color: Colors.white,
                          padding: EdgeInsets.all(8),
                          child: RaisedButton(
                            onPressed: () => createNewOrder(),
                            color: Colors.green,
                            textColor: Colors.white,
                            elevation: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("ORDER (${distance.toStringAsFixed(1)} Km)"),
                                Text(rupiah(cost)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  ) : Container()
                ],
              ),
            ),
          ],
        ),
      )
    );
  }

  deleteMarkerById(String id) {
    _markers.removeWhere((m) => m.markerId.value == id);
  }

  moveToCurrentLocation({LocationData locationData}) async {
    if(currentLocation == null) currentLocation = await location.getLocation();

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
        deleteMarkerById("pinMarker");
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
      position: LatLng(originLatLng.latitude, originLatLng.longitude),
      icon: originLocationIcon
    ));
  }
  
  void setDestinationMarker() async {
    _markers.removeWhere((m) => m.markerId.value == "destinationMarker");
    _markers.add(Marker(
      markerId: MarkerId("destinationMarker"),
      position: LatLng(destinationLatLng.latitude, destinationLatLng.longitude),
      icon: destinationLocationIcon
    ));
  }

  void setPolylineOrder() async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleAPIKey,
      PointLatLng(originLatLng.latitude, originLatLng.longitude),
      PointLatLng(destinationLatLng.latitude, destinationLatLng.longitude)
    );

    polylineCoordinates.clear();
    polylines.removeWhere((p) => p.polylineId.value == "orderRoute");
    if(result.points.isNotEmpty){
      result.points.forEach((PointLatLng point){
        polylineCoordinates.add(LatLng(point.latitude,point.longitude));
      });
      polylines.add(Polyline(
        width: 5,
        polylineId: PolylineId("orderRoute"),
        color: Color.fromARGB(255, 40, 122, 198), 
        points: polylineCoordinates
      ));
    }
    setState(() {});
  }

  void createNewOrder() async {
    originAddress = await getCurrentAddress();
    originLatLng = LocationData.fromMap({
      "latitude": currentLocation.latitude,
      "longitude": currentLocation.longitude
    });
    destinationLatLng = null;
    destinationAddress = null;
    isReadyToCreateNewOrder = false;
    polylines.clear();
    _markers.removeWhere((m) => m.markerId.value == "originMarker");
    _markers.removeWhere((m) => m.markerId.value == "destinationMarker");
    isSelectingOrigin = true;
    isShowPinMarker = true;
    moveToCurrentLocation();
  }

  searchAddress() async {
    Map results = await Navigator.push(context, MaterialPageRoute(builder: (context) => SearchLocationPage()));

    if (results != null && results.containsKey("location")) {
      currentLocation = results["location"];
      moveToCurrentLocation();
    }
  }

  countDistance() async {
    double distance = await Geolocator().distanceBetween(
      originLatLng.latitude,
      originLatLng.longitude,
      destinationLatLng.latitude,
      destinationLatLng.longitude,
    );
    return distance/1000;
  }
  
  countCost() async {
    int cost = 9000;
    double distance = await countDistance();
    if(distance > 5){
      print(distance);
      print(distance.ceil());
      int additionalCost = (distance.round() - 5)*3000;
      cost += additionalCost;
    }
    return cost;
  }

  cancelOrder() {
    setState(() {
      originAddress = null;
      originLatLng = null;
      destinationLatLng = null;
      destinationAddress = null;
      isReviewRouteBeforeOrder = false;
      isReadyToCreateNewOrder = true;
      polylines.clear();
      _markers.removeWhere((m) => m.markerId.value == "originMarker");
      _markers.removeWhere((m) => m.markerId.value == "destinationMarker");
      isSelectingOrigin = false;
      isShowPinMarker = false;
    });
  }

}