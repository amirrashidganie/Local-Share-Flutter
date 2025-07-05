import 'package:flutter/material.dart';
import 'package:localshare/utils/transfer_manager.dart';

class CurrentReceivingFiles extends StatelessWidget {
  const CurrentReceivingFiles({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TransferManager(),
      builder: (context, child) {
        final transferManager = TransferManager();

        if (!transferManager.isReceiving) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.download, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    "Currently Receiving",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // File name
              Text(
                transferManager.receivingFileName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Progress bar
              LinearProgressIndicator(
                value: transferManager.receiveProgress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 6,
              ),
              const SizedBox(height: 8),

              // Progress details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${(transferManager.receiveProgress * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "${transferManager.receiveSpeed.toStringAsFixed(1)} MB/s",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
