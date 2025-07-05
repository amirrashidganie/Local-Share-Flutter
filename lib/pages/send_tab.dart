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
  const SendTab({super.key, this.onQrScannerVisibilityChanged});

  final ValueChanged<bool>? onQrScannerVisibilityChanged;

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

  Future<void> _pickFiles() async {
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
      setState(() {
        _selectedFiles.addAll(result.paths.map((path) => File(path!)));
      });
      // Ensure auto-scan is running when files are added
      if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
        _startAutoScan();
      }
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultipleMedia();
    if (images.isNotEmpty) {
      if (_disposed || !mounted) return;
      setState(() {
        _selectedFiles.addAll(images.map((image) => File(image.path)));
      });
      // Ensure auto-scan is running when files are added
      if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
        _startAutoScan();
      }
    }
  }

  Future<void> _pickVideos() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null) {
      if (_disposed || !mounted) return;
      setState(() {
        _selectedFiles.addAll(result.paths.map((path) => File(path!)));
      });
      // Ensure auto-scan is running when files are added
      if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
        _startAutoScan();
      }
    }
  }

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result != null) {
      if (_disposed || !mounted) return;
      setState(() {
        _selectedFiles.addAll(result.paths.map((path) => File(path!)));
      });
      // Ensure auto-scan is running when files are added
      if (_currentIP.isNotEmpty && !_isScanning && !_disposed && mounted) {
        _startAutoScan();
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
  }

  @override
  void dispose() {
    _disposed = true;
    _selectedFilesScrollController.dispose();
    // Stop auto-scan immediately
    _stopAutoScan();
    _autoScanTimer?.cancel();
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transferManager.stopSending();
    });
    _selectedFiles.clear();
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
        setState(() {
          _availableDevices.add(ip);
        });
      }
    } catch (e) {
      // Device not available
    }
  }

  Future<void> _sendToDevice(String receiverIP) async {
    if (_disposed || !mounted) return;
    final filesToSend = _selectedFiles.whereType<File>().toList();

    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _transferManager.startSending(filesToSend);
      }
    });

    try {
      for (int i = 0; i < filesToSend.length; i++) {
        dynamic file = filesToSend[i];
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
          _transferManager.stopSending();

          // Clear selected files and show success message
          setState(() => _selectedFiles.clear());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("All files sent successfully!")),
          );

          // Restart device scanning after successful transfer
          _restartDeviceScanning();
        }
      });
    } catch (e) {
      // Use addPostFrameCallback to avoid calling notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transferManager.stopSending();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Failed to send files: $e")));
        }
      });
    }
  }

  Future<void> _sendSingleFile(dynamic file, String receiverIP) async {
    if (_disposed || !mounted) return;
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
    socket.add([
      (totalSize >> 24) & 0xFF,
      (totalSize >> 16) & 0xFF,
      (totalSize >> 8) & 0xFF,
      totalSize & 0xFF,
    ]);

    await socket.flush();

    int sentBytes = 0;
    DateTime startTime = DateTime.now();

    await for (List<int> chunk in file.openRead()) {
      socket.add(chunk);
      sentBytes += chunk.length;

      double progress = sentBytes / totalSize;
      double elapsedSeconds =
          DateTime.now().difference(startTime).inMilliseconds / 1000;
      double speed =
          elapsedSeconds > 0 ? (sentBytes / (1024 * 1024)) / elapsedSeconds : 0;

      // Use addPostFrameCallback to avoid calling notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transferManager.updateSendProgress(progress, fileName, speed);
        }
      });
    }

    await socket.flush();
    await socket.close();
  }

  @override
  Widget build(BuildContext context) {
    if (_showQrScanner) {
      return _buildQrScanner();
    }
    return Scaffold(
      // backgroundColor: const Color(0xFF2C1D4D),
      appBar: AppBar(
        // backgroundColor: const Color(0xFF2C1D4D),
        title: const Text("LocalShare"),
      ),
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
          if (_selectedFiles.isNotEmpty) ...[
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
                      Text(
                        "Selected Files (${_selectedFiles.length})",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
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
                          _selectedFilesDisplayCount < _selectedFiles.length) {
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
                                color: Theme.of(context).colorScheme.onSurface,
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
                                color: Theme.of(context).colorScheme.onSurface,
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

          // Transfer progress
          ListenableBuilder(
            listenable: _transferManager,
            builder: (context, child) {
              if (!_transferManager.isSending) return const Spacer();

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.upload, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          "Sending Files",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          "${_transferManager.currentSendingIndex + 1}/${_transferManager.sendingFiles.length}",
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _transferManager.sendingFileName,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _transferManager.sendProgress,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${(_transferManager.sendProgress * 100).toStringAsFixed(1)}%",
                        ),
                        Text(
                          "${_transferManager.sendSpeed.toStringAsFixed(1)} MB/s",
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
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
          widget.onQrScannerVisibilityChanged?.call(false);
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
              widget.onQrScannerVisibilityChanged?.call(false);
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
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
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
    try {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing clipboard: $e')),
        );
      }
    }
  }

  Future<void> _addCustomText() async {
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
                onPressed: () => Navigator.pop(context),
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
                            content: Text('Added custom text file: $fileName'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating text file: $e'),
                          ),
                        );
                      }
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter some text')),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
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
}
