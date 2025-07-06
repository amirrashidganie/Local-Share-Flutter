// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:localshare/pages/main_navigation.dart';

// class PermissionScreen extends StatefulWidget {
//   const PermissionScreen({super.key});

//   @override
//   State<PermissionScreen> createState() => _PermissionScreenState();
// }

// class _PermissionScreenState extends State<PermissionScreen> {
//   Map<Permission, PermissionStatus> _permissionStatuses = {};
//   bool _isLoading = false;

//   final List<PermissionInfo> _requiredPermissions = [
//     PermissionInfo(
//       permission: Permission.storage,
//       title: "Storage Access",
//       description: "Required to save and access files",
//       icon: Icons.folder,
//     ),
//     PermissionInfo(
//       permission: Permission.photos,
//       title: "Photos Access",
//       description: "Required to access and share photos",
//       icon: Icons.photo,
//     ),
//     PermissionInfo(
//       permission: Permission.camera,
//       title: "Camera Access",
//       description: "Required for QR code scanning",
//       icon: Icons.camera_alt,
//     ),
//     //location
//     PermissionInfo(
//       permission: Permission.location,
//       title: "Location Access",
//       description: "Required for QR code scanning",
//       icon: Icons.location_on,
//     ),
//     //audio
//     PermissionInfo(
//       permission: Permission.audio,
//       title: "Audio Access",
//       description: "Required for audio sharing",
//       icon: Icons.music_note,
//     ),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _checkPermissions();
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // Check if permissions have been granted and we can proceed
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkIfCanProceed();
//     });
//   }

//   Future<void> _checkPermissions() async {
//     setState(() => _isLoading = true);

//     Map<Permission, PermissionStatus> statuses = {};
//     for (var permInfo in _requiredPermissions) {
//       try {
//         statuses[permInfo.permission] = await permInfo.permission.status;
//       } catch (e) {
//         statuses[permInfo.permission] = PermissionStatus.denied;
//       }
//     }

//     setState(() {
//       _permissionStatuses = statuses;
//       _isLoading = false;
//     });
//   }

//   Future<void> _requestPermission(Permission permission) async {
//     try {
//       final status = await permission.request();
//       setState(() {
//         _permissionStatuses[permission] = status;
//       });
//       // Check if we can proceed after each permission request
//       _checkIfCanProceed();
//     } catch (e) {
//       // Handle error
//     }
//   }

//   Future<void> _requestAllPermissions() async {
//     setState(() => _isLoading = true);

//     for (var permInfo in _requiredPermissions) {
//       if (_permissionStatuses[permInfo.permission] !=
//           PermissionStatus.granted) {
//         await _requestPermission(permInfo.permission);
//       }
//     }

//     setState(() => _isLoading = false);
//     // Final check after all permissions are requested
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkIfCanProceed();
//     });
//   }

//   void _checkIfCanProceed() {
//     bool hasEssentialPermissions =
//         _permissionStatuses[Permission.storage] == PermissionStatus.granted;

//     if (hasEssentialPermissions) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const MainNavigation()),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Permissions Required"),
//         automaticallyImplyLeading: false,
//       ),
//       body:
//           _isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     const Icon(Icons.security, size: 80, color: Colors.blue),
//                     const SizedBox(height: 20),
//                     const Text(
//                       "LocalShare needs these permissions to work properly:",
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 30),

//                     Expanded(
//                       child: ListView.builder(
//                         itemCount: _requiredPermissions.length,
//                         itemBuilder: (context, index) {
//                           final permInfo = _requiredPermissions[index];
//                           final status =
//                               _permissionStatuses[permInfo.permission];

//                           return Card(
//                             margin: const EdgeInsets.only(bottom: 12),
//                             child: ListTile(
//                               leading: Icon(permInfo.icon, color: Colors.blue),
//                               title: Text(permInfo.title),
//                               subtitle: Text(permInfo.description),
//                               trailing: _buildPermissionStatus(
//                                 status,
//                                 permInfo.permission,
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),

//                     const SizedBox(height: 20),

//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _requestAllPermissions,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.blue,
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                         ),
//                         child: const Text(
//                           "Grant Permissions",
//                           style: TextStyle(fontSize: 16, color: Colors.white),
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 12),

//                     TextButton(
//                       onPressed: () {
//                         bool hasStorage =
//                             _permissionStatuses[Permission.storage] ==
//                             PermissionStatus.granted;
//                         if (hasStorage) {
//                           _checkIfCanProceed();
//                         } else {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(
//                               content: Text(
//                                 "Storage permission is required to continue",
//                               ),
//                               backgroundColor: Colors.red,
//                             ),
//                           );
//                         }
//                       },
//                       child: const Text("Continue with granted permissions"),
//                     ),
//                   ],
//                 ),
//               ),
//     );
//   }

//   Widget _buildPermissionStatus(
//     PermissionStatus? status,
//     Permission permission,
//   ) {
//     switch (status) {
//       case PermissionStatus.granted:
//         return const Icon(Icons.check_circle, color: Colors.green);
//       case PermissionStatus.denied:
//         return IconButton(
//           icon: const Icon(Icons.refresh, color: Colors.orange),
//           onPressed: () => _requestPermission(permission),
//         );
//       case PermissionStatus.permanentlyDenied:
//         return IconButton(
//           icon: const Icon(Icons.settings, color: Colors.red),
//           onPressed: () => openAppSettings(),
//         );
//       default:
//         return const Icon(Icons.help_outline, color: Colors.grey);
//     }
//   }
// }

// class PermissionInfo {
//   final Permission permission;
//   final String title;
//   final String description;
//   final IconData icon;

//   PermissionInfo({
//     required this.permission,
//     required this.title,
//     required this.description,
//     required this.icon,
//   });
// }
