import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'sync_client.dart';

/// Helper responsible for capturing high-resolution snapshots of the Flutter UI,
/// saving them to platform-appropriate download/storage folders,
/// or streaming them directly to the Annotter MCP host server.
class AnnotterSnapshotHelper {
  /// Captures a snapshot from the provided [RepaintBoundary] render object.
  /// If [_syncClient] is connected, directly uploads to host and returns local host path.
  /// Otherwise, saves locally to [customSavePath] or platform default Downloads folder.
  static Future<String?> capture({
    required RenderRepaintBoundary? boundary,
    required String filename,
    String? customSavePath,
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
      if (customSavePath != null && customSavePath.trim().isNotEmpty) {
        try {
          final customDir = Directory(customSavePath.trim());
          if (!await customDir.exists()) {
            await customDir.create(recursive: true);
          }
          file = File('${customDir.path}/$filename');
        } catch (_) {}
      }

      // 2. Platform default folders (Downloads folder preference)
      if (file == null) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final downloadDir = Directory('/sdcard/Download');
          if (await downloadDir.exists()) {
            file = File('${downloadDir.path}/$filename');
          }
        } else if (defaultTargetPlatform == TargetPlatform.windows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null && userProfile.isNotEmpty) {
            final winDownloads = Directory('$userProfile\\Downloads');
            if (await winDownloads.exists()) {
              file = File('${winDownloads.path}\\$filename');
            }
          }
        } else if (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux) {
          final home = Platform.environment['HOME'];
          if (home != null && home.isNotEmpty) {
            final unixDownloads = Directory('$home/Downloads');
            if (await unixDownloads.exists()) {
              file = File('${unixDownloads.path}/$filename');
            }
          }
        }
      }

      // 3. Fallback to system temp directory
      file ??= File('${Directory.systemTemp.path}/$filename');
      await file.writeAsBytes(pngBytes);

      // 4. Direct stream to MCP server host if connected
      if (syncClient != null) {
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
}
