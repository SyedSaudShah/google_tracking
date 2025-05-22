// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;
import 'package:geolocator/geolocator.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final Location _location = Location();
  Stream<LocationData>? _locationStream;
  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<DocumentSnapshot>? _approvalSubscription;
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  LatLng? _lastLatLng;
  double _totalDistance = 0.0;
  double _maxDistance = 0.0;
  String activity = 'car';
  String? clientId;
  bool _isApproved = false;
  bool _isLoading = true;
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
    print('Client ID initialized: $clientId'); // Debug

    // Force send request to pending when app starts
    await _sendPendingRequest();
    await _checkApprovalStatus();
    _startListeningForApproval();
  }

  Future<void> _sendPendingRequest() async {
    try {
      print('Sending pending request for client: $clientId'); // Debug

      await FirebaseFirestore.instance
          .collection('pending_clients')
          .doc(clientId)
          .set({
            'timestamp': Timestamp.now(),
            'clientId': clientId,
            'status': 'pending',
            'deviceInfo': 'Flutter App',
            'requestTime': DateTime.now().toIso8601String(),
            'appVersion': '1.0.0',
            'lastSeen': Timestamp.now(),
          }, SetOptions(merge: true));

      print('Successfully sent pending request'); // Debug
    } catch (e) {
      print('Error sending pending request: $e'); // Debug
    }
  }

  Future<void> _checkApprovalStatus() async {
    try {
      print('Checking approval for client: $clientId'); // Debug log

      final doc =
          await FirebaseFirestore.instance
              .collection('approved_clients')
              .doc(clientId)
              .get();

      if (doc.exists) {
        print('Client is approved!'); // Debug log
        _isApproved = true;
        _maxDistance = (doc.data()?['maxDistanceKm'] ?? 0.0).toDouble();
        _checkPermissionsAndStart();
      } else {
        print('Client not approved, adding to pending...'); // Debug log

        // Always try to add to pending_clients to ensure it's there
        await FirebaseFirestore.instance
            .collection('pending_clients')
            .doc(clientId)
            .set({
              'timestamp': Timestamp.now(),
              'clientId': clientId,
              'status': 'pending',
              'deviceInfo': 'Flutter App',
              'requestTime': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true)); // Use merge to avoid overwriting

        print('Added to pending_clients collection'); // Debug log
        _isApproved = false;
      }
    } catch (e) {
      print('Error checking approval status: $e');
      _isApproved = false;
    }

    _isLoading = false;
    if (mounted) setState(() {});
  }

  void _startListeningForApproval() {
    _approvalSubscription = FirebaseFirestore.instance
        .collection('approved_clients')
        .doc(clientId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && !_isApproved) {
            _isApproved = true;
            _maxDistance = (doc.data()?['maxDistanceKm'] ?? 0.0).toDouble();
            _checkPermissionsAndStart();
            if (mounted) setState(() {});

            // Show approval notification
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Approved! Max travel: ${_maxDistance.toStringAsFixed(1)} km',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
  }

  void _checkPermissionsAndStart() async {
    if (!_isApproved) return;

    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    if (!serviceEnabled) return;

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
        final newLatLng = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );

        // Distance calculation
        if (_lastLatLng != null) {
          final distance =
              Geolocator.distanceBetween(
                _lastLatLng!.latitude,
                _lastLatLng!.longitude,
                newLatLng.latitude,
                newLatLng.longitude,
              ) /
              1000.0;
          _totalDistance += distance;
        }
        _lastLatLng = newLatLng;

        // Check if exceeded max distance
        if (_totalDistance > _maxDistance) {
          _showMaxDistanceReached();
          return;
        }

        if (now.difference(_lastSent).inSeconds >= 5) {
          _currentLatLng = newLatLng;
          _lastSent = now;

          _sendToFirebase(_currentLatLng!);

          if (_mapController != null && mounted) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(_currentLatLng!),
            );
          }

          if (mounted) setState(() {});
        }
      }
    });
  }

  void _showMaxDistanceReached() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Distance Limit Reached'),
            content: Text(
              'You have traveled ${_maxDistance.toStringAsFixed(1)} km, which is your maximum allowed distance.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Stop location tracking
                  _locationSubscription?.cancel();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _sendToFirebase(LatLng position) async {
    if (clientId == null || !_isApproved) return;
    activity = ['car', 'bike', 'walk'][DateTime.now().second % 3];

    await FirebaseFirestore.instance.collection('locations').doc(clientId).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'activity': activity,
      'timestamp': Timestamp.now(),
      'totalDistance': _totalDistance,
      'maxDistance': _maxDistance,
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _approvalSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Widget _buildWaitingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.hourglass_empty,
                  size: 50,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Waiting for Admin Approval',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                'Your request has been sent to the administrator.\nPlease wait for approval to start tracking.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (clientId != null)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Client ID:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        clientId!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () async {
                  _isLoading = true;
                  setState(() {});
                  await _sendPendingRequest(); // Resend pending request
                  await _checkApprovalStatus();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Debug info button
              TextButton(
                onPressed: () async {
                  // Test Firebase connection
                  try {
                    await FirebaseFirestore.instance
                        .collection('test')
                        .doc('connection')
                        .set({'timestamp': Timestamp.now()});

                    showDialog(
                      // ignore: use_build_context_synchronously
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Debug Info'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Client ID: $clientId'),
                                Text('Is Approved: $_isApproved'),
                                Text('Is Loading: $_isLoading'),
                                const Text('Firebase: Connected ✓'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                    );
                  } catch (e) {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Debug Info'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Client ID: $clientId'),
                                Text('Is Approved: $_isApproved'),
                                Text('Is Loading: $_isLoading'),
                                Text('Firebase Error: $e'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                    );
                  }
                },
                child: const Text(
                  'Debug Info',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracking'),
        backgroundColor: Colors.green,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                '${_totalDistance.toStringAsFixed(2)}/${_maxDistance.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
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
                    infoWindow: InfoWindow(
                      title: "Your Location ($activity)",
                      snippet:
                          "Distance: ${_totalDistance.toStringAsFixed(2)} km / ${_maxDistance.toStringAsFixed(1)} km",
                    ),
                  ),
                },
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isApproved) {
      return _buildWaitingScreen();
    }

    return _buildTrackingScreen();
  }
}
