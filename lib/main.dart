import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_tracking/Screen/client.dart';
import 'package:google_tracking/Screen/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCL4sh6jzxy5MLmITPTSXFiXLjqcUsujk4",
      appId: "1:336505251470:android:763f76667eea000cc58bdf",
      messagingSenderId: "336505251470",
      projectId: "fir-91fba",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 2,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 3,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder:
            (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isPrimary,
    required VoidCallback onTap,
    required bool isLandscape,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = isLandscape ? screenWidth * 0.4 : double.infinity;
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Card(
        elevation: isPrimary ? 8 : 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient:
                  isPrimary
                      ? LinearGradient(
                        colors: [color, color.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor:
                      isPrimary ? Colors.white24 : color.withOpacity(0.1),
                  child: Icon(icon, color: isPrimary ? Colors.white : color),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isPrimary ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isPrimary ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLandscape) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.location_on,
            size: isLandscape ? 50 : 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          Text(
            'Location Tracker Pro',
            style: TextStyle(
              fontSize: isLandscape ? 22 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your role to get started',
            style: TextStyle(
              fontSize: isLandscape ? 14 : 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(isLandscape),
                  Expanded(
                    child:
                        isLandscape
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCard(
                                  context: context,
                                  title: 'Client',
                                  subtitle:
                                      'Track your location and get real-time updates.',
                                  icon: Icons.person_outline,
                                  color: Colors.green,
                                  isPrimary: true,
                                  onTap:
                                      () => _navigate(
                                        context,
                                        const ClientScreen(),
                                      ),
                                  isLandscape: true,
                                ),
                                _buildCard(
                                  context: context,
                                  title: 'Administrator',
                                  subtitle:
                                      'Monitor and manage client tracking efficiently.',
                                  icon: Icons.admin_panel_settings,
                                  color: Colors.orange,
                                  isPrimary: false,
                                  onTap:
                                      () => _navigate(
                                        context,
                                        const AdminScreen(),
                                      ),
                                  isLandscape: true,
                                ),
                              ],
                            )
                            : ListView(
                              children: [
                                _buildCard(
                                  context: context,
                                  title: 'Client',
                                  subtitle:
                                      'Track your location and get real-time updates.',
                                  icon: Icons.person_outline,
                                  color: Colors.green,
                                  isPrimary: true,
                                  onTap:
                                      () => _navigate(
                                        context,
                                        const ClientScreen(),
                                      ),
                                  isLandscape: false,
                                ),
                                _buildCard(
                                  context: context,
                                  title: 'Administrator',
                                  subtitle:
                                      'Monitor and manage client tracking efficiently.',
                                  icon: Icons.admin_panel_settings,
                                  color: Colors.orange,
                                  isPrimary: false,
                                  onTap:
                                      () => _navigate(
                                        context,
                                        const AdminScreen(),
                                      ),
                                  isLandscape: false,
                                ),
                              ],
                            ),
                  ),
                  const SizedBox(height: 16),
                  // Text('v1.0.0', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
