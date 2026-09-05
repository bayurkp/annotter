import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'sync_client.dart';

/// Helper responsible for capturing high-resolution snapshots of the Flutter UI,
/// saving them to platform-appropriate download/storage folders,
/// or streaming them directly to the Annotter MCP host server.
class AnnotterSnapshotHelper {
  /// Resolves the effective snapshot directory on the current platform
  static Directory? resolveDirectory([String? snapshotDirectory]) {
    if (kIsWeb) return null;
    if (snapshotDirectory != null && snapshotDirectory.trim().isNotEmpty) {
      return Directory(snapshotDirectory.trim());
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final downloadDir = Directory('/sdcard/Download');
      if (downloadDir.existsSync()) return downloadDir;
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final winDownloads = Directory('$userProfile\\Downloads');
        if (winDownloads.existsSync()) return winDownloads;
      }
    } else if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final unixDownloads = Directory('$home/Downloads');
        if (unixDownloads.existsSync()) return unixDownloads;
      }
    }
    return Directory.systemTemp;
  }

  /// Captures a snapshot from the provided [RepaintBoundary] render object.
  /// If [syncClient] is connected, directly uploads to host and returns local host path.
  /// Otherwise, saves locally to [snapshotDirectory] or platform default Downloads folder.
  static Future<String?> capture({
    required RenderRepaintBoundary? boundary,
    required String filename,
    String? snapshotDirectory,
    AnnotterSyncClient? syncClient,
    double pixelRatio = 2.0,
  }) async {
    try {
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        return 'web_$filename';
      }

      File? file;

      // 1. User custom directory
      if (snapshotDirectory != null && snapshotDirectory.trim().isNotEmpty) {
        try {
          final customDir = Directory(snapshotDirectory.trim());
          if (!await customDir.exists()) {
            await customDir.create(recursive: true);
          }
          file = File('${customDir.path}/$filename');
        } catch (_) {}
      }

      // 2. Platform default folders (Downloads folder preference)
      if (file == null) {
        final dir = resolveDirectory();
        if (dir != null && await dir.exists()) {
          file = File('${dir.path}/$filename');
        }
      }

      // 3. Fallback to system temp directory
      file ??= File('${Directory.systemTemp.path}/$filename');
      await file.writeAsBytes(pngBytes);

      // 4. Direct stream to MCP server host if connected
      if (syncClient != null && syncClient.isConnected) {
        try {
          final remotePath =
              await syncClient.uploadScreenshot(pngBytes, filename);
          if (remotePath != null && remotePath.isNotEmpty) {
            return remotePath;
          }
        } catch (_) {}
      }

      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Deletes all annotter snapshot PNG files locally and on MCP server.
  /// Returns the number of local files deleted.
  static Future<int> clearSnapshots({
    String? snapshotDirectory,
    AnnotterSyncClient? syncClient,
  }) async {
    int deletedCount = 0;
    if (!kIsWeb) {
      try {
        final targetDir = resolveDirectory(snapshotDirectory);
        if (targetDir != null && await targetDir.exists()) {
          final entities = targetDir.listSync();
          for (final entity in entities) {
            if (entity is File) {
              final name = entity.uri.pathSegments.last;
              if (name.startsWith('annotter_') && name.endsWith('.png')) {
                try {
                  await entity.delete();
                  deletedCount++;
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}
    }

    // Sync clear on MCP server if connected
    if (syncClient != null && syncClient.isConnected) {
      try {
        await syncClient.clearSnapshots();
      } catch (_) {}
    }

    return deletedCount;
  }
}
