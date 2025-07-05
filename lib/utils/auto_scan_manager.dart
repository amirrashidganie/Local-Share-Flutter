import 'package:flutter/foundation.dart';

class AutoScanManager extends ChangeNotifier {
  static final AutoScanManager _instance = AutoScanManager._internal();
  factory AutoScanManager() => _instance;
  AutoScanManager._internal();

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  void enable() {
    _isEnabled = true;
    notifyListeners();
  }

  void disable() {
    _isEnabled = false;
    notifyListeners();
  }
}
