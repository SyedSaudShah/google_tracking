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
  final Map<String, TextEditingController> _controllers = {};
  bool hasMovedCamera = false;

  void _updateMarkers(List<QueryDocumentSnapshot> documents) {
    _markers.clear();
    for (var doc in documents) {
      final data = doc.data() as Map<String, dynamic>;
      final latLng = LatLng(
        data['latitude'] as double,
        data['longitude'] as double,
      );

      final totalDistance = data['totalDistance']?.toDouble() ?? 0.0;
      final maxDistance = data['maxDistance']?.toDouble() ?? 0.0;
      final activity = data['activity'] ?? 'unknown';

      final marker = Marker(
        markerId: MarkerId(doc.id),
        position: latLng,
        infoWindow: InfoWindow(
          title: 'Client: ${doc.id.substring(0, 8)}...',
          snippet:
              '$activity - ${totalDistance.toStringAsFixed(2)}/${maxDistance.toStringAsFixed(1)} km',
        ),
      );
      _markers[doc.id] = marker;
    }
    if (mounted) setState(() {});
  }

  Future<void> _approveClient(String clientId, double maxDistance) async {
    try {
      // Add to approved_clients
      await FirebaseFirestore.instance
          .collection('approved_clients')
          .doc(clientId)
          .set({
            'maxDistanceKm': maxDistance,
            'approvedAt': Timestamp.now(),
            'clientId': clientId,
          });

      // Remove from pending_clients
      await FirebaseFirestore.instance
          .collection('pending_clients')
          .doc(clientId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Client approved with ${maxDistance.toStringAsFixed(1)} km limit',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving client: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectClient(String clientId) async {
    try {
      await FirebaseFirestore.instance
          .collection('pending_clients')
          .doc(clientId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting client: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildLiveTrackingSection() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Live Client Tracking",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('locations').snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Chip(
                label: Text('$count Active'),
                backgroundColor: Colors.green[100],
                labelStyle: const TextStyle(fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Pending Client Approvals",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('pending_clients')
                    .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Chip(
                label: Text('$count Pending'),
                backgroundColor: Colors.orange[100],
                labelStyle: const TextStyle(fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('locations').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  'No active clients',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateMarkers(snapshot.data!.docs);
        });

        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(30.0444, 31.2357),
            zoom: 5,
          ),
          markers: _markers.values.toSet(),
          myLocationEnabled: true,
        );
      },
    );
  }

  Widget _buildPendingClientCard(QueryDocumentSnapshot doc) {
    final clientId = doc.id;
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;

    final controller = _controllers.putIfAbsent(
      clientId,
      () => TextEditingController(text: '10'),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client Info Row
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client ID: ${clientId.length > 12 ? "${clientId.substring(0, 12)}..." : clientId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          'Requested: ${timestamp.toDate().toString().substring(0, 16)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Row - Responsive Layout
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 400) {
                  // Wide layout - Row
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Max Distance (km)",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildApproveButton(clientId, controller),
                      const SizedBox(width: 8),
                      _buildRejectButton(clientId),
                    ],
                  );
                } else {
                  // Narrow layout - Column
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Max Distance (km)",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildApproveButton(clientId, controller),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _buildRejectButton(clientId)),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproveButton(
    String clientId,
    TextEditingController controller,
  ) {
    return ElevatedButton.icon(
      onPressed: () async {
        final input = controller.text.trim();
        if (input.isEmpty || double.tryParse(input) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enter a valid number"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final maxDistance = double.parse(input);
        if (maxDistance <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Distance must be greater than 0"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await _approveClient(clientId, maxDistance);
        _controllers.remove(clientId);
      },
      icon: const Icon(Icons.check, size: 18),
      label: const Text("Approve", style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
      ),
    );
  }

  Widget _buildRejectButton(String clientId) {
    return ElevatedButton.icon(
      onPressed: () async {
        final shouldReject = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Reject Client'),
                content: const Text(
                  'Are you sure you want to reject this client request?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Reject'),
                  ),
                ],
              ),
        );

        if (shouldReject == true) {
          await _rejectClient(clientId);
          _controllers.remove(clientId);
        }
      },
      icon: const Icon(Icons.close, size: 18),
      label: const Text("Reject", style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
      ),
    );
  }

  Widget _buildPendingClientsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('pending_clients')
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        print('StreamBuilder called - hasData: ${snapshot.hasData}');
        if (snapshot.hasError) {
          print('Stream error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 50, color: Colors.red),
                const SizedBox(height: 10),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        print('Documents count: ${snapshot.data!.docs.length}');

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox, size: 50, color: Colors.grey),
                const SizedBox(height: 10),
                const Text(
                  "No pending approvals",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            print('Rendering client: ${doc.id}');
            return _buildPendingClientCard(doc);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.blue,
        elevation: 2,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Mobile Layout (Portrait)
          if (constraints.maxWidth < 768) {
            return Column(
              children: [
                _buildLiveTrackingSection(),
                Expanded(flex: 2, child: _buildMapSection()),
                const Divider(thickness: 2),
                _buildPendingSection(),
                Expanded(flex: 3, child: _buildPendingClientsSection()),
              ],
            );
          }
          // Tablet/Desktop Layout
          else {
            return Row(
              children: [
                // Left side - Live tracking
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildLiveTrackingSection(),
                      Expanded(child: _buildMapSection()),
                    ],
                  ),
                ),
                const VerticalDivider(thickness: 2),
                // Right side - Pending approvals
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildPendingSection(),
                      Expanded(child: _buildPendingClientsSection()),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
