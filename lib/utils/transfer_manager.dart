import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ReceivingFile {
  final String fileName;
  final int fileSize;
  double progress;
  double speed;
  bool isComplete;
  bool isError;
  String? errorMessage;
  DateTime? startTime;
  int receivedBytes;
  List<double> speedHistory;

  ReceivingFile({
    required this.fileName,
    required this.fileSize,
    this.progress = 0.0,
    this.speed = 0.0,
    this.isComplete = false,
    this.isError = false,
    this.errorMessage,
    this.startTime,
    this.receivedBytes = 0,
    List<double>? speedHistory,
  }) : speedHistory = speedHistory ?? [];

  ReceivingFile copyWith({
    String? fileName,
    int? fileSize,
    double? progress,
    double? speed,
    bool? isComplete,
    bool? isError,
    String? errorMessage,
    DateTime? startTime,
    int? receivedBytes,
    List<double>? speedHistory,
  }) {
    return ReceivingFile(
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      isComplete: isComplete ?? this.isComplete,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      speedHistory: speedHistory ?? this.speedHistory,
    );
  }

  String get formattedSpeed {
    if (speed < 1024) {
      return '${speed.toStringAsFixed(1)} B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else if (speed < 1024 * 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else {
      return '${(speed / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
    }
  }

  String get estimatedTimeRemaining {
    if (speed <= 0) return 'Calculating...';

    final remainingBytes = fileSize - receivedBytes;
    final secondsRemaining = remainingBytes / speed;

    if (secondsRemaining < 60) {
      return '${secondsRemaining.toInt()}s';
    } else if (secondsRemaining < 3600) {
      final minutes = (secondsRemaining / 60).floor();
      final seconds = (secondsRemaining % 60).toInt();
      return '${minutes}m ${seconds}s';
    } else {
      final hours = (secondsRemaining / 3600).floor();
      final minutes = ((secondsRemaining % 3600) / 60).floor();
      return '${hours}h ${minutes}m';
    }
  }
}

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
  List<ReceivingFile> _receivingFiles = [];
  int _receivedFilesCount = 0;
  bool _isTransferComplete = false; // Track completion status

  // Getters
  bool get isSending => _isSending;
  bool get isReceiving => _isReceiving;
  List<File> get sendingFiles => _sendingFiles;
  int get currentSendingIndex => _currentSendingIndex;
  double get sendProgress => _sendProgress;
  String get sendingFileName => _sendingFileName;
  double get sendSpeed => _sendSpeed;
  List<ReceivingFile> get receivingFiles => _receivingFiles;
  int get receivedFilesCount => _receivedFilesCount;
  bool get isTransferComplete => _isTransferComplete;

  // Convenience getters for backward compatibility
  String get receivingFileName =>
      _receivingFiles.isNotEmpty ? _receivingFiles.first.fileName : "";
  double get receiveProgress =>
      _receivingFiles.isNotEmpty ? _receivingFiles.first.progress : 0.0;
  double get receiveSpeed =>
      _receivingFiles.isNotEmpty ? _receivingFiles.first.speed : 0.0;
  int get receivingFileSize =>
      _receivingFiles.isNotEmpty ? _receivingFiles.first.fileSize : 0;

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
      _sendingFileName =
          _sendingFiles[_currentSendingIndex].path.split('/').last;
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

  void startReceiving(String fileName, int fileSize) {
    _isReceiving = true;
    _isTransferComplete = false;

    // Check if file is already in the list
    final existingIndex = _receivingFiles.indexWhere(
      (file) => file.fileName == fileName,
    );
    if (existingIndex == -1) {
      // Add new file to the list with start time
      _receivingFiles.add(
        ReceivingFile(
          fileName: fileName,
          fileSize: fileSize,
          startTime: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void updateReceiveProgress(
    String fileName,
    double progress,
    double speed,
    int receivedBytes,
  ) {
    final fileIndex = _receivingFiles.indexWhere(
      (file) => file.fileName == fileName,
    );
    if (fileIndex != -1) {
      final currentFile = _receivingFiles[fileIndex];
      final newSpeedHistory = List<double>.from(currentFile.speedHistory);
      newSpeedHistory.add(speed);

      // Keep only last 10 speed measurements for averaging
      if (newSpeedHistory.length > 10) {
        newSpeedHistory.removeAt(0);
      }

      // Calculate average speed
      final avgSpeed =
          newSpeedHistory.reduce((a, b) => a + b) / newSpeedHistory.length;

      _receivingFiles[fileIndex] = currentFile.copyWith(
        progress: progress,
        speed: avgSpeed,
        receivedBytes: receivedBytes,
        speedHistory: newSpeedHistory,
      );
      notifyListeners();
    }
  }

  void completeReceiving(String fileName) {
    final fileIndex = _receivingFiles.indexWhere(
      (file) => file.fileName == fileName,
    );
    if (fileIndex != -1) {
      _receivingFiles[fileIndex] = _receivingFiles[fileIndex].copyWith(
        isComplete: true,
        progress: 1.0,
      );
      _receivedFilesCount++;

      // Check if all files are complete
      final allComplete = _receivingFiles.every((file) => file.isComplete);
      if (allComplete) {
        _isTransferComplete = true;
      }
      notifyListeners();
    }
  }

  void setTransferComplete() {
    _isTransferComplete = true;
    notifyListeners();
  }

  void resetReceivingState() {
    _isReceiving = false;
    _receivingFiles.clear();
    _isTransferComplete = false;
    notifyListeners();
  }

  void resetReceiveCount() {
    _receivedFilesCount = 0;
    notifyListeners();
  }
}
