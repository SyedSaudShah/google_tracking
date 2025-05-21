import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_tracking/Screen/client.dart';
import 'package:google_tracking/Screen/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCL4sh6jzxy5MLmITPTSXFiXLjqcUsujk4",
      appId: "1:336505251470:android:763f76667eea000cc58bdf",
      messagingSenderId: "336505251470",
      projectId: "fir-91fba",
    ),
  ); // Firebase initialization
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Tracker',
      debugShowCheckedModeBanner: false,
      home: const RoleSelectionScreen(),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Role")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text("Client"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientScreen()),
                );
              },
            ),
            ElevatedButton(
              child: const Text("Admin"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
