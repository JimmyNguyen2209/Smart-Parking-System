import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:car_parking/services/firebase_service.dart';
import 'package:car_parking/screens/parking_spot_screen.dart';

// Widget ScanInScreen - Scan xe vào
class ScanInScreen extends StatefulWidget {
  @override
  State<ScanInScreen> createState() => _ScanInScreenState();
}

// ScanIn State
class _ScanInScreenState extends State<ScanInScreen> {
  final FirebaseService _firebaseService = FirebaseService();                     // Tạo đối tượng từ Constructor FirebaseService()

  bool _processing = false;                                       // Kiểm tra xem có đang được xử lý hay không
  bool _hasScanned = false;                                       // Kiểm tra xem có đang quét hay không
  String? _lastScannedPlate;                                      // Lưu biển số đã quét gần nhất

  // Phương thức Quét xe vào
  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;             // Nếu đang quét thì thoát hàm

    final barcodes = capture.barcodes;   // Lấy mã QR
    if (barcodes.isEmpty) return;        // Không có mã thì thoát hàm

    final rawValue = barcodes.first.rawValue;         // Lấy mã đầu tiên quét được
    if (rawValue != null && rawValue.isNotEmpty) {    
      _hasScanned = true;         // Đánh dấu đang quét

      _handleBarcode(rawValue);   // Đưa mã vào hàm Xử lý

      // Thông báo đã quét
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã quét biển số: $rawValue")),
      );

      // Cho phép quét lại sau 1 giây
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _hasScanned = false);       // Widget còn trên WidgetTree thì set state
      });
    }
  }

  // Phương thức Xử lý Sau khi Quét xe vào
  void _handleBarcode(String plate) async {

    if (_processing) return;      // Nếu còn xử lý thì thoát hàm
    setState(() {
      _processing = true;         // Đánh dấu đang processing
      _lastScannedPlate = plate;  // Lưu biển số
    });

    try {
      // Kiểm tra xem plate có trong bãi (Firebase) hay chưa
      final existingSpot = await _firebaseService.findSpotByPlate(plate);

      if (!mounted) return;     // Biến mounted có sẵn, kiểm tra xem Widget còn tồn tại trên Widget Tree hay không
      
      // Nếu chưa có trong bãi
      if (existingSpot != null) {
        await _showDialog('Thông báo', 'Xe $plate đã vào bãi tại vị trí $existingSpot');
        setState(() {
          _processing = false;  // Đánh dấu processing xong
        });
        return;
      }

      // Tiếp tục sang màn hình chọn chỗ
      // Trả về Navigator.pop(context, true); --> Khi người dùng đã chọn chỗ thành công
      // Trả về Navigator.pop(context, false);  --> Khi không thành công hoặc không chọn gì và quay lại

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ParkingSpotScreen(scannedPlate: plate),
        ),
      );

      if (!mounted) return;     // Biến mounted có sẵn, kiểm tra xem Widget còn tồn tại trên Widget Tree hay không

      if (result == true) {
        await _showDialog('Thành công', 'Xe $plate đã được thêm vào bãi');
      }
    } catch (e) {
      if (!mounted) return;
      await _showDialog('Lỗi', 'Đã xảy ra lỗi: $e');  // Hiển thị lỗi bằng _showDialog
    }

    setState(() {
      _processing = false;    // Đánh dấu processing xong
    });
  }

  // Phương thức Hiển thị Dialog
  Future<void> _showDialog(String title, String msg) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Giao diện
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: Text('Quét xe vào')),
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(onDetect: _onDetect),

          // Custom overlay
          ScannerOverlay(),

          // Phần hiển thị trạng thái xử lý hoặc hướng dẫn
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              color: Colors.black.withOpacity(0.5),
              child: _processing
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          'Đang xử lý...',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.login,
                          color: Colors.white,
                          size: 70,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _lastScannedPlate == null
                              ? 'Quét mã QR để xe vào bãi'
                              : 'Biển số đã quét: $_lastScannedPlate',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Overlay
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: ScannerOverlayShape(),
      ),
    );
  }
}

class ScannerOverlayShape extends ShapeBorder {
  const ScannerOverlayShape();

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..fillType = PathFillType.evenOdd;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path outerPath = Path()..addRect(rect);
    Path innerPath = Path();
    
    // Tạo khung quét ở giữa màn hình
    double scanAreaSize = 450.0;
    double left = (rect.width - scanAreaSize) / 2;
    double top = (rect.height - scanAreaSize) / 2;
    
    Rect scanArea = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);
    innerPath.addRRect(RRect.fromRectAndRadius(scanArea, Radius.circular(12)));
    
    return Path.combine(PathOperation.difference, outerPath, innerPath);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Vẽ overlay mờ
    Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(getOuterPath(rect), overlayPaint);
    
    // Vẽ khung quét
    double scanAreaSize = 350.0;
    double left = (rect.width - scanAreaSize) / 2;
    double top = (rect.height - scanAreaSize) / 2;
    
    Rect scanArea = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);
    
    // Vẽ viền khung
    Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, Radius.circular(12)),
      borderPaint,
    );
    
    // Vẽ các góc của khung (trang trí)
    Paint cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    
    double cornerLength = 30.0;
    
    // Góc trên trái
    canvas.drawLine(
      Offset(scanArea.left, scanArea.top + cornerLength),
      Offset(scanArea.left, scanArea.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.left, scanArea.top),
      Offset(scanArea.left + cornerLength, scanArea.top),
      cornerPaint,
    );
    
    // Góc trên phải
    canvas.drawLine(
      Offset(scanArea.right - cornerLength, scanArea.top),
      Offset(scanArea.right, scanArea.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.right, scanArea.top),
      Offset(scanArea.right, scanArea.top + cornerLength),
      cornerPaint,
    );
    
    // Góc dưới trái
    canvas.drawLine(
      Offset(scanArea.left, scanArea.bottom - cornerLength),
      Offset(scanArea.left, scanArea.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.left, scanArea.bottom),
      Offset(scanArea.left + cornerLength, scanArea.bottom),
      cornerPaint,
    );
    
    // Góc dưới phải
    canvas.drawLine(
      Offset(scanArea.right - cornerLength, scanArea.bottom),
      Offset(scanArea.right, scanArea.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.right, scanArea.bottom),
      Offset(scanArea.right, scanArea.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => const ScannerOverlayShape();
}