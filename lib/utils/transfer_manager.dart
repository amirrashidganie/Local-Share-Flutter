import 'dart:io';
import 'package:flutter/foundation.dart';

class TransferManager extends ChangeNotifier {
  static final TransferManager _instance = TransferManager._internal();
  factory TransferManager() => _instance;
  TransferManager._internal();

  // Sending state
  bool _isSending = false;
  List<File> _sendingFiles = [];
  int _currentSendingIndex = 0;
  double _sendProgress = 0.0;
  String _sendingFileName = "";
  double _sendSpeed = 0.0;

  // Receiving state
  bool _isReceiving = false;
  String _receivingFileName = "";
  double _receiveProgress = 0.0;
  double _receiveSpeed = 0.0;
  int _receivedFilesCount = 0;

  // Getters
  bool get isSending => _isSending;
  bool get isReceiving => _isReceiving;
  List<File> get sendingFiles => _sendingFiles;
  int get currentSendingIndex => _currentSendingIndex;
  double get sendProgress => _sendProgress;
  String get sendingFileName => _sendingFileName;
  double get sendSpeed => _sendSpeed;
  String get receivingFileName => _receivingFileName;
  double get receiveProgress => _receiveProgress;
  double get receiveSpeed => _receiveSpeed;
  int get receivedFilesCount => _receivedFilesCount;

  void startSending(List<File> files) {
    _isSending = true;
    _sendingFiles = files;
    _currentSendingIndex = 0;
    _sendProgress = 0.0;
    _sendingFileName = files.isNotEmpty ? files.first.path.split('/').last : "";
    notifyListeners();
  }

  void updateSendProgress(double progress, String fileName, double speed) {
    _sendProgress = progress;
    _sendingFileName = fileName;
    _sendSpeed = speed;
    notifyListeners();
  }

  void nextSendingFile() {
    _currentSendingIndex++;
    if (_currentSendingIndex < _sendingFiles.length) {
      _sendingFileName = _sendingFiles[_currentSendingIndex].path.split('/').last;
      _sendProgress = 0.0;
    }
    notifyListeners();
  }

  void stopSending() {
    _isSending = false;
    _sendingFiles.clear();
    _currentSendingIndex = 0;
    _sendProgress = 0.0;
    _sendingFileName = "";
    _sendSpeed = 0.0;
    notifyListeners();
  }

  void startReceiving(String fileName) {
    _isReceiving = true;
    _receivingFileName = fileName;
    _receiveProgress = 0.0;
    notifyListeners();
  }

  void updateReceiveProgress(double progress, double speed) {
    _receiveProgress = progress;
    _receiveSpeed = speed;
    notifyListeners();
  }

  void completeReceiving() {
    _receivedFilesCount++;
    _isReceiving = false;
    _receivingFileName = "";
    _receiveProgress = 0.0;
    _receiveSpeed = 0.0;
    notifyListeners();
  }

  void resetReceiveCount() {
    _receivedFilesCount = 0;
    notifyListeners();
  }
}