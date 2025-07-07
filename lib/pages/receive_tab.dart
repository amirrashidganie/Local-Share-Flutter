import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:localshare/utils/transfer_manager.dart';
import 'package:localshare/utils/device_discovery.dart';
import 'package:localshare/utils/settings_manager.dart';
import 'package:localshare/components/receivingfilesscreen/current_receiving_files.dart';
import 'package:localshare/components/receivingfilesscreen/received_files_widget.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key, this.onReceivingVisibilityChanged});

  final ValueChanged<bool>? onReceivingVisibilityChanged;

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> with TickerProviderStateMixin {
  String? qrData;
  String? receiverIP;
  String deviceName = "Unknown Device";
  ServerSocket? _server;
  bool _isReadyToReceive = false;
  bool _isModalShown = false;
  final TransferManager _transferManager = TransferManager();
  final DeviceDiscovery _deviceDiscovery = DeviceDiscovery();

  // Network monitoring
  Timer? _networkSpeedTimer;
  double _currentNetworkSpeed = 0.0;
  String _connectionType = "WiFi";
  String _ssid = "";

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Navigation visibility tracking
  bool _isNavigationHidden = false;

  @override
  void initState() {
    super.initState();
    _initializeReceiver();
    _startNetworkMonitoring();
    _initializeAnimations();

    // Reset any lingering receiving state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _transferManager.resetReceivingState();
      }
    });
  }

  Future<void> _initializeReceiver() async {
    await _requestPermissions();
    await _fetchDeviceName();
    await _checkConnection();
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.location,
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();
    } catch (e) {
      print('Permission request error: $e');
    }

    try {
      if (!(await Permission.location.serviceStatus.isEnabled)) {
        // Prompt user to enable location services
      }
    } catch (e) {
      print('Location service check error: $e');
    }
  }

  Future<void> _fetchDeviceName() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (mounted) setState(() => deviceName = androidInfo.model);
    } catch (e) {
      // Handle silently
    }
  }

  Future<void> _checkConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final info = NetworkInfo();
      final ssid = await info.getWifiName();
      receiverIP = await info.getWifiIP();

      print(
        'DEBUG: connectivityResult=$connectivityResult, ssid=$ssid, receiverIP=$receiverIP',
      );

      if (connectivityResult.contains(ConnectivityResult.wifi) &&
          receiverIP != null &&
          ssid != null) {
        if (mounted) {
          setState(() {
            qrData = "$ssid|$receiverIP";
            _isReadyToReceive = true;
          });
        }
        _startServer();
        _deviceDiscovery.announceReceiver(deviceName, receiverIP!);
      } else {
        if (mounted) setState(() => _isReadyToReceive = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isReadyToReceive = false);
    }
  }

  Future<void> _startServer() async {
    try {
      final settingsManager = SettingsManager();
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        settingsManager.transferPort,
      );
      _server!.listen(
        (Socket socket) async {
          if (mounted) {
            try {
              await _handleFileReceive(socket);
            } catch (e) {
              print('Error handling file receive: $e');
              // Don't crash the server, just log the error
            }
          }
        },
        onError: (error) {
          print('Server error: $error');
          // Handle server errors gracefully
        },
        onDone: () {
          print('Server done');
        },
      );
    } catch (e) {
      print('Server start error: $e');
      // Handle silently but log for debugging
    }
  }

  Future<void> _handleFileReceive(Socket socket) async {
    try {
      String fileName = "";
      int expectedSize = 0;
      bool headerParsed = false;
      DateTime startTime = DateTime.now();
      int receivedBytes = 0;

      // Use streaming approach instead of loading everything into memory
      final settingsManager = SettingsManager();
      Directory saveDir = await settingsManager.getCurrentSaveDirectory();

      // Create the directory if it doesn't exist
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // Add timeout for receiving
      bool timeoutOccurred = false;
      Timer? timeoutTimer;
      IOSink? fileSink;

      void startTimeout() {
        timeoutTimer?.cancel();
        timeoutTimer = Timer(
          Duration(seconds: settingsManager.networkTimeout),
          () {
            timeoutOccurred = true;
            fileSink?.close();
            socket.close();
          },
        );
      }

      startTimeout();

      // Use a more robust approach to handle the socket stream
      try {
        await for (List<int> data in socket) {
          if (!mounted || timeoutOccurred) {
            fileSink?.close();
            return;
          }

          // Reset timeout on each data chunk
          startTimeout();

          if (!headerParsed && data.length > 5) {
            // Parse header from first chunk
            int nameLength = data[0];
            if (data.length >= 5 + nameLength) {
              fileName = String.fromCharCodes(data.sublist(1, 1 + nameLength));
              expectedSize =
                  (data[1 + nameLength] << 24) |
                  (data[2 + nameLength] << 16) |
                  (data[3 + nameLength] << 8) |
                  data[4 + nameLength];
              headerParsed = true;

              // Check file size limit (15GB)
              if (expectedSize > 15 * 1024 * 1024 * 1024) {
                throw Exception('File size exceeds 15GB limit');
              }

              // Create file with proper filename
              String finalFileName = fileName;
              int counter = 1;
              while (await File('${saveDir.path}/$finalFileName').exists()) {
                int lastDotIndex = fileName.lastIndexOf('.');
                if (lastDotIndex > 0) {
                  String nameWithoutExt = fileName.substring(0, lastDotIndex);
                  String extension = fileName.substring(lastDotIndex);
                  finalFileName = '${nameWithoutExt}_$counter$extension';
                } else {
                  finalFileName = '${fileName}_$counter';
                }
                counter++;
              }

              final actualFile = File('${saveDir.path}/$finalFileName');
              fileSink = actualFile.openWrite();

              // Start receiving state immediately
              _transferManager.startReceiving(fileName, expectedSize);

              // Force UI update
              if (mounted) {
                setState(() {});
              }

              // Write file data (excluding header)
              List<int> fileData = data.sublist(5 + nameLength);
              if (fileData.isNotEmpty) {
                fileSink!.add(fileData);
                receivedBytes += fileData.length;
              }
            }
          } else if (headerParsed && fileSink != null) {
            // Continue receiving file data
            fileSink!.add(data);
            receivedBytes += data.length;

            double progress = receivedBytes / expectedSize;
            double elapsedSeconds =
                DateTime.now().difference(startTime).inMilliseconds / 1000;
            double speed =
                elapsedSeconds > 0 ? receivedBytes / elapsedSeconds : 0;

            // Update progress dynamically based on file size for better user experience
            // For very large files (>100MB), update every 256KB
            // For large files (>10MB), update every 512KB
            // For smaller files, update every 1MB
            int updateInterval = 1024 * 1024; // Default 1MB
            if (expectedSize > 100 * 1024 * 1024) {
              updateInterval = 256 * 1024; // 256KB for very large files
            } else if (expectedSize > 10 * 1024 * 1024) {
              updateInterval = 512 * 1024; // 512KB for large files
            }

            if (receivedBytes % updateInterval == 0 ||
                receivedBytes == expectedSize) {
              double clampedProgress = progress.clamp(0.0, 1.0);
              _transferManager.updateReceiveProgress(
                fileName,
                clampedProgress,
                speed,
                receivedBytes,
              );

              // Force UI update
              if (mounted) {
                setState(() {});
              }
            }
          }
        }
      } catch (streamError) {
        print('Stream error: $streamError');
        // Handle stream errors gracefully
        if (fileSink != null) {
          await fileSink!.close();
        }
        throw streamError;
      }

      timeoutTimer?.cancel();
      await fileSink?.close();

      if (timeoutOccurred) {
        throw Exception('Transfer timeout - connection lost');
      }

      if (headerParsed && receivedBytes > 0) {
        _transferManager.completeReceiving(fileName);

        // Force UI update
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error receiving file: $e');
      if (mounted) {
        String errorMessage = "Error receiving file";
        if (e.toString().contains("timeout")) {
          errorMessage = "Transfer timeout - connection lost";
        } else if (e.toString().contains("15GB")) {
          errorMessage = "File size exceeds 15GB limit";
        } else if (e.toString().contains("Permission denied")) {
          errorMessage = "Permission denied. Please check storage permissions.";
        } else if (e.toString().contains(
          "Stream has already been listened to",
        )) {
          errorMessage = "Connection error - please try again";
        } else if (e.toString().contains("SocketException")) {
          errorMessage = "Connection lost - please try again";
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
    } finally {
      try {
        socket.close();
      } catch (e) {
        print('Error closing socket: $e');
      }
    }
  }

  @override
  void dispose() {
    _server?.close();
    _deviceDiscovery.stopDiscovery();
    _networkSpeedTimer?.cancel();
    _pulseController.dispose();
    // Reset transfer manager state to avoid any lingering state
    if (_transferManager.isReceiving) {
      _transferManager.resetReceivingState();
    }
    // Close modal if open
    if (_isModalShown) {
      Navigator.of(context).pop();
      _isModalShown = false;
    }
    // Ensure navigation bar is shown when widget is disposed
    if (_isNavigationHidden) {
      _isNavigationHidden = false;
      widget.onReceivingVisibilityChanged?.call(false);
    }
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  void _startNetworkMonitoring() {
    _networkSpeedTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _updateNetworkInfo();
      }
    });
  }

  Future<void> _updateNetworkInfo() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final info = NetworkInfo();

      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        _connectionType = "WiFi";
        _ssid = await info.getWifiName() ?? "Unknown Network";
      } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
        _connectionType = "Mobile Data";
        _ssid = "Cellular Network";
      } else {
        _connectionType = "No Connection";
        _ssid = "Disconnected";
      }

      // Calculate network speed based on active transfers
      if (_transferManager.isReceiving) {
        double totalSpeed = 0.0;
        for (var file in _transferManager.receivingFiles) {
          if (!file.isComplete) {
            totalSpeed += file.speed;
          }
        }
        _currentNetworkSpeed = totalSpeed;
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Network monitoring error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _transferManager,
      builder: (context, child) {
        // Debug logging to track state
        print(
          'DEBUG: ReceiveTab build - isReceiving: ${_transferManager.isReceiving}, isTransferComplete: ${_transferManager.isTransferComplete}',
        );
        print(
          'DEBUG: ReceiveTab build - receiving files count: ${_transferManager.receivingFiles.length}',
        );

        // Show dedicated receiving screen when receiving files or when transfer is complete
        if (_transferManager.isReceiving ||
            _transferManager.isTransferComplete) {
          print('DEBUG: Showing receiving screen');
          // Hide navigation bar when receiving screen is active
          if (!_isNavigationHidden) {
            _isNavigationHidden = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onReceivingVisibilityChanged?.call(true);
              }
            });
          }
          return _buildReceivingScreen();
        }

        print('DEBUG: Showing main receive screen');
        // Show main receive screen when not receiving
        // Show navigation bar when main screen is active
        if (_isNavigationHidden) {
          _isNavigationHidden = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onReceivingVisibilityChanged?.call(false);
            }
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text("LocalShare"),
            actions: [
              // Show settings button to access save location
              IconButton(
                icon: const Icon(Icons.info),
                onPressed: () => _showSaveLocationInfo(),
              ),
              // Debug button to test receiving screen
              IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: () {
                  print('DEBUG: Manual test - starting receiving');
                  _transferManager.startReceiving('test_file.txt', 1024);
                  setState(() {});
                },
              ),
            ],
          ),
          body: SingleChildScrollView(child: _buildMainReceiveScreen()),
        );
      },
    );
  }

  Widget _buildReceivingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _transferManager.isTransferComplete
              ? "Transfer Complete"
              : "Receiving Files",
        ),
        backgroundColor:
            _transferManager.isTransferComplete ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Main receiving content
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current receiving files
                _buildCurrentReceivingFilesCard(),

                const SizedBox(height: 20),

                // Overall progress
                _buildOverallProgressCard(),

                const SizedBox(height: 20),

                // Transfer statistics
                _buildTransferStatisticsCard(),

                const SizedBox(height: 20),

                // Save location info
                _buildSaveLocationInfo(),

                const SizedBox(height: 100), // Space for floating buttons
              ],
            ),
          ),

          // Cancel button (when receiving is in progress)
          if (_transferManager.isReceiving &&
              !_transferManager.isTransferComplete)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: _onCancelReceiving,
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.cancel),
                label: const Text("Cancel"),
              ),
            ),

          // Done button (when transfer is complete)
          if (_transferManager.isTransferComplete)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
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

  Widget _buildMainReceiveScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/protection.png', width: 100, height: 100),
          const SizedBox(height: 20),
          Text(
            deviceName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            _isReadyToReceive ? "Ready to receive files" : "Connect to WiFi",
            style: TextStyle(
              fontSize: 16,
              color: _isReadyToReceive ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 30),
          if (_isReadyToReceive && qrData != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData!,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Scan this QR code to receive files",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            // Save location info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Files will be saved to: ${_getSaveLocationDisplay()}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),

          // Show current receiving files (if any)
          const CurrentReceivingFiles(),

          // Show received files history
          const ReceivedFilesWidget(),
        ],
      ),
    );
  }

  String _getSaveLocationDisplay() {
    final settingsManager = SettingsManager();
    switch (settingsManager.saveLocation) {
      case 'Downloads':
        return 'Downloads folder';
      case 'DCIM':
        return 'DCIM folder';
      case 'Documents':
        return 'Documents folder';
      case 'Custom':
        return 'Custom location';
      default:
        return 'Documents/LocalShare folder';
    }
  }

  IconData _getFileTypeIcon([String? fileName]) {
    final file = fileName ?? _transferManager.receivingFileName;
    final extension = file.toLowerCase().split('.').last;

    if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'svg',
      'ico',
    ].contains(extension)) {
      return Icons.image;
    } else if ([
      'mp4',
      'avi',
      'mov',
      'mkv',
      'wmv',
      'flv',
      'webm',
      'm4v',
    ].contains(extension)) {
      return Icons.video_file;
    } else if ([
      'mp3',
      'wav',
      'flac',
      'aac',
      'ogg',
      'm4a',
      'wma',
    ].contains(extension)) {
      return Icons.audio_file;
    } else if (['pdf', 'epub', 'mobi'].contains(extension)) {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx', 'rtf', 'odt'].contains(extension)) {
      return Icons.description;
    } else if (['xls', 'xlsx', 'csv', 'ods'].contains(extension)) {
      return Icons.table_chart;
    } else if (['ppt', 'pptx', 'odp'].contains(extension)) {
      return Icons.slideshow;
    } else if ([
      'txt',
      'md',
      'json',
      'xml',
      'html',
      'css',
      'js',
    ].contains(extension)) {
      return Icons.text_snippet;
    } else if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].contains(extension)) {
      return Icons.archive;
    } else if (['apk', 'ipa'].contains(extension)) {
      return Icons.android;
    } else if (['exe', 'msi', 'dmg', 'deb', 'rpm'].contains(extension)) {
      return Icons.computer;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor([String? fileName]) {
    final file = fileName ?? _transferManager.receivingFileName;
    final extension = file.toLowerCase().split('.').last;

    if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'svg',
      'ico',
    ].contains(extension)) {
      return Colors.purple;
    } else if ([
      'mp4',
      'avi',
      'mov',
      'mkv',
      'wmv',
      'flv',
      'webm',
      'm4v',
    ].contains(extension)) {
      return Colors.red;
    } else if ([
      'mp3',
      'wav',
      'flac',
      'aac',
      'ogg',
      'm4a',
      'wma',
    ].contains(extension)) {
      return Colors.orange;
    } else if (['pdf', 'epub', 'mobi'].contains(extension)) {
      return Colors.red;
    } else if (['doc', 'docx', 'rtf', 'odt'].contains(extension)) {
      return Colors.blue;
    } else if (['xls', 'xlsx', 'csv', 'ods'].contains(extension)) {
      return Colors.green;
    } else if (['ppt', 'pptx', 'odp'].contains(extension)) {
      return Colors.orange;
    } else if ([
      'txt',
      'md',
      'json',
      'xml',
      'html',
      'css',
      'js',
    ].contains(extension)) {
      return Colors.grey;
    } else if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].contains(extension)) {
      return Colors.amber;
    } else if (['apk', 'ipa'].contains(extension)) {
      return Colors.green;
    } else if (['exe', 'msi', 'dmg', 'deb', 'rpm'].contains(extension)) {
      return Colors.indigo;
    } else {
      return Colors.blue;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
    }
  }

  void _showSaveLocationInfo() {
    final settingsManager = SettingsManager();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Save Location"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Current save location: ${settingsManager.saveLocation}"),
                const SizedBox(height: 16),
                const Text(
                  "To change the save location, go to Settings > Network Settings > Save Location",
                  style: TextStyle(fontSize: 14),
                ),
              ],
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

  Widget _buildFileItem(ReceivingFile file) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            file.isComplete
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              file.isComplete
                  ? Colors.green.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File header row
          Row(
            children: [
              // File type icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getFileTypeColor(file.fileName).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileTypeIcon(file.fileName),
                  size: 20,
                  color: _getFileTypeColor(file.fileName),
                ),
              ),
              const SizedBox(width: 12),

              // File name and size
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(file.fileSize),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      file.isComplete
                          ? Colors.green.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  file.isComplete ? "Complete" : "Receiving",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: file.isComplete ? Colors.green : Colors.blue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress section
          if (!file.isComplete) ...[
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: file.progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),

            // Progress details row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Progress: ${(file.progress * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      "ETA: ${file.estimatedTimeRemaining}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Speed: ${file.formattedSpeed}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      "${_formatFileSize(file.receivedBytes)} / ${_formatFileSize(file.fileSize)}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            // Completion indicator
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  "File received successfully",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Save Location",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  _getSaveLocationDisplay(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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

  // Receiving screen helper methods
  Widget _buildCurrentReceivingFilesCard() {
    final isComplete = _transferManager.isTransferComplete;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
                isComplete ? Icons.check_circle : Icons.download_rounded,
                color: isComplete ? Colors.green : Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isComplete ? "Transfer Complete" : "Receiving Files",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Files list
          ..._transferManager.receivingFiles.map(
            (file) => _buildFileItem(file),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgressCard() {
    final isComplete = _transferManager.isTransferComplete;
    final totalFiles = _transferManager.receivingFiles.length;
    final completedFiles =
        _transferManager.receivingFiles.where((f) => f.isComplete).length;
    final overallProgress = totalFiles > 0 ? completedFiles / totalFiles : 0.0;

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
                isComplete ? Icons.check_circle : Icons.download_rounded,
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
                "Completed: $completedFiles/$totalFiles files",
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
    final isComplete = _transferManager.isTransferComplete;
    final totalFiles = _transferManager.receivingFiles.length;
    final completedFiles =
        _transferManager.receivingFiles.where((f) => f.isComplete).length;
    final totalSize = _transferManager.receivingFiles.fold<int>(
      0,
      (sum, file) => sum + file.fileSize,
    );
    final receivedSize = _transferManager.receivingFiles.fold<int>(
      0,
      (sum, file) => sum + file.receivedBytes,
    );
    final avgSpeed =
        _transferManager.receivingFiles.isNotEmpty
            ? _transferManager.receivingFiles
                    .map((f) => f.speed)
                    .reduce((a, b) => a + b) /
                _transferManager.receivingFiles.length
            : 0.0;

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
                  "$completedFiles/$totalFiles",
                  Icons.file_copy,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  "Data",
                  "${_formatFileSize(receivedSize)}/${_formatFileSize(totalSize)}",
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
                  "Avg Speed",
                  _formatSpeed(avgSpeed),
                  Icons.speed,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  "Status",
                  isComplete ? "Complete" : "Active",
                  Icons.info,
                  isComplete ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onCancelReceiving() {
    // Show confirmation dialog before canceling
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Cancel Receiving"),
            content: const Text(
              "Are you sure you want to cancel the receiving? This will stop the current transfer.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("No"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Stop receiving and return to main receive screen
                  setState(() {
                    _transferManager.resetReceivingState();
                  });
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Yes, Cancel"),
              ),
            ],
          ),
    );
  }

  void _onTransferComplete() {
    // Show navigation bar immediately when Done is clicked
    if (_isNavigationHidden) {
      _isNavigationHidden = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onReceivingVisibilityChanged?.call(false);
        }
      });
    }

    // Clear selected files and stop receiving state
    setState(() {
      _transferManager.resetReceivingState();
    });

    // Stop the receiving state to return to main screen
    _transferManager.resetReceivingState();
  }
}
