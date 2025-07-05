import 'package:flutter/material.dart';
import 'package:localshare/utils/transfer_manager.dart';
import 'package:localshare/utils/file_utils.dart';
import 'package:localshare/utils/settings_manager.dart';

class ReceivingFilesScreen extends StatefulWidget {
  const ReceivingFilesScreen({super.key});

  @override
  State<ReceivingFilesScreen> createState() => _ReceivingFilesScreenState();
}

class _ReceivingFilesScreenState extends State<ReceivingFilesScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Start pulse animation
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TransferManager(),
      builder: (context, child) {
        final transferManager = TransferManager();

        if (!transferManager.isReceiving) {
          return const SizedBox.shrink();
        }

        return _buildReceivingScreen(transferManager);
      },
    );
  }

  Widget _buildReceivingScreen(TransferManager transferManager) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // File icon and animation
                      _buildFileIcon(transferManager),

                      const SizedBox(height: 30),

                      // File information
                      _buildFileInfo(transferManager),

                      const SizedBox(height: 30),

                      // Progress section
                      _buildProgressSection(transferManager),

                      const SizedBox(height: 30),

                      // Save location info
                      _buildSaveLocationInfo(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showCancelDialog(),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const Expanded(
            child: Text(
              "Receiving Files",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildFileIcon(TransferManager transferManager) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _getFileTypeColor(
                transferManager.receivingFileName,
              ).withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getFileTypeColor(
                    transferManager.receivingFileName,
                  ).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _getFileTypeIcon(transferManager.receivingFileName),
              size: 60,
              color: _getFileTypeColor(transferManager.receivingFileName),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileInfo(TransferManager transferManager) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // File name
          Text(
            transferManager.receivingFileName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // File type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getFileTypeColor(
                transferManager.receivingFileName,
              ).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getFileTypeName(transferManager.receivingFileName),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getFileTypeColor(transferManager.receivingFileName),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(TransferManager transferManager) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Container(
                    height: 12,
                    width:
                        MediaQuery.of(context).size.width *
                        0.7 *
                        transferManager.receiveProgress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Progress",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    "${(transferManager.receiveProgress * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Speed",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    "${transferManager.receiveSpeed.toStringAsFixed(1)} MB/s",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // File size info (if available)
          if (transferManager.receiveProgress > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "File transfer in progress...",
                      style: const TextStyle(fontSize: 14, color: Colors.blue),
                    ),
                  ),
                ],
              ),
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
          const Icon(Icons.folder, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Saving to:",
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

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Cancel Receiving"),
            content: const Text(
              "Are you sure you want to cancel the file transfer? This may interrupt the current file being received.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Continue Receiving"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Close the receiving screen
                  TransferManager().resetReceivingState();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Cancel"),
              ),
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
        return 'LocalShare folder';
    }
  }

  IconData _getFileTypeIcon(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return Icons.image;
    } else if (['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv'].contains(extension)) {
      return Icons.video_file;
    } else if (['mp3', 'wav', 'aac', 'flac', 'ogg'].contains(extension)) {
      return Icons.audio_file;
    } else if (['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(extension)) {
      return Icons.description;
    } else if (['xls', 'xlsx', 'csv'].contains(extension)) {
      return Icons.table_chart;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return Icons.slideshow;
    } else if (extension == 'apk') {
      return Icons.android;
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(extension)) {
      return Icons.archive;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return Colors.green;
    } else if (['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv'].contains(extension)) {
      return Colors.red;
    } else if (['mp3', 'wav', 'aac', 'flac', 'ogg'].contains(extension)) {
      return Colors.orange;
    } else if (['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(extension)) {
      return Colors.blue;
    } else if (['xls', 'xlsx', 'csv'].contains(extension)) {
      return Colors.green;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return Colors.orange;
    } else if (extension == 'apk') {
      return Colors.purple;
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(extension)) {
      return Colors.grey;
    } else {
      return Colors.blue;
    }
  }

  String _getFileTypeName(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return 'Image';
    } else if (['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv'].contains(extension)) {
      return 'Video';
    } else if (['mp3', 'wav', 'aac', 'flac', 'ogg'].contains(extension)) {
      return 'Audio';
    } else if (['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(extension)) {
      return 'Document';
    } else if (['xls', 'xlsx', 'csv'].contains(extension)) {
      return 'Spreadsheet';
    } else if (['ppt', 'pptx'].contains(extension)) {
      return 'Presentation';
    } else if (extension == 'apk') {
      return 'Android App';
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(extension)) {
      return 'Archive';
    } else {
      return 'File';
    }
  }
}
