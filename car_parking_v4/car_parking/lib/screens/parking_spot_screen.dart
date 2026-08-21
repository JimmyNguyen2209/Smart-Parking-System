import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:car_parking/services/firebase_service.dart';

// Widget ParkingSpotScreen - Hiển thị Bãi đỗ
class ParkingSpotScreen extends StatefulWidget {
  final String? scannedPlate;       // Biển số xe

  const ParkingSpotScreen({Key? key, this.scannedPlate}) : super(key: key);

  @override
  State<ParkingSpotScreen> createState() => _ParkingSpotScreenState();
}

// ParkingSpotScreen State
class _ParkingSpotScreenState extends State<ParkingSpotScreen> {
  final FirebaseService _firebaseService = FirebaseService();     // Tạo đối tượng từ Constructor FirebaseService()
  Map<String, dynamic> _spots = {};     // Các ô đỗ
  bool _loading = true;                 // Load dữ liệu Firebase xuống

  @override
  // Load 1 lần đầu khi vào Bãi đỗ
  void initState() {
    super.initState();
    _loadSpots();
  }

  // Phương thức Load dữ liệu Firebase xuống
  Future<void> _loadSpots() async {
    final snapshot = await _firebaseService.getAllSpots();    
    if (mounted) {
      setState(() {
        _spots = snapshot;    // Lấy dữ liệu
        _loading = false;     // Đánh dấu đã load xong
      });
    }
  }

  // Phương thức Chọn ô đỗ
  Future<void> _handleCheckIn(String spotId) async {
    final plate = widget.scannedPlate;      // Cho dữ liệu đã scan vào plate
    if (plate == null) return;              // Không có dữ liệu thì thoát hàm

    await _firebaseService.checkInVehicle(
      spotId: spotId,
      plate: plate,
      timeIn: DateTime.now(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi xe tại vị trí $spotId'),
      ),
    );

    Navigator.pop(context);
  }

  // Format định dạng để hiển thị 
  String formatSpotId(String spotId) {
    final reg = RegExp(r'^([A-Z]+)(\d+)$');
    final match = reg.firstMatch(spotId);
    if (match != null) {
      return '${match.group(1)}-${match.group(2)}';
    }
    return spotId;
  }

  // Widget hiển thị cho 1 ô đỗ
  Widget _buildSpotCard(String spotId, dynamic spotData) {
    final status = spotData['status'] ?? 'unknown';
    final plate = spotData['plate'] ?? '';
    final isEmpty = status == 'empty';

    final formattedSpotId = formatSpotId(spotId);

    // Hiển thị cho ô đỗ
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        // Màu nền
        color: isEmpty ? const Color(0xFF00BFA5) : const Color(0xFF9CA3AF),
        borderRadius: BorderRadius.circular(16),
        // Màu shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      // Nội dung bên trong
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng đầu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    isEmpty ? LucideIcons.parkingCircle : LucideIcons.car,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedSpotId,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Hàng trạng thái
              Text(
                isEmpty ? 'Trạng thái: Trống' : 'Trạng thái: Đã có xe\nXe: $plate',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

              // Nút chọn
              if (widget.scannedPlate != null && isEmpty)
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF00BFA5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _handleCheckIn(spotId),    // Chọn vị trí
                        child: const Text('Chọn'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        )
      ),
    );
  }

  // Hiển thị giao diện
  @override
  Widget build(BuildContext context) {

    final plate = widget.scannedPlate;
    final availableCount = _spots.values.where((s) => s['status'] == 'empty').length;     // Số chỗ trống còn lại

    // Sắp xếp theo thứ tự A-01, A-02, ..., A-10
    final sortedEntries = _spots.entries.toList()
      ..sort((a, b) {
        final reg = RegExp(r'([A-Z]+)-(\d+)');
        final ma = reg.firstMatch(a.key);
        final mb = reg.firstMatch(b.key);
        if (ma == null || mb == null) return a.key.compareTo(b.key);

        final zoneA = ma.group(1)!;
        final zoneB = mb.group(1)!;
        final numA = int.parse(ma.group(2)!);
        final numB = int.parse(mb.group(2)!);

        final zoneCompare = zoneA.compareTo(zoneB);
        return zoneCompare != 0 ? zoneCompare : numA.compareTo(numB);
      });

    // Hiển thị
    return Scaffold(
      // AppBar
      appBar: plate == null ? null 
        : AppBar(
          backgroundColor: Colors.white,
          title: const Text('Chọn vị trí cho xe'),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _spots.isEmpty ? const Center(child: Text('Không có dữ liệu'))

          // Khung
          : Column(
              children: [
                // Hàng đầu, hiển thị số lượng vị trí còn trống
                // Tạo khung
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00BFA5).withOpacity(0.3),
                    ),
                  ),

                  // Bố cục hàng
                  child: Row(
                    children: [
                      // Icon
                      const Icon(Icons.local_parking,
                          size: 28, color: Color(0xFF00BFA5)),
                      const SizedBox(width: 12),

                      // Text: Vị trí trống
                      const Text(
                        'Vị trí trống:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),

                      // Khoảng cách
                      const Spacer(),

                      // Số lượng ô còn trống
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BFA5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$availableCount chỗ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Hiển thị các ô đỗ thành nhiều cột
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3, // Tùy chỉnh tỉ lệ chiều rộng / chiều cao
                    ),
                    itemCount: sortedEntries.length,
                    itemBuilder: (context, index) {
                      final entry = sortedEntries[index];
                      return _buildSpotCard(entry.key, entry.value);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
