import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final Map<String, Marker> _markers = {};
  GoogleMapController? _mapController;
  bool _hasMovedCamera = false;

  void _updateMarkers(List<QueryDocumentSnapshot> docs) {
    final updatedMarkers = <String, Marker>{};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final LatLng position = LatLng(data['latitude'], data['longitude']);
      final activity = data['activity'];
      final clientId = doc.id;

      BitmapDescriptor icon;
      if (activity == 'car') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      } else if (activity == 'bike') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }

      updatedMarkers[clientId] = Marker(
        markerId: MarkerId(clientId),
        position: position,
        icon: icon,
        infoWindow: InfoWindow(title: "$clientId: $activity"),
      );

      if (!_hasMovedCamera && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
        _hasMovedCamera = true;
      }
    }

    setState(() {
      _markers.clear();
      _markers.addAll(updatedMarkers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin View")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('locations').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Instead of calling setState inside addPostFrameCallback, call here safely
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateMarkers(snapshot.data!.docs);
            }
          });

          return GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(30.0444, 31.2357), // Cairo default
              zoom: 5,
            ),
            markers: _markers.values.toSet(),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );
        },
      ),
    );
  }
}
