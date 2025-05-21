import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final Location _location = Location();
  Stream<LocationData>? _locationStream;
  StreamSubscription<LocationData>? _locationSubscription;
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  String activity = 'car'; // simulate activity (can be bike/walk later)
  String? clientId;
  DateTime _lastSent = DateTime.now().subtract(const Duration(seconds: 10));

  @override
  void initState() {
    super.initState();
    _initClientId();
  }

  Future<void> _initClientId() async {
    final prefs = await SharedPreferences.getInstance();
    clientId = prefs.getString('client_id');
    if (clientId == null) {
      clientId = const uuid_pkg.Uuid().v4();
      await prefs.setString('client_id', clientId!);
    }
    _checkPermissionsAndStart();
  }

  void _checkPermissionsAndStart() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    _location.changeSettings(interval: 5000);
    _locationStream = _location.onLocationChanged;

    _locationSubscription = _locationStream!.listen((locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        final now = DateTime.now();
        if (now.difference(_lastSent).inSeconds >= 5) {
          _currentLatLng = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
          _lastSent = now;

          _sendToFirebase(_currentLatLng!);

          if (_mapController != null && mounted) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(_currentLatLng!),
            );
          }

          if (mounted) {
            setState(() {});
          }
        }
      }
    });
  }

  void _sendToFirebase(LatLng position) async {
    if (clientId == null) return;

    // Simulate changing activity randomly
    activity = ['car', 'bike', 'walk'][DateTime.now().second % 3];

    print("Sending to Firebase: $position ($activity)");

    await FirebaseFirestore.instance.collection('locations').doc(clientId).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'activity': activity,
      'timestamp': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _locationSubscription?.cancel(); // Clean up the stream
    _mapController?.dispose(); // Dispose map controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Tracking')),
      body:
          _currentLatLng == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLatLng!,
                  zoom: 16,
                ),
                onMapCreated: (controller) => _mapController = controller,
                myLocationEnabled: true,
                markers: {
                  Marker(
                    markerId: const MarkerId('client'),
                    position: _currentLatLng!,
                    infoWindow: InfoWindow(title: "You're here ($activity)"),
                  ),
                },
              ),
    );
  }
}
