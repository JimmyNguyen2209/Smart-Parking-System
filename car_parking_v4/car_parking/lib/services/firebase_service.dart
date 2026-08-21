import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final _db = FirebaseDatabase.instance.ref();

  // Lấy dữ liệu chỗ để xe theo id
  Future<Map<String, dynamic>?> getParkingSpot(String spotId) async {
    final snapshot = await _db.child('parkingSpots/$spotId').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  // Lấy tất cả vị trí trống (status == 'empty')
  Future<List<String>> getEmptySpots() async {
    final snapshot = await _db.child('parkingSpots').get();
    List<String> emptySpots = [];
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        if (value['status'] == 'empty') emptySpots.add(key);
      });
    }
    return emptySpots;
  }

  // Kiểm tra xe đã có trong bãi (tìm theo các plate đang có status = occupied)
  Future<String?> findSpotByPlate(String plate) async {
    final snapshot = await _db.child('parkingSpots').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      for (var entry in data.entries) {
        if (entry.value['plate'] == plate && entry.value['status'] == 'occupied') {
          return entry.key;
        }
      }
    }
    return null;
  }

  String toVietnamTimeString(DateTime dt) {
    final vnTime = dt.toUtc().add(Duration(hours: 7));
    String iso = vnTime.toIso8601String().split('.').first;
    return '$iso+07:00';
  }

  // Xe vào: cập nhật chỗ đậu lên Firebase
  Future<void> checkInVehicle({
    required String spotId,
    required String plate,
    required DateTime timeIn,
  }) async {
    await _db.child('parkingSpots/$spotId').set({
      'status': 'occupied',
      'plate': plate,
      'timeIn': toVietnamTimeString(timeIn),
      'timeOut': null,
      'duration': null,
    });
  }

  // Xe ra: cập nhật chỗ đậu và lưu lịch sử lên Firebase
  Future<void> checkOutVehicle({
    required String spotId,
    required String plate,
    required DateTime timeOut,
  }) async {
    final spotData = await getParkingSpot(spotId);
    if (spotData == null) return;
    final timeInStr = spotData['timeIn'] as String?;
    if (timeInStr == null) return;
    final timeIn = DateTime.parse(timeInStr);
    final duration = timeOut.difference(timeIn).inSeconds;

    // Cập nhật chỗ đậu về empty
    await _db.child('parkingSpots/$spotId').set({
      'status': 'empty',
      'plate': null,
      'timeIn': null,
      'timeOut': null,
      'duration': null,
    });

    // Lưu lịch sử ra vào
    final historyKey = '${plate}_${timeIn.toUtc().toIso8601String().replaceAll(RegExp(r'[:\-]'), '').replaceAll('.', '_')}Z';
    await _db.child('parkingHistory/$historyKey').set({
      'spotId': spotId,
      'plate': plate,
      'timeIn': toVietnamTimeString(timeIn),
      'timeOut': toVietnamTimeString(timeOut),
      'duration': duration,
    });
  }

  // Khởi tạo danh sách chỗ đỗ xe
  Future<void> initializeParkingSpots(int numberOfSpots) async {
    final snapshot = await _db.child('parkingSpots').get();
    if (snapshot.exists) {
      return;
    }
    
    Map<String, dynamic> spotsData = {};
    for (int i = 1; i <= numberOfSpots; i++) {
      String spotId = 'A${i.toString().padLeft(2, '0')}'; // A01, A02, ..., A20
      spotsData[spotId] = {
        "status": "empty",
        "plate": null,
        "timeIn": null,
        "timeOut": null,
        "duration": null,
      };
    }
    await _db.child('parkingSpots').set(spotsData);
  }

  // Lấy các vị trí đang có
  Future<Map<String, dynamic>> getAllSpots() async {
    final snapshot = await _db.child('parkingSpots').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }
}



