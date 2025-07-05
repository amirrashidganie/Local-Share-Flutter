// import 'dart:io';
// import 'package:flutter/material.dart';
// // import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:network_info_plus/network_info_plus.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:localshare/utils/file_utils.dart';
// import 'package:localshare/utils/transfer_manager.dart';

// class SendConnectionScreen extends StatefulWidget {
//   final List<File> selectedFiles;

//   const SendConnectionScreen({super.key, required this.selectedFiles});

//   @override
//   State<SendConnectionScreen> createState() => _SendConnectionScreenState();
// }

// class _SendConnectionScreenState extends State<SendConnectionScreen> {
//   bool _showQrScanner = false;
//   bool _isSending = false;
//   double _sendProgress = 0.0;
//   String _currentSSID = "";
//   String _currentIP = "";
//   List<String> _availableDevices = [];
//   bool _isScanning = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeAndScan();
//   }

//   Future<void> _initializeAndScan() async {
//     await _getNetworkInfo();
//     _startAutoScan();
//   }

//   Future<void> _getNetworkInfo() async {
//     try {
//       final info = NetworkInfo();
//       _currentSSID = await info.getWifiName() ?? "Unknown";
//       _currentIP = await info.getWifiIP() ?? "";
//     } catch (e) {
//       // Handle silently
//     }
//   }

//   void _startAutoScan() {
//     if (_currentIP.isNotEmpty) {
//       _scanNetworkForReceivers();
//       // Auto-scan every 5 seconds
//       Future.delayed(const Duration(seconds: 5), () {
//         if (mounted && !_isSending) {
//           _startAutoScan();
//         }
//       });
//     }
//   }

//   Future<void> _manualScan() async {
//     if (_currentIP.isNotEmpty) {
//       await _scanNetworkForReceivers();
//     }
//   }

//   Future<void> _scanNetworkForReceivers() async {
//     setState(() {
//       _availableDevices.clear();
//       _isScanning = true;
//     });

//     String subnet = _currentIP.substring(0, _currentIP.lastIndexOf('.'));

//     List<Future> scanTasks = [];
//     for (int i = 1; i <= 254; i++) {
//       String targetIP = '$subnet.$i';
//       if (targetIP != _currentIP) {
//         scanTasks.add(_checkForReceiver(targetIP));
//       }
//     }

//     await Future.wait(scanTasks);
//     setState(() => _isScanning = false);
//   }

//   Future<void> _checkForReceiver(String ip) async {
//     try {
//       Socket socket = await Socket.connect(
//         ip,
//         5000,
//         timeout: const Duration(milliseconds: 500),
//       );
//       await socket.close();

//       if (mounted) {
//         setState(() {
//           _availableDevices.add(ip);
//         });
//       }
//     } catch (e) {
//       // Device not available
//     }
//   }

//   void _handleQrScanned(BarcodeCapture capture) {
//     final barcode = capture.barcodes.first;
//     if (barcode.rawValue != null) {
//       List<String> data = barcode.rawValue!.split("|");
//       if (data.length == 2) {
//         _sendToDevice(data[1]);
//         setState(() => _showQrScanner = false);
//       }
//     }
//   }

//   Future<void> _sendToDevice(String receiverIP) async {
//     TransferManager transferManager = TransferManager();
//     transferManager.startSending(widget.selectedFiles);

//     setState(() => _isSending = true);

//     try {
//       for (int i = 0; i < widget.selectedFiles.length; i++) {
//         File file = widget.selectedFiles[i];
//         await _sendSingleFile(file, receiverIP, transferManager);
//         if (i < widget.selectedFiles.length - 1) {
//           transferManager.nextSendingFile();
//         }
//       }

//       transferManager.stopSending();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("All files sent successfully!")),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       transferManager.stopSending();
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("Failed to send files: $e")));
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isSending = false;
//           _sendProgress = 0.0;
//         });
//       }
//     }
//   }

//   Future<void> _sendSingleFile(
//     File file,
//     String receiverIP,
//     TransferManager transferManager,
//   ) async {
//     Socket socket = await Socket.connect(
//       receiverIP,
//       5000,
//       timeout: const Duration(seconds: 10),
//     );
//     socket.setOption(SocketOption.tcpNoDelay, true);

//     String fileName = file.path.split('/').last;
//     List<int> fileNameBytes = fileName.codeUnits;
//     socket.add([fileNameBytes.length]);
//     socket.add(fileNameBytes);

//     int totalSize = await file.length();
//     socket.add([
//       (totalSize >> 24) & 0xFF,
//       (totalSize >> 16) & 0xFF,
//       (totalSize >> 8) & 0xFF,
//       totalSize & 0xFF,
//     ]);

//     await socket.flush();

//     int sentBytes = 0;
//     DateTime startTime = DateTime.now();

//     await for (List<int> chunk in file.openRead()) {
//       socket.add(chunk);
//       sentBytes += chunk.length;

//       double progress = sentBytes / totalSize;
//       double elapsedSeconds =
//           DateTime.now().difference(startTime).inMilliseconds / 1000;
//       double speed =
//           elapsedSeconds > 0 ? (sentBytes / (1024 * 1024)) / elapsedSeconds : 0;

//       transferManager.updateSendProgress(progress, fileName, speed);

//       if (mounted) {
//         setState(() => _sendProgress = progress);
//       }
//     }

//     await socket.flush();
//     await socket.close();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Send Files"),
//         backgroundColor: Colors.blue,
//       ),
//       body: _showQrScanner ? _buildQrScanner() : _buildMainContent(),
//     );
//   }

//   Widget _buildQrScanner() {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(16),
//           color: Colors.blue[50],
//           child: Row(
//             children: [
//               IconButton(
//                 onPressed: () => setState(() => _showQrScanner = false),
//                 icon: const Icon(Icons.arrow_back),
//               ),
//               const Text(
//                 "Scan QR Code",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         ),
//         Expanded(child: MobileScanner(onDetect: _handleQrScanned)),
//         Container(
//           padding: const EdgeInsets.all(16),
//           child: const Text(
//             "Point camera at receiver's QR code",
//             style: TextStyle(fontSize: 16),
//             textAlign: TextAlign.center,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildMainContent() {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(16),
//           color: Colors.grey[100],
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   const Icon(Icons.folder, color: Colors.blue),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           "${widget.selectedFiles.length} files selected",
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         Text(
//                           FileUtils.formatFileSize(
//                             widget.selectedFiles.fold(
//                               0,
//                               (sum, file) => sum + file.lengthSync(),
//                             ),
//                           ),
//                           style: const TextStyle(color: Colors.grey),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 "Files to send:",
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               SizedBox(
//                 height: 100,
//                 child: ListView.builder(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: widget.selectedFiles.length,
//                   itemBuilder: (context, index) {
//                     File file = widget.selectedFiles[index];
//                     String fileName = file.path.split('/').last;
//                     return Container(
//                       width: 80,
//                       margin: const EdgeInsets.only(right: 8),
//                       child: Card(
//                         child: Padding(
//                           padding: const EdgeInsets.all(8),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(
//                                 _getFileIcon(fileName),
//                                 size: 24,
//                                 color: Colors.blue,
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 fileName.length > 10
//                                     ? '${fileName.substring(0, 10)}...'
//                                     : fileName,
//                                 style: const TextStyle(fontSize: 10),
//                                 textAlign: TextAlign.center,
//                                 maxLines: 2,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                               Text(
//                                 FileUtils.formatFileSize(file.lengthSync()),
//                                 style: const TextStyle(
//                                   fontSize: 8,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),

//         if (_isSending) ...[
//           Container(
//             margin: const EdgeInsets.all(16),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.blue[50],
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.blue[200]!),
//             ),
//             child: Column(
//               children: [
//                 const Text(
//                   "Sending Files...",
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 LinearProgressIndicator(value: _sendProgress),
//                 const SizedBox(height: 4),
//                 Text("${(_sendProgress * 100).toStringAsFixed(1)}% completed"),
//               ],
//             ),
//           ),
//         ] else ...[
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Connection method icons
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _buildConnectionButton(
//                         Icons.qr_code_scanner,
//                         "QR Scan",
//                         Colors.blue,
//                         () => setState(() => _showQrScanner = true),
//                       ),
//                       _buildConnectionButton(
//                         _isScanning ? Icons.wifi_find : Icons.refresh,
//                         "Scan",
//                         Colors.green,
//                         _manualScan,
//                       ),
//                       _buildConnectionButton(
//                         Icons.devices,
//                         "Nearby",
//                         Colors.orange,
//                         () {}, // Just for display
//                       ),
//                       _buildConnectionButton(
//                         Icons.edit,
//                         "Manual IP",
//                         Colors.red,
//                         _showManualIPDialog,
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     "Found Devices (${_availableDevices.length})",
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),

//                   if (_availableDevices.isEmpty) ...[
//                     Card(
//                       child: Padding(
//                         padding: const EdgeInsets.all(16),
//                         child: Column(
//                           children: [
//                             Icon(
//                               _isScanning ? Icons.wifi_find : Icons.wifi_off,
//                               size: 48,
//                               color: Colors.grey,
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               _isScanning ? "Scanning..." : "No devices found",
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               "Make sure receiver is ready on $_currentSSID",
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               "Auto-scanning on $_currentSSID",
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ] else ...[
//                     ..._availableDevices.map(
//                       (ip) => Card(
//                         child: ListTile(
//                           leading: const Icon(
//                             Icons.download,
//                             color: Colors.green,
//                           ),
//                           title: Text("Device ($ip)"),
//                           subtitle: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text("IP: $ip"),
//                               const Text(
//                                 "Ready to receive",
//                                 style: TextStyle(
//                                   color: Colors.green,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           trailing: const Icon(Icons.send),
//                           onTap: () => _sendToDevice(ip),
//                         ),
//                       ),
//                     ),
//                   ],

//                   const Spacer(),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ],
//     );
//   }

//   void _showManualIPDialog() {
//     TextEditingController ipController = TextEditingController();
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text("Enter IP Address"),
//             content: TextField(
//               controller: ipController,
//               decoration: const InputDecoration(
//                 hintText: "192.168.1.100",
//                 labelText: "Receiver IP Address",
//               ),
//               keyboardType: const TextInputType.numberWithOptions(
//                 decimal: true,
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text("Cancel"),
//               ),
//               TextButton(
//                 onPressed: () {
//                   if (ipController.text.isNotEmpty) {
//                     Navigator.pop(context);
//                     _sendToDevice(ipController.text);
//                   }
//                 },
//                 child: const Text("Connect"),
//               ),
//             ],
//           ),
//     );
//   }

//   Widget _buildConnectionButton(
//     IconData icon,
//     String label,
//     Color color,
//     VoidCallback onTap,
//   ) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: color.withOpacity(0.3)),
//             ),
//             child: Icon(icon, color: color, size: 28),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 12,
//               color: color,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   IconData _getFileIcon(String fileName) {
//     String ext = fileName.split('.').last.toLowerCase();
//     if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return Icons.image;
//     if (['mp4', 'avi', 'mov'].contains(ext)) return Icons.video_file;
//     if (['mp3', 'wav', 'aac'].contains(ext)) return Icons.audio_file;
//     if (['pdf', 'doc', 'docx'].contains(ext)) return Icons.description;
//     return Icons.insert_drive_file;
//   }
// }
