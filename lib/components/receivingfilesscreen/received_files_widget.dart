// import 'package:flutter/material.dart';
// import 'package:localshare/utils/transfer_manager.dart';

// class ReceivedFilesWidget extends StatelessWidget {
//   const ReceivedFilesWidget({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ListenableBuilder(
//       listenable: TransferManager(),
//       builder: (context, child) {
//         final transferManager = TransferManager();

//         if (transferManager.receivedFilesCount == 0) {
//           return const SizedBox.shrink();
//         }

//         return Container(
//           margin: const EdgeInsets.all(16),
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.green.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.green.withOpacity(0.3)),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   const Icon(Icons.check_circle, color: Colors.green),
//                   const SizedBox(width: 8),
//                   const Text(
//                     "Received Files",
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.green,
//                     ),
//                   ),
//                   const Spacer(),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.green.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       "${transferManager.receivedFilesCount}",
//                       style: const TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.green,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),

//               Text(
//                 "Files have been successfully received and saved to your device.",
//                 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//               ),
//               const SizedBox(height: 12),

//               Row(
//                 children: [
//                   Expanded(
//                     child: OutlinedButton.icon(
//                       onPressed: () => _showReceivedFilesInfo(context),
//                       icon: const Icon(Icons.folder_open, size: 16),
//                       label: const Text("View Files"),
//                       style: OutlinedButton.styleFrom(
//                         foregroundColor: Colors.green,
//                         side: const BorderSide(color: Colors.green),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   OutlinedButton.icon(
//                     onPressed: () => _clearReceivedCount(context),
//                     icon: const Icon(Icons.clear, size: 16),
//                     label: const Text("Clear"),
//                     style: OutlinedButton.styleFrom(
//                       foregroundColor: Colors.grey,
//                       side: const BorderSide(color: Colors.grey),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _showReceivedFilesInfo(BuildContext context) {
//     final transferManager = TransferManager();
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text("Received Files"),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "Total files received: ${transferManager.receivedFilesCount}",
//                   style: const TextStyle(fontSize: 16),
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   "Files are automatically saved to your configured save location. You can find them in your device's file manager.",
//                   style: TextStyle(fontSize: 14),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text("OK"),
//               ),
//             ],
//           ),
//     );
//   }

//   void _clearReceivedCount(BuildContext context) {
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text("Clear Received Count"),
//             content: const Text(
//               "Are you sure you want to clear the received files count? This will reset the counter to zero.",
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text("Cancel"),
//               ),
//               TextButton(
//                 onPressed: () {
//                   TransferManager().resetReceiveCount();
//                   Navigator.pop(context);
//                 },
//                 style: TextButton.styleFrom(foregroundColor: Colors.red),
//                 child: const Text("Clear"),
//               ),
//             ],
//           ),
//     );
//   }
// }
