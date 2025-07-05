// import 'package:localshare/components/mainscreen/button_widget.dart';
// import 'package:localshare/components/mainscreen/quick_access_widget.dart';
// import 'package:localshare/components/mainscreen/quick_tools_btn.dart';
// import 'package:localshare/components/mainscreen/recent_transfers_widget.dart';
// import 'package:localshare/components/mainscreen/storage_widget.dart';
// import 'package:localshare/components/receivescreen/receive_screen_widget.dart';
// import 'package:localshare/components/sendscreen/send_screen_widget.dart';
// import 'package:localshare/notifiers/dark_mode_notifier.dart';
// import 'package:localshare/pages/settings_widget.dart';
// import 'package:flutter/material.dart';

// class HomeWidget extends StatelessWidget {
//   const HomeWidget({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: Image.asset('assets/images/protection.png'),
//         leadingWidth: 40.0,
//         title: Text("LocalShare"),
//         actions: [
//           ValueListenableBuilder<bool>(
//             valueListenable: darkModeNotifier,
//             builder:
//                 (context, isDarkMode, child) => IconButton(
//                   onPressed: () {
//                     darkModeNotifier.value = !isDarkMode;
//                   },
//                   icon: Icon(Icons.dark_mode),
//                 ),
//           ),
//           IconButton(
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => SettingsWidget()),
//               );
//             },
//             icon: Icon(Icons.settings),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.only(left: 20.0, right: 20.0, bottom: 80.0),
//         child: Column(
//           spacing: 40,
//           mainAxisAlignment: MainAxisAlignment.start,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             SizedBox(),
//             //Send and Receive btns
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 //Send btn
//                 Expanded(
//                   child: ButtonWidget(
//                     btnName: 'Send',
//                     iconButton: Icon(
//                       Icons.cloud_upload_outlined,
//                       color: Colors.blue,
//                       size: 40,
//                     ),
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => SendScreenWidget(),
//                         ),
//                       );
//                     },
//                     color: Colors.blue,
//                   ),
//                 ),
//                 SizedBox(width: 10),
//                 // Spacer(),
//                 //Receive btn
//                 Expanded(
//                   child: ButtonWidget(
//                     btnName: 'Receive',
//                     iconButton: Icon(
//                       Icons.cloud_download_outlined,
//                       color: Colors.green,
//                       size: 40.0,
//                     ),
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => ReceiveScreenWidget(),
//                         ),
//                       );
//                     },
//                     color: Colors.green,
//                   ),
//                 ),
//               ],
//             ),

//             //Quick Access
//             QuickAccessWidget(),

//             //Storage
//             StorageWidget(),

//             //Recent transfers
//             RecentTransfersWidget(),

//             //Quick Tools
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 QuickToolsBtn(icon: Icons.delete, name: 'Cleaner'),
//                 QuickToolsBtn(icon: Icons.folder, name: 'Files'),
//                 QuickToolsBtn(icon: Icons.play_arrow, name: 'Player'),
//                 QuickToolsBtn(icon: Icons.download_sharp, name: 'History'),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
