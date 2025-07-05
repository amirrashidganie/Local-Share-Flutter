import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:localshare/utils/transfer_manager.dart';
import 'package:localshare/utils/device_discovery.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key});

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  String? qrData;
  String? receiverIP;
  String deviceName = "Unknown Device";
  ServerSocket? _server;
  bool _isReadyToReceive = false;
  final TransferManager _transferManager = TransferManager();
  final DeviceDiscovery _deviceDiscovery = DeviceDiscovery();

  @override
  void initState() {
    super.initState();
    _initializeReceiver();
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
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 5000);
      _server!.listen((Socket socket) async {
        if (mounted) await _handleFileReceive(socket);
      });
    } catch (e) {
      // Handle silently
    }
  }

  Future<void> _handleFileReceive(Socket socket) async {
    try {
      List<int> allData = [];
      String fileName = "";
      int expectedSize = 0;
      bool headerParsed = false;
      DateTime startTime = DateTime.now();

      await for (List<int> data in socket) {
        allData.addAll(data);

        if (!headerParsed && allData.length > 5) {
          int nameLength = allData[0];
          if (allData.length >= 5 + nameLength) {
            fileName = String.fromCharCodes(allData.sublist(1, 1 + nameLength));
            expectedSize =
                (allData[1 + nameLength] << 24) |
                (allData[2 + nameLength] << 16) |
                (allData[3 + nameLength] << 8) |
                allData[4 + nameLength];
            headerParsed = true;
            _transferManager.startReceiving(fileName);
          }
        }

        if (headerParsed && mounted) {
          double progress =
              (allData.length - 5 - fileName.length) / expectedSize;
          double elapsedSeconds =
              DateTime.now().difference(startTime).inMilliseconds / 1000;
          double speed =
              elapsedSeconds > 0
                  ? ((allData.length - 5 - fileName.length) / (1024 * 1024)) /
                      elapsedSeconds
                  : 0;
          _transferManager.updateReceiveProgress(
            progress.clamp(0.0, 1.0),
            speed,
          );
        }
      }

      if (allData.isNotEmpty && headerParsed) {
        List<int> fileData = allData.sublist(5 + fileName.length);
        await _saveFile(fileName, fileData);
        _transferManager.completeReceiving();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("File '$fileName' received successfully!")),
          );
        }
      }
    } catch (e) {
      // Handle silently
    } finally {
      socket.close();
    }
  }

  Future<void> _saveFile(String fileName, List<int> bytes) async {
    try {
      String extension = fileName.split('.').last.toLowerCase();
      Directory dir =
          ['jpg', 'jpeg', 'png', 'gif'].contains(extension)
              ? Directory('/storage/emulated/0/DCIM/LocalShare')
              : Directory('/storage/emulated/0/LocalShare');

      await dir.create(recursive: true);
      await File('${dir.path}/$fileName').writeAsBytes(bytes);
    } catch (e) {
      // Handle silently
    }
  }

  @override
  void dispose() {
    _server?.close();
    _deviceDiscovery.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF2C1D4D),
      appBar: AppBar(
        // backgroundColor: const Color(0xFF2C1D4D),
        title: const Text("LocalShare"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/protection.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            Text(
              deviceName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                // color: Colors.white,
              ),
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
                ),
                child: QrImageView(
                  data: qrData!,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Scan this QR code to send files",
                // style: TextStyle(color: Colors.white),
              ),
            ],
            const SizedBox(height: 30),
            // Transfer progress
            ListenableBuilder(
              listenable: _transferManager,
              builder: (context, child) {
                if (!_transferManager.isReceiving &&
                    _transferManager.receivedFilesCount == 0) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.download, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            _transferManager.isReceiving
                                ? "Receiving File"
                                : "Files Received",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_transferManager.receivedFilesCount > 0)
                            Text(
                              "${_transferManager.receivedFilesCount} files",
                            ),
                        ],
                      ),
                      if (_transferManager.isReceiving) ...[
                        const SizedBox(height: 8),
                        Text(
                          _transferManager.receivingFileName,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _transferManager.receiveProgress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${(_transferManager.receiveProgress * 100).toStringAsFixed(1)}%",
                            ),
                            Text(
                              "${_transferManager.receiveSpeed.toStringAsFixed(1)} MB/s",
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
