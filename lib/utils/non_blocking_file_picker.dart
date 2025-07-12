// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:localshare/models/file_item.dart';

// class NonBlockingFilePicker {
//   static Future<List<FileItem>> pickFiles({
//     bool allowMultiple = true,
//     FileType type = FileType.any,
//     List<String>? allowedExtensions,
//     required Function(List<FileItem>) onFilesSelected,
//   }) async {
//     List<FileItem> fileItems = [];
    
//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         allowMultiple: allowMultiple,
//         type: type,
//         allowedExtensions: allowedExtensions,
//         withData: false,
//         withReadStream: true, // Use read stream for better performance
//       );
      
//       if (result != null && result.paths.isNotEmpty) {
//         // Create lightweight FileItems immediately
//         fileItems = result.paths
//             .where((path) => path != null)
//             .map((path) => FileItem.fromFile(File(path!)))
//             .toList();
        
//         // Notify caller immediately with file items
//         onFilesSelected(fileItems);
//       }
//     } catch (e) {
//       print('File picker error: $e');
//     }
    
//     return fileItems;
//   }
  
//   static Future<List<FileItem>> pickImages({
//     required Function(List<FileItem>) onImagesSelected,
//   }) async {
//     List<FileItem> fileItems = [];
    
//     try {
//       final ImagePicker picker = ImagePicker();
//       final List<XFile> images = await picker.pickMultipleMedia();
      
//       if (images.isNotEmpty) {
//         // Create lightweight FileItems immediately
//         fileItems = images
//             .map((image) => FileItem.fromFile(File(image.path)))
//             .toList();
        
//         // Notify caller immediately with file items
//         onImagesSelected(fileItems);
//       }
//     } catch (e) {
//       print('Image picker error: $e');
//     }
    
//     return fileItems;
//   }
  
//   static Future<List<FileItem>> pickVideos({
//     required Function(List<FileItem>) onVideosSelected,
//   }) async {
//     List<FileItem> fileItems = [];
    
//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.video,
//         allowMultiple: true,
//         withData: false,
//         withReadStream: true, // Use read stream for better performance
//       );
      
//       if (result != null && result.paths.isNotEmpty) {
//         // Create lightweight FileItems immediately
//         fileItems = result.paths
//             .where((path) => path != null)
//             .map((path) => FileItem.fromFile(File(path!)))
//             .toList();
        
//         // Notify caller immediately with file items
//         onVideosSelected(fileItems);
//       }
//     } catch (e) {
//       print('Video picker error: $e');
//     }
    
//     return fileItems;
//   }
  
//   static Future<List<FileItem>> pickAudio({
//     required Function(List<FileItem>) onAudioSelected,
//   }) async {
//     List<FileItem> fileItems = [];
    
//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.audio,
//         allowMultiple: true,
//         withData: false,
//         withReadStream: true, // Use read stream for better performance
//       );
      
//       if (result != null && result.paths.isNotEmpty) {
//         // Create lightweight FileItems immediately
//         fileItems = result.paths
//             .where((path) => path != null)
//             .map((path) => FileItem.fromFile(File(path!)))
//             .toList();
        
//         // Notify caller immediately with file items
//         onAudioSelected(fileItems);
//       }
//     } catch (e) {
//       print('Audio picker error: $e');
//     }
    
//     return fileItems;
//   }
// }