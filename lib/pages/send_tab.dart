import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:localshare/utils/file_utils.dart';
import 'package:localshare/utils/transfer_manager.dart';
import 'package:localshare/utils/auto_scan_manager.dart';
import 'package:installed_apps/app_info.dart';
import 'package:localshare/pages/device_apps_screen.dart';
import 'package:flutter/services.dart';
// import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'package:localshare/utils/settings_manager.dart';

class SendTab extends StatefulWidget {
  const SendTab({
    super.key,
    this.onQrScannerVisibilityChanged,
    this.onSendingVisibilityChanged,
  });

  final ValueChanged<bool>? onQrScannerVisibilityChanged;
  final ValueChanged<bool>? onSendingVisibilityChanged;

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> {
  final List<dynamic> _selectedFiles = [];
  final TransferManager _transferManager = TransferManager();
  final AutoScanManager _autoScanManager = AutoScanManager();
  final ScrollController _selectedFilesScrollController = ScrollController();
  int _selectedFilesDisplayCount = 20;
  bool _isLoadingMoreSelectedFiles = false;

  // Connection state
  bool _showQrScanner = false;
  String _currentSSID = "";
  String _currentIP = "";
  List<String> _availableDevices = [];
  bool _isScanning = false;
  bool _disposed = false;
  Timer? _autoScanTimer;

  // File picker state
  bool _isFilePickerActive = false;
  bool _isProcessingFiles = false; // Add loading state for file processing

  // Navigation visibility tracking
  bool _isNavigationHidden = false;

  Future<void> _pickFiles() async {
    if (_isFilePickerActive || _disposed || !mounted) return;

    try {
      _isFilePickerActive = true;
      setState(() {
        _isProcessingFiles = true;
      });

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing files...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'doc',
          'docx',
          'pdf',
          'txt',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'odt',
          'ods',
          'odp',
          'rtf',
          'csv',
          'md',
          'json',
          'xml',
          'html',
          'htm',
        ],
      );
      if (result != null) {
        if (_disposed || !mounted) return;

        // Process files asynchronously to prevent UI blocking
        await _processSelectedFiles(
          result.paths.map((path) => File(path!)).toList(),
        );

        // Ensure auto-scan is running when files are added
        if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
          _startAutoScan();
        }
      }
    } catch (e) {
      print('File picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFilePickerActive = false;
          _isProcessingFiles = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    if (_isFilePickerActive || _disposed || !mounted) return;

    try {
      _isFilePickerActive = true;
      setState(() {
        _isProcessingFiles = true;
      });

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing images...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultipleMedia();
      if (images.isNotEmpty) {
        if (_disposed || !mounted) return;

        // Process files asynchronously to prevent UI blocking
        await _processSelectedFiles(
          images.map((image) => File(image.path)).toList(),
        );

        // Ensure auto-scan is running when files are added
        if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
          _startAutoScan();
        }
      }
    } catch (e) {
      print('Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFilePickerActive = false;
          _isProcessingFiles = false;
        });
      }
    }
  }

  Future<void> _pickVideos() async {
    if (_isFilePickerActive || _disposed || !mounted) return;

    try {
      _isFilePickerActive = true;
      setState(() {
        _isProcessingFiles = true;
      });

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing video files...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result != null) {
        if (_disposed || !mounted) return;

        // Process files asynchronously to prevent UI blocking
        await _processSelectedFiles(
          result.paths.map((path) => File(path!)).toList(),
        );

        // Ensure auto-scan is running when files are added
        if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
          _startAutoScan();
        }
      }
    } catch (e) {
      print('Video picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking videos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFilePickerActive = false;
          _isProcessingFiles = false;
        });
      }
    }
  }

  // Helper method to process selected files asynchronously
  Future<void> _processSelectedFiles(List<File> files) async {
    if (_disposed || !mounted) return;

    int processedCount = 0;
    int totalFiles = files.length;

    // Add files one by one to show progress
    for (int i = 0; i < files.length; i++) {
      if (_disposed || !mounted) return;

      final file = files[i];

      // Verify file exists and is accessible
      try {
        if (await file.exists()) {
          final fileSize = await file.length();

          // Check if file is too large (e.g., > 2GB)
          if (fileSize > 2 * 1024 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'File ${file.path.split('/').last} is too large (>2GB)',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            continue;
          }

          // Check if file is accessible
          try {
            await file.openRead().first;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot access file: ${file.path.split('/').last}',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            continue;
          }

          setState(() {
            _selectedFiles.add(file);
            processedCount++;
          });

          // Show progress for large files
          if (totalFiles > 5 && processedCount % 5 == 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Processed $processedCount of $totalFiles files...',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          }

          // Small delay to prevent UI blocking
          await Future.delayed(const Duration(milliseconds: 50));
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File not found: ${file.path.split('/').last}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Error processing file ${file.path}: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error processing file: ${file.path.split('/').last}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }

    // Show completion message
    if (mounted && processedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added $processedCount files'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickAudio() async {
    if (_isFilePickerActive || _disposed || !mounted) return;

    try {
      _isFilePickerActive = true;
      setState(() {
        _isProcessingFiles = true;
      });

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing audio files...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result != null) {
        if (_disposed || !mounted) return;

        // Process files asynchronously to prevent UI blocking
        await _processSelectedFiles(
          result.paths.map((path) => File(path!)).toList(),
        );

        // Ensure auto-scan is running when files are added
        if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
          _startAutoScan();
        }
      }
    } catch (e) {
      print('Audio picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFilePickerActive = false;
          _isProcessingFiles = false;
        });
      }
    }
  }

  void _removeFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      // Use addPostFrameCallback to avoid calling notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transferManager.stopSending();
        }
      });
      if (_disposed || !mounted) return;
      setState(() => _selectedFiles.removeAt(index));
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeConnection();
    _selectedFilesScrollController.addListener(_onSelectedFilesScroll);

    // Set up callback for when receiver completes transfer
    _transferManager.setReceiverCompleteCallback(() {
      if (mounted && _transferManager.isSendingComplete) {
        // Automatically redirect to main send screen when receiver clicks Done
        _onTransferComplete();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _selectedFilesScrollController.dispose();
    // Stop auto-scan immediately
    _stopAutoScan();
    _autoScanTimer?.cancel();
    // Reset file picker state
    _isFilePickerActive = false;
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transferManager.stopSending();
    });
    _selectedFiles.clear();
    // Clear the receiver complete callback
    _transferManager.setReceiverCompleteCallback(() {});
    // Ensure navigation bar is shown when widget is disposed
    if (_isNavigationHidden) {
      _isNavigationHidden = false;
      widget.onSendingVisibilityChanged?.call(false);
    }
    super.dispose();
  }

  void _onSelectedFilesScroll() {
    if (_selectedFilesScrollController.position.pixels >=
        _selectedFilesScrollController.position.maxScrollExtent - 100) {
      _loadMoreSelectedFiles();
    }
  }

  void _loadMoreSelectedFiles() {
    if (_isLoadingMoreSelectedFiles) return;
    if (_selectedFilesDisplayCount >= _selectedFiles.length) return;
    if (_disposed || !mounted) return;
    setState(() {
      _isLoadingMoreSelectedFiles = true;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_disposed && mounted) {
        setState(() {
          _selectedFilesDisplayCount = (_selectedFilesDisplayCount + 20).clamp(
            0,
            _selectedFiles.length,
          );
          _isLoadingMoreSelectedFiles = false;
        });
      }
    });
  }

  Future<void> _initializeConnection() async {
    if (_disposed || !mounted) return;
    await _getNetworkInfo();
    // Start auto-scan immediately when tab is loaded
    if (_currentIP.isNotEmpty && !_disposed && mounted) {
      _startAutoScan();
    } else if (!_disposed && mounted) {
      // If IP is not available yet, try again after a short delay
      Timer(const Duration(seconds: 1), () {
        if (!_disposed && mounted) {
          _getNetworkInfo().then((_) {
            if (_currentIP.isNotEmpty && !_disposed && mounted) {
              _startAutoScan();
            }
          });
        }
      });
    }
  }

  Future<void> _getNetworkInfo() async {
    if (_disposed || !mounted) return;
    try {
      final info = NetworkInfo();
      _currentSSID = await info.getWifiName() ?? "Unknown";
      _currentIP = await info.getWifiIP() ?? "";

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle silently
    }
  }

  void _startAutoScan() {
    if (_disposed || !mounted || !_autoScanManager.isEnabled) return;
    if (_currentIP.isNotEmpty) {
      _scanNetworkForReceivers();
      _autoScanTimer?.cancel();
      _autoScanTimer = Timer(const Duration(seconds: 2), () {
        if (!_disposed &&
            mounted &&
            !_transferManager.isSending &&
            _autoScanManager.isEnabled) {
          _startAutoScan();
        }
      });
    }
  }

  void _stopAutoScan() {
    _disposed = true;
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
    // Clear any pending auto-scan operations
  }

  void _restartDeviceScanning() {
    if (_disposed || !mounted) return;

    // Clear previous scan results
    if (mounted) {
      setState(() {
        _availableDevices.clear();
        _isScanning = false;
      });
    }

    // Wait a moment then start fresh scanning
    Timer(const Duration(milliseconds: 500), () {
      if (!_disposed && mounted && _autoScanManager.isEnabled) {
        _scanNetworkForReceivers();
        // Restart auto-scan after manual scan
        _startAutoScan();
      }
    });
  }

  Future<void> _scanNetworkForReceivers() async {
    if (_disposed || !mounted) return;

    if (mounted) {
      setState(() {
        _availableDevices.clear();
        _isScanning = true;
      });
    }

    String subnet = _currentIP.substring(0, _currentIP.lastIndexOf('.'));
    List<Future> scanTasks = [];
    for (int i = 1; i <= 254; i++) {
      String targetIP = '$subnet.$i';
      if (targetIP != _currentIP) {
        scanTasks.add(_checkForReceiver(targetIP));
      }
    }

    await Future.wait(scanTasks);

    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _checkForReceiver(String ip) async {
    if (_disposed || !mounted) return;
    try {
      final settingsManager = SettingsManager();
      Socket socket = await Socket.connect(
        ip,
        settingsManager.transferPort,
        timeout: Duration(milliseconds: settingsManager.networkTimeout * 1000),
      );
      await socket.close();

      if (!_disposed && mounted) {
        if (!_availableDevices.contains(ip)) {
          setState(() {
            _availableDevices.add(ip);
          });
        }
      }
    } catch (e) {
      // Device not available
    }
  }

  Future<void> _sendToDevice(String receiverIP) async {
    if (_disposed || !mounted) return;
    final filesToSend = _selectedFiles.whereType<File>().toList();

    // Check total file size before sending
    int totalSize = 0;
    for (var file in filesToSend) {
      try {
        totalSize += await file.length();
      } catch (e) {
        print('Error getting file size: $e');
      }
    }

    // Check if total size exceeds limit (e.g., 5GB)
    if (totalSize > 5 * 1024 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Total file size exceeds 5GB limit"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _transferManager.startSending(filesToSend);
      }
    });

    try {
      for (int i = 0; i < filesToSend.length; i++) {
        if (_disposed || !mounted) return;

        dynamic file = filesToSend[i];

        // Check individual file size
        try {
          int fileSize = await file.length();
          if (fileSize > 2 * 1024 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "File ${file.path.split('/').last} exceeds 2GB limit",
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            continue;
          }
        } catch (e) {
          print('Error checking file size: $e');
          continue;
        }

        await _sendSingleFile(file, receiverIP);

        if (i < filesToSend.length - 1) {
          // Use addPostFrameCallback to avoid calling notifyListeners during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _transferManager.nextSendingFile();
            }
          });
        }
      }

      // Use addPostFrameCallback to avoid calling notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transferManager.completeSending();

          // Show success message but keep files selected
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("All files sent successfully!"),
              backgroundColor: Colors.green,
            ),
          );

          // Restart device scanning after successful transfer
          _restartDeviceScanning();
        }
      });
    } catch (e) {
      print('Error sending files: $e');
      // Use addPostFrameCallback to avoid calling notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transferManager.stopSending();

          String errorMessage = "Failed to send files";
          if (e.toString().contains("timeout")) {
            errorMessage =
                "Connection timeout. Please check network connection.";
          } else if (e.toString().contains("2GB")) {
            errorMessage = "File size exceeds 2GB limit";
          } else if (e.toString().contains("Connection refused")) {
            errorMessage = "Connection refused. Receiver may be offline.";
          } else {
            errorMessage = "Error: ${e.toString()}";
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    }
  }

  Future<void> _sendSingleFile(dynamic file, String receiverIP) async {
    if (_disposed || !mounted) return;

    try {
      final settingsManager = SettingsManager();
      Socket socket = await Socket.connect(
        receiverIP,
        settingsManager.transferPort,
        timeout: Duration(seconds: settingsManager.networkTimeout),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);

      String fileName = file.path.split('/').last;
      List<int> fileNameBytes = fileName.codeUnits;
      socket.add([fileNameBytes.length]);
      socket.add(fileNameBytes);

      int totalSize = await file.length();

      // Check file size limit (2GB)
      if (totalSize > 2 * 1024 * 1024 * 1024) {
        throw Exception('File size exceeds 2GB limit');
      }

      socket.add([
        (totalSize >> 24) & 0xFF,
        (totalSize >> 16) & 0xFF,
        (totalSize >> 8) & 0xFF,
        totalSize & 0xFF,
      ]);

      await socket.flush();

      int sentBytes = 0;
      DateTime startTime = DateTime.now();
      const int chunkSize =
          64 * 1024; // 64KB chunks for better memory management

      await for (List<int> chunk in file.openRead()) {
        if (_disposed || !mounted) {
          socket.close();
          return;
        }

        // Send chunk in smaller pieces to prevent memory issues
        for (int i = 0; i < chunk.length; i += chunkSize) {
          int end =
              (i + chunkSize < chunk.length) ? i + chunkSize : chunk.length;
          List<int> subChunk = chunk.sublist(i, end);

          socket.add(subChunk);
          sentBytes += subChunk.length;

          double progress = sentBytes / totalSize;
          double elapsedSeconds =
              DateTime.now().difference(startTime).inMilliseconds / 1000;
          double speed =
              elapsedSeconds > 0
                  ? (sentBytes / (1024 * 1024)) / elapsedSeconds
                  : 0;

          // Update progress less frequently to reduce UI updates
          if (sentBytes % (1024 * 1024) == 0 || sentBytes == totalSize) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _transferManager.updateSendProgress(progress, fileName, speed);
              }
            });
          }

          // Small delay to prevent overwhelming the UI
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      await socket.flush();
      await socket.close();
    } catch (e) {
      print('Error sending file: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showQrScanner) {
      // Hide navigation bar when QR scanner is active
      if (!_isNavigationHidden) {
        _isNavigationHidden = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onQrScannerVisibilityChanged?.call(true);
          }
        });
      }
      return _buildQrScanner();
    }

    return ListenableBuilder(
      listenable: _transferManager,
      builder: (context, child) {
        // Show sending screen when actively sending or when sending is complete
        if (_transferManager.isSending || _transferManager.isSendingComplete) {
          // Hide navigation bar when sending screen is active
          if (!_isNavigationHidden) {
            _isNavigationHidden = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onSendingVisibilityChanged?.call(true);
              }
            });
          }
          return _buildSendingScreen();
        }

        // Show main send screen when not sending
        // Show navigation bar when main screen is active
        if (_isNavigationHidden) {
          _isNavigationHidden = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onSendingVisibilityChanged?.call(false);
            }
          });
        }
        return _buildMainSendScreen();
      },
    );
  }

  Widget _buildSendingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sending Files"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Main sending content
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current file being sent
                _buildCurrentFileCard(),

                const SizedBox(height: 20),

                // Overall progress
                _buildOverallProgressCard(),

                const SizedBox(height: 20),

                // Transfer statistics
                _buildTransferStatisticsCard(),

                const SizedBox(height: 20),

                // Sending queue
                _buildSendingQueueCard(),

                const SizedBox(height: 100), // Space for floating buttons
              ],
            ),
          ),

          // Floating Add button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _showAddFilesModal,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),

          // Cancel button (when sending is in progress)
          if (_transferManager.isSending)
            Positioned(
              bottom: 20,
              left: 20,
              child: FloatingActionButton.extended(
                onPressed: _onCancelSending,
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.cancel),
                label: const Text("Cancel"),
              ),
            ),

          // Done button (when transfer is complete)
          if (_transferManager.isSendingComplete)
            Positioned(
              bottom: 20,
              left: 20,
              child: FloatingActionButton.extended(
                onPressed: _onTransferComplete,
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.check),
                label: const Text("Done"),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainSendScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text("LocalShare")),
      body: ListView(
        padding: EdgeInsets.only(bottom: 90),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildCategoryCard(
                  Icons.folder,
                  "Files",
                  Colors.blue,
                  _pickFiles,
                ),
                _buildCategoryCard(
                  Icons.image,
                  "Photos",
                  Colors.green,
                  _pickImages,
                ),
                _buildCategoryCard(
                  Icons.videocam,
                  "Videos",
                  Colors.red,
                  _pickVideos,
                ),
                _buildCategoryCard(
                  Icons.audiotrack,
                  "Audio",
                  Colors.orange,
                  _pickAudio,
                ),
                _buildCategoryCard(Icons.apps, "Apps", Colors.purple, () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeviceAppsScreen(),
                    ),
                  );
                  if (result != null) {
                    if (result is List) {
                      // Multiple apps selected
                      if (_disposed || !mounted) return;
                      setState(() {
                        for (var app in result) {
                          if (app is AppInfo && !_selectedFiles.contains(app)) {
                            _selectedFiles.add(app);
                          }
                        }
                      });
                      // Ensure auto-scan is running when files are added
                      if (_currentIP.isNotEmpty &&
                          !_isScanning &&
                          !_disposed &&
                          mounted) {
                        _startAutoScan();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added \\${result.length} apps to selection',
                            ),
                          ),
                        );
                      }
                    } else if (result is AppInfo) {
                      // Single app selected (fallback)
                      if (_disposed || !mounted) return;
                      setState(() {
                        _selectedFiles.add(result);
                      });
                      // Ensure auto-scan is running when files are added
                      if (_currentIP.isNotEmpty &&
                          !_isScanning &&
                          !_disposed &&
                          mounted) {
                        _startAutoScan();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added \\${result.name} to selection',
                            ),
                          ),
                        );
                      }
                    }
                  }
                }),

                //clipboard
                _buildCategoryCard(
                  Icons.copy,
                  "Clipboard",
                  Colors.grey,
                  _addClipboardText,
                ),

                //text
                _buildCategoryCard(
                  Icons.text_fields,
                  "Text",
                  Colors.grey,
                  _addCustomText,
                ),
              ],
            ),
          ),

          //send options section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Send Options",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildConnectionButton(
                      Icons.qr_code_scanner,
                      "QR Scan",
                      Colors.blue,
                      _onShowQrScanner,
                    ),
                    _buildConnectionButton(
                      _isScanning ? Icons.wifi_find : Icons.refresh,
                      _isScanning ? "Scanning..." : "Scan",
                      Colors.green,
                      _scanNetworkForReceivers,
                    ),
                    _buildConnectionButton(
                      Icons.devices,
                      "Nearby",
                      Colors.orange,
                      () {},
                    ),
                    _buildConnectionButton(
                      Icons.edit,
                      "Manual IP",
                      Colors.red,
                      _showManualIPDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  "Found Devices (${_availableDevices.length})",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                // check condittion user has not selected any files then show please select any files to send
                if (_availableDevices.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isScanning ? Icons.wifi_find : Icons.wifi_off,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isScanning
                                    ? "Auto-scanning for devices..."
                                    : "No devices found on $_currentSSID",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              if (!_isScanning && _currentIP.isNotEmpty)
                                Text(
                                  "Auto-scan is active - devices will appear automatically",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ..._availableDevices.map(
                    (ip) => Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.download,
                          color: Colors.green,
                          size: 20,
                        ),
                        title: Text(ip, style: const TextStyle(fontSize: 14)),
                        subtitle: const Text(
                          "Ready to receive",
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                        trailing: const Icon(Icons.send, size: 20),
                        onTap: () {
                          if (_selectedFiles.isEmpty) {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text("No Files Selected"),
                                    content: const Text(
                                      "Please select files to send.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("OK"),
                                      ),
                                    ],
                                  ),
                            );
                          } else {
                            _sendToDevice(ip);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          //selected files section
          if (_selectedFiles.isNotEmpty || _isProcessingFiles) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Selected Files (${_selectedFiles.length})",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (_isProcessingFiles) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Processing...",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_selectedFiles.isNotEmpty)
                        Text(
                          FileUtils.formatFileSize(
                            _selectedFiles.fold(
                              0,
                              (sum, file) =>
                                  sum + (file is File ? file.lengthSync() : 0),
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Show processing message when no files yet but processing
                  if (_isProcessingFiles && _selectedFiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Processing files... Please wait",
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Show selected files list
                  if (_selectedFiles.isNotEmpty)
                    ListView.builder(
                      controller: _selectedFilesScrollController,
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      itemCount:
                          (_selectedFilesDisplayCount < _selectedFiles.length)
                              ? _selectedFilesDisplayCount + 1
                              : _selectedFiles.length,
                      itemBuilder: (context, index) {
                        if (index >= _selectedFilesDisplayCount &&
                            _selectedFilesDisplayCount <
                                _selectedFiles.length) {
                          return const Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final item = _selectedFiles[index];
                        if (item is File) {
                          String fileName = item.path.split('/').last;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 0,
                            ),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Icon(
                                _getFileIcon(fileName),
                                color: Colors.blue,
                                size: 32,
                              ),
                              title: Text(
                                fileName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                FileUtils.formatFileSize(item.lengthSync()),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _removeFile(index),
                              ),
                            ),
                          );
                        } else if (item is AppInfo) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 0,
                            ),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading:
                                  item.icon != null
                                      ? Image.memory(
                                        item.icon!,
                                        width: 32,
                                        height: 32,
                                      )
                                      : const Icon(
                                        Icons.android,
                                        color: Colors.purple,
                                        size: 32,
                                      ),
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                item.packageName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _removeFile(index),
                              ),
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  void _handleQrScanned(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      List<String> data = barcode.rawValue!.split("|");
      if (data.length == 2) {
        _sendToDevice(data[1]);
        if (mounted) {
          setState(() => _showQrScanner = false);
          // Show navigation bar when QR scanner is closed
          if (_isNavigationHidden) {
            _isNavigationHidden = false;
            widget.onQrScannerVisibilityChanged?.call(false);
          }
        }
      }
    }
  }

  Widget _buildQrScanner() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 59, 42, 96),
        elevation: 0,
        title: const Text(
          "Scan QR Code",
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () {
            if (mounted) {
              setState(() => _showQrScanner = false);
              // Show navigation bar when QR scanner is closed
              if (_isNavigationHidden) {
                _isNavigationHidden = false;
                widget.onQrScannerVisibilityChanged?.call(false);
              }
            }
          },
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 59, 42, 96).withOpacity(0.7),
                  const Color.fromARGB(255, 59, 42, 96).withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withOpacity(0.1)),
          ),
          Center(
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 59, 42, 96).withOpacity(0.18),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: const Color.fromARGB(
                    255,
                    97,
                    55,
                    187,
                  ).withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(
                      255,
                      59,
                      42,
                      96,
                    ).withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: MobileScanner(onDetect: _handleQrScanned),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Point your camera at the receiver's QR code",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Text(
                      "The QR code contains the receiver's WiFi and IP info for secure transfer.",
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    bool isProcessing =
        _isProcessingFiles &&
        ((label == "Videos" && _isFilePickerActive) ||
            (label == "Photos" && _isFilePickerActive) ||
            (label == "Files" && _isFilePickerActive) ||
            (label == "Audio" && _isFilePickerActive));

    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isProcessing)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 32, color: color),
            const SizedBox(height: 4),
            Text(
              isProcessing ? "Processing..." : label,
              style: TextStyle(
                fontSize: 12,
                color:
                    isProcessing
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                fontStyle: isProcessing ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualIPDialog() {
    // Check if files are selected first
    if (_selectedFiles.isEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("No Files Selected"),
              content: const Text(
                "Please select files to send before entering IP address.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
      return;
    }

    TextEditingController ipController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Enter IP Address"),
            content: TextField(
              controller: ipController,
              decoration: const InputDecoration(
                hintText: "192.168.1.100",
                labelText: "Receiver IP Address",
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  if (ipController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _sendToDevice(ipController.text);
                  }
                },
                child: const Text("Connect"),
              ),
            ],
          ),
    );
  }

  Widget _buildConnectionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    String ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return Icons.image;
    if (['mp4', 'avi', 'mov'].contains(ext)) return Icons.video_file;
    if (['mp3', 'wav', 'aac'].contains(ext)) return Icons.audio_file;
    if (['pdf', 'doc', 'docx'].contains(ext)) return Icons.description;
    if (ext == 'apk') return Icons.android;
    return Icons.insert_drive_file;
  }

  Future<void> _addClipboardText() async {
    if (_isFilePickerActive || _disposed || !mounted) return;

    try {
      _isFilePickerActive = true;
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        // Create a temporary file with clipboard text
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${tempDir.path}/clipboard_$timestamp.txt');
        await file.writeAsString(data.text!);

        if (_disposed || !mounted) return;
        setState(() {
          _selectedFiles.add(file);
        });

        // Ensure auto-scan is running when files are added
        if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
          _startAutoScan();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added clipboard text (${data.text!.length} characters)',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in clipboard')),
          );
        }
      }
    } catch (e) {
      print('Clipboard error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing clipboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isFilePickerActive = false;
    }
  }

  Future<void> _addCustomText() async {
    if (_isFilePickerActive || _disposed || !mounted) return;

    try {
      _isFilePickerActive = true;
      final TextEditingController textController = TextEditingController();
      final TextEditingController fileNameController = TextEditingController(
        text: 'custom_text.txt',
      );

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Add Custom Text'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fileNameController,
                    decoration: const InputDecoration(
                      labelText: 'File Name',
                      hintText: 'Enter file name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Text Content',
                      hintText: 'Enter your text here...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    maxLength: 10000,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _isFilePickerActive = false;
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (textController.text.isNotEmpty) {
                      try {
                        final tempDir = await getTemporaryDirectory();
                        final timestamp = DateTime.now().millisecondsSinceEpoch;
                        final fileName =
                            fileNameController.text.trim().isEmpty
                                ? 'custom_text_$timestamp.txt'
                                : fileNameController.text.trim();
                        final file = File('${tempDir.path}/$fileName');
                        await file.writeAsString(textController.text);

                        if (_disposed || !mounted) return;
                        setState(() {
                          _selectedFiles.add(file);
                        });

                        // Ensure auto-scan is running when files are added
                        if (_currentIP.isNotEmpty &&
                            !_isScanning &&
                            !_disposed &&
                            mounted) {
                          _startAutoScan();
                        }

                        Navigator.pop(context);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added custom text file: $fileName',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Custom text error: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error creating text file: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter some text'),
                          ),
                        );
                      }
                    }
                    _isFilePickerActive = false;
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
      );
    } catch (e) {
      print('Custom text dialog error: $e');
      _isFilePickerActive = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening text dialog: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onShowQrScanner() async {
    // Check if files are selected first
    if (_selectedFiles.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("No Files Selected"),
                content: const Text(
                  "Please select files to send before scanning QR code.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
      }
      return;
    }

    if (await Permission.camera.isGranted) {
      if (mounted) {
        setState(() {
          _showQrScanner = true;
          widget.onQrScannerVisibilityChanged?.call(true);
        });
      }
    } else {
      final result = await Permission.camera.request();
      if (result.isGranted && mounted) {
        setState(() {
          _showQrScanner = true;
          widget.onQrScannerVisibilityChanged?.call(true);
        });
      } else if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Camera Permission Required'),
                content: const Text(
                  'Camera access is needed to scan QR codes.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Open Settings'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
        );
      }
    }
  }

  // Sending screen helper methods
  Widget _buildCurrentFileCard() {
    final isComplete = _transferManager.isSendingComplete;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            isComplete
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isComplete
                  ? Colors.green.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle
                    : _getFileIcon(_transferManager.sendingFileName),
                color: isComplete ? Colors.green : Colors.blue,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete
                          ? "Transfer Complete"
                          : _transferManager.sendingFileName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isComplete ? Colors.green : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isComplete
                          ? "All files sent successfully"
                          : "File ${_transferManager.currentSendingIndex + 1} of ${_transferManager.sendingFiles.length}",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _transferManager.sendProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? Colors.green : Colors.blue,
              ),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Progress details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isComplete
                    ? "100%"
                    : "${(_transferManager.sendProgress * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isComplete ? Colors.green : Colors.blue,
                ),
              ),
              if (!isComplete)
                Text(
                  "${_transferManager.sendSpeed.toStringAsFixed(1)} MB/s",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgressCard() {
    final isComplete = _transferManager.isSendingComplete;
    final totalFiles = _transferManager.sendingFiles.length;
    final completedFiles =
        isComplete ? totalFiles : _transferManager.currentSendingIndex;
    final currentFileProgress =
        isComplete ? 1.0 : _transferManager.sendProgress;
    final overallProgress =
        isComplete ? 1.0 : (completedFiles + currentFileProgress) / totalFiles;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.upload_rounded,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isComplete ? "Transfer Complete" : "Overall Progress",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overall progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isComplete
                    ? "Completed: $totalFiles/$totalFiles files"
                    : "Completed: $completedFiles/$totalFiles files",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              Text(
                isComplete
                    ? "100%"
                    : "${(overallProgress * 100).toStringAsFixed(1)}%",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferStatisticsCard() {
    final totalSize = _transferManager.sendingFiles.fold<int>(
      0,
      (sum, file) => sum + file.lengthSync(),
    );
    final completedSize = _transferManager.sendingFiles
        .take(_transferManager.currentSendingIndex)
        .fold<int>(0, (sum, file) => sum + file.lengthSync());
    final currentFileSize =
        _transferManager.sendingFiles.isNotEmpty
            ? _transferManager
                .sendingFiles[_transferManager.currentSendingIndex]
                .lengthSync()
            : 0;
    final sentSize =
        completedSize +
        (currentFileSize * _transferManager.sendProgress).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                "Transfer Statistics",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  "Files",
                  "${_transferManager.currentSendingIndex}/${_transferManager.sendingFiles.length}",
                  Icons.file_copy,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  "Data",
                  "${FileUtils.formatFileSize(sentSize)}/${FileUtils.formatFileSize(totalSize)}",
                  Icons.storage,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  "Speed",
                  "${_transferManager.sendSpeed.toStringAsFixed(1)} MB/s",
                  Icons.speed,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  "Status",
                  "Active",
                  Icons.info,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSendingQueueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.queue, color: Colors.purple, size: 24),
              const SizedBox(width: 8),
              Text(
                "Sending Queue",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ..._transferManager.sendingFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            final isCurrent = index == _transferManager.currentSendingIndex;
            final isCompleted = index < _transferManager.currentSendingIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isCurrent
                        ? Colors.blue.withOpacity(0.1)
                        : isCompleted
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isCurrent
                          ? Colors.blue.withOpacity(0.3)
                          : isCompleted
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCurrent
                        ? Icons.upload
                        : isCompleted
                        ? Icons.check_circle
                        : Icons.schedule,
                    color:
                        isCurrent
                            ? Colors.blue
                            : isCompleted
                            ? Colors.green
                            : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.path.split('/').last,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isCurrent
                                    ? Colors.blue
                                    : isCompleted
                                    ? Colors.green
                                    : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          FileUtils.formatFileSize(file.lengthSync()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Text(
                      "${(_transferManager.sendProgress * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showAddFilesModal() {
    if (_isFilePickerActive || _disposed || !mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Add More Files",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),

                // File type options
                Expanded(
                  child: GridView.count(
                    padding: const EdgeInsets.all(20),
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildAddFileOption(
                        Icons.folder,
                        "Files",
                        Colors.blue,
                        _pickFiles,
                      ),
                      _buildAddFileOption(
                        Icons.image,
                        "Photos",
                        Colors.green,
                        _pickImages,
                      ),
                      _buildAddFileOption(
                        Icons.videocam,
                        "Videos",
                        Colors.red,
                        _pickVideos,
                      ),
                      _buildAddFileOption(
                        Icons.audiotrack,
                        "Audio",
                        Colors.orange,
                        _pickAudio,
                      ),
                      _buildAddFileOption(
                        Icons.apps,
                        "Apps",
                        Colors.purple,
                        () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeviceAppsScreen(),
                            ),
                          );
                          if (result != null) {
                            if (result is List) {
                              if (_disposed || !mounted) return;
                              setState(() {
                                for (var app in result) {
                                  if (app is AppInfo &&
                                      !_selectedFiles.contains(app)) {
                                    _selectedFiles.add(app);
                                  }
                                }
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added ${result.length} apps to queue',
                                    ),
                                  ),
                                );
                              }
                            } else if (result is AppInfo) {
                              if (_disposed || !mounted) return;
                              setState(() {
                                _selectedFiles.add(result);
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added ${result.name} to queue',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      _buildAddFileOption(
                        Icons.copy,
                        "Clipboard",
                        Colors.grey,
                        _addClipboardText,
                      ),
                      _buildAddFileOption(
                        Icons.text_fields,
                        "Text",
                        Colors.grey,
                        _addCustomText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildAddFileOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onTransferComplete() {
    // Show navigation bar immediately when Done is clicked
    if (_isNavigationHidden) {
      _isNavigationHidden = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSendingVisibilityChanged?.call(false);
        }
      });
    }

    // Clear selected files and stop sending state
    setState(() {
      _selectedFiles.clear();
      _availableDevices.clear();
    });

    // Stop the sending state to return to main screen
    _transferManager.stopSending();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Transfer completed successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onCancelSending() {
    // Stop sending and return to main send screen
    setState(() {
      _selectedFiles.clear();
      _availableDevices.clear();
    });
    _transferManager.stopSending();
  }
}
