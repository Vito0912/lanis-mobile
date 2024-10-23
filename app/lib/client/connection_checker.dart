import 'dart:async';
import 'package:dio/dio.dart';

CustomConnectionChecker connectionChecker = CustomConnectionChecker();

enum ConnectionStatus { connected, disconnected }

class CustomConnectionChecker {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final dio = Dio(
    BaseOptions(validateStatus: (status) => status != null && (status == 200 || status == 302 || status == 503))
  );
  DateTime lastRequest = DateTime.now().subtract(const Duration(seconds: 5));

  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  CustomConnectionChecker() {
    testConnection();
  }

  set status(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
    lastRequest = DateTime.now();
  }

  ConnectionStatus get status => _status;

  Future<bool> _isConnected() async {
    if (DateTime.now().difference(lastRequest) > const Duration(seconds: 1)) {
      await testConnection();
    }
    return _status == ConnectionStatus.connected;
  }

  Future<bool> get connected async => await _isConnected();

  void dispose() {
    _statusController.close();
  }


  Future<bool> testConnection() async {
    try {
      await dio.post("http://192.168.0.65:5000");
      status = ConnectionStatus.connected;
      return true;
    } catch (e) {
      status = ConnectionStatus.disconnected;
      return false;
    }
  }
}
