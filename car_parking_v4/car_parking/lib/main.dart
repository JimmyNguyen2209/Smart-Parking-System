import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:car_parking/screens/scan_in_screen.dart';
import 'package:car_parking/screens/scan_out_screen.dart';
import 'package:car_parking/screens/parking_spot_screen.dart';

import 'package:car_parking/services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();           // Đảm bảo Flutter đã khởi tạo
  await Firebase.initializeApp();                      // Đợi Firebase khởi tạo xong

  final firebaseService = FirebaseService();           // Tạo đối tượng từ Constructor FirebaseService()
  await firebaseService.initializeParkingSpots(10);    // Đợi Khởi tạo danh sách chỗ đỗ xe

  runApp(ParkingApp());                                // Chạy ứng dụng
}

// Widget ParkingApp - Khung ứng dụng
class ParkingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),                   // HomeScreen
      debugShowCheckedModeBanner: false
    );
  }
}

// Widget HomeScreen - Chuyển đổi qua lại 3 Tab
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

// HomeScreen State
class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Danh sách Màn hình
  // Đối tượng _screens gọi 3 Widget, chọn bằng index
  final List<Widget> _screens = [
    ScanInScreen(),                
    ParkingSpotScreen(),
    ScanOutScreen(),
  ];

  // Phương thức chuyển màn hình
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Giao diện Màn hình chính
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // AppBar
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA5),
        title: const Text(
          'Smart Parking System',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),

      // Body
      body: _screens[_selectedIndex],

      // Bottom
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Xe vào'),
          BottomNavigationBarItem(icon: Icon(Icons.local_parking), label: 'Bãi đỗ'),
          BottomNavigationBarItem(icon: Icon(Icons.exit_to_app), label: 'Xe ra'),
        ],
      ),
    );
  }
}