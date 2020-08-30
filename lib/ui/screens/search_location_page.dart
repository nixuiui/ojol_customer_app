import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:search_map_place/search_map_place.dart';

class SearchLocationPage extends StatefulWidget {
  @override
  _SearchLocationPageState createState() => _SearchLocationPageState();
}

class _SearchLocationPageState extends State<SearchLocationPage> {

  String googleAPIKey = "AIzaSyCbEHsXGfuijWMzS2YxPk8Tls8BdqWVwaA";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: MediaQuery.of(context).size.width,
          child: SearchMapPlaceWidget(
            apiKey: googleAPIKey,
            onSelected: (Place place) async {
              final geolocation = await place.geolocation;
              var location = LocationData.fromMap({
                "latitude": geolocation.coordinates.latitude,
                "longitude": geolocation.coordinates.longitude
              });
              Navigator.of(context).pop({"location": location});
            },
          ),
        ),
      ),
    );
  }
}