import 'package:flutter/material.dart';
import 'package:localshare/utils/transfer_manager.dart';

class ReceivingProgress extends StatefulWidget {
  const ReceivingProgress({super.key});

  @override
  State<ReceivingProgress> createState() => _ReceivingProgressState();
}

class _ReceivingProgressState extends State<ReceivingProgress>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
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

        // Update progress animation
        _progressController.value = transferManager.receiveProgress;

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
              // Progress header
              Row(
                children: [
                  const Icon(Icons.download, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    "Transfer Progress",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${(transferManager.receiveProgress * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Animated progress bar
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Container(
                        height: 16,
                        width:
                            MediaQuery.of(context).size.width *
                            0.8 *
                            _progressAnimation.value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue, Colors.blue.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Progress details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildProgressDetail(
                    "Progress",
                    "${(transferManager.receiveProgress * 100).toStringAsFixed(1)}%",
                    Colors.blue,
                  ),
                  _buildProgressDetail(
                    "Speed",
                    "${transferManager.receiveSpeed.toStringAsFixed(1)} MB/s",
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    transferManager.receiveProgress,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(
                      transferManager.receiveProgress,
                    ).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(transferManager.receiveProgress),
                      color: _getStatusColor(transferManager.receiveProgress),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getStatusText(transferManager.receiveProgress),
                        style: TextStyle(
                          fontSize: 14,
                          color: _getStatusColor(
                            transferManager.receiveProgress,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressDetail(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(double progress) {
    if (progress == 0.0) {
      return Colors.grey;
    } else if (progress < 1.0) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  IconData _getStatusIcon(double progress) {
    if (progress == 0.0) {
      return Icons.hourglass_empty;
    } else if (progress < 1.0) {
      return Icons.download;
    } else {
      return Icons.check_circle;
    }
  }

  String _getStatusText(double progress) {
    if (progress == 0.0) {
      return "Waiting for file transfer to begin...";
    } else if (progress < 1.0) {
      return "File transfer in progress...";
    } else {
      return "File transfer completed successfully!";
    }
  }
}
