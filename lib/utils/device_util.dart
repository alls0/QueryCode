import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceUtil {
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    // Önce kayıtlı ID var mı bak
    String? deviceId = prefs.getString('device_unique_id');

    // Yoksa yeni oluştur ve kaydet
    if (deviceId == null) {
      deviceId = const Uuid().v4(); // Örn: "123e4567-e89b-..."
      await prefs.setString('device_unique_id', deviceId);
    }

    return deviceId;
  }
}
