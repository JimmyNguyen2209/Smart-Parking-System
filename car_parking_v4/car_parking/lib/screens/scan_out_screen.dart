import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:car_parking/services/firebase_service.dart';

// Widget ScanOutScreen - Scan xe ra
class ScanOutScreen extends StatefulWidget {
  @override
  State<ScanOutScreen> createState() => _ScanOutScreenState();
}

// ScanOut State
class _ScanOutScreenState extends State<ScanOutScreen> {
  final FirebaseService _firebaseService = FirebaseService();                     // Tạo đối tượng từ Constructor FirebaseService()
  final MobileScannerController _cameraController = MobileScannerController();    // Tạo đối tượng từ Constructor MobileScannerController()
  bool _hasScanned = false;                                       // Kiểm tra xem có đang quét hay không

  bool _processing = false;       // Kiểm tra có đang xử lý hay không
  String? _lastScannedPlate;      // Biển số đã quét lần cuối
  String? _lastSpotId;            // Vị trí đã đỗ xe

  // Format định dạng để hiển thị 
  String formatSpotId(String spotId) {
    final regex = RegExp(r'^([A-Za-z]+)(\d+)$');
    final match = regex.firstMatch(spotId);
    if (match == null) return spotId;
    return '${match.group(1)}-${match.group(2)}';
  }

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
    if (_processing) return;

    setState(() {
      _processing = true;
      _lastScannedPlate = plate;
      _lastSpotId = null;
    });

    _cameraController.stop(); // Tạm dừng camera khi xử lý

    final spotIdRaw = await _firebaseService.findSpotByPlate(plate);

    if (spotIdRaw == null) {
      _showDialog('Thông báo', 'Xe $plate không có trong bãi');
      setState(() {
        _processing = false;
      });
      _cameraController.start(); // Mở lại camera
      return;
    }

    // Lấy vị trí đã đỗ
    final spotId = formatSpotId(spotIdRaw);

    // Lấy thời gian hiện tại
    final now = DateTime.now().toUtc();
    await _firebaseService.checkOutVehicle(
      spotId: spotIdRaw,
      plate: plate,
      timeOut: now,
    );

    setState(() {
      _lastSpotId = spotId;
      _processing = false;
    });

    _showDialog('Thành công', 'Xe $plate đã ra khỏi bãi tại vị trí $spotId');

    _cameraController.start(); // Mở lại camera sau khi xử lý xong
  }

  // Phương thức hiển thị Dialog
  void _showDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét xe ra'),
      ),
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),

          // Custom overlay
          ExitScannerOverlay(),
          
          // Thông báo xử lý và hướng dẫn
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(
                          'Đang xử lý...',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    )
                  : _lastScannedPlate == null
                      ? Column(
                          children: [
                            Icon(
                              Icons.login,
                              color: Colors.white,
                              size: 70,
                            ),
                            const SizedBox(height: 16),
                            Text(
                            'Quét mã QR để xe ra khỏi bãi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ])
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Biển số:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _lastScannedPlate ?? '',
                              style: const TextStyle(
                                  fontSize: 26, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.lightBlueAccent,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            if (_lastSpotId != null) ...[
                              Text(
                                'Vị trí đậu:',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _lastSpotId ?? '',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightGreenAccent
                                    ),
                              ),
                            ],
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
class ExitScannerOverlay extends StatelessWidget {
  const ExitScannerOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: ExitScannerOverlayShape(),
      ),
    );
  }
}

class ExitScannerOverlayShape extends ShapeBorder {
  const ExitScannerOverlayShape();

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
    double scanAreaSize = 350.0;
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
    
    // Vẽ các góc của khung (trang trí) - màu đỏ cho exit
    Paint cornerPaint = Paint()
      ..color = Colors.red
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
  ShapeBorder scale(double t) => const ExitScannerOverlayShape();
}