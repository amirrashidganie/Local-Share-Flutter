import 'dart:io';

class FileUtils {
  static String formatFileSize(int sizeInBytes) {
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = 0;
    double size = sizeInBytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(2)} ${suffixes[i]}";
  }

  static String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  static bool isImageFile(String extension) {
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(extension);
  }

  static bool isVideoFile(String extension) {
    return ['mp4', 'mkv', 'avi', 'mov'].contains(extension);
  }

  static bool isAudioFile(String extension) {
    return ['mp3', 'wav', 'aac', 'flac'].contains(extension);
  }

  static bool isDocumentFile(String extension) {
    return ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx'].contains(extension);
  }

  static Directory getStorageDirectory(String fileName) {
    String extension = getFileExtension(fileName);
    
    if (isImageFile(extension) || isVideoFile(extension)) {
      return Directory('/storage/emulated/0/DCIM/LocalShare');
    } else {
      return Directory('/storage/emulated/0/LocalShare');
    }
  }
}