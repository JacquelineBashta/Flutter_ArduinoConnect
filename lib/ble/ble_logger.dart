import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleLogger {
  BleLogger({
    required FlutterReactiveBle ble,
  }) : _ble = ble;

  final FlutterReactiveBle _ble;
  final List<String> _logMessages = [];

  List<String> get messages => _logMessages;

  void addToLog(String message) {
    final now = DateTime.now();
    _logMessages.add('- $message');
  }

  void clearLogs() => _logMessages.clear();

  bool get verboseLogging => _ble.logLevel == LogLevel.verbose;

  void toggleVerboseLogging() =>
      _ble.logLevel = verboseLogging ? LogLevel.none : LogLevel.verbose;
}