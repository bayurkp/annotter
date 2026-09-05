import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'models.dart';

/// Lightweight HTTP sync client for Annotter MCP server.
/// Uses 100% native dart:io / browser fetch (zero external dependencies).
class AnnotterSyncClient {
  final String serverUrl;
  final HttpClient _httpClient = HttpClient();
  bool _isConnected = false;

  /// Returns true if the MCP server was verified reachable on the last check
  bool get isConnected => _isConnected;

  AnnotterSyncClient({required this.serverUrl}) {
    // 1-second fast timeout: never block event loop or UI thread if server is down
    _httpClient.connectionTimeout = const Duration(seconds: 1);
  }

  Uri _uri(String path) {
    final cleanBase = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  /// Pings the MCP server with a fast timeout (default 1s).
  /// Updates [isConnected] circuit-breaker flag.
  Future<bool> ping({Duration timeout = const Duration(seconds: 1)}) async {
    if (kIsWeb) {
      _isConnected = false;
      return false;
    }
    try {
      final uri = _uri('/api/ping');
      final request = await _httpClient.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        _isConnected = body.contains('"status":"ok"') || body.contains('"pong":true');
        return _isConnected;
      }
    } catch (_) {
      _isConnected = false;
    }
    _isConnected = false;
    return false;
  }

  /// Serializes an AnnotterItem into JSON map for MCP server
  Map<String, dynamic> _itemToJson(AnnotterItem item,
      {String? route, String? screenshotPath}) {
    return {
      'id': 'ann_${item.id}',
      'number': item.number,
      'widgetName': item.widgetName,
      'selectedText': item.selectedText,
      'hierarchy': item.hierarchy,
      'note': item.note,
      'intent': item.intent ?? 'fix',
      'severity': item.severity ?? 'important',
      'status': 'pending',
      'mode': item.mode.name,
      'route': route ?? item.screenName,
      'screenshotPath': screenshotPath,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'rect': {
        'x': item.rect.left,
        'y': item.rect.top,
        'width': item.rect.width,
        'height': item.rect.height,
      },
    };
  }

  /// Sends a newly created or updated annotation to the MCP server
  Future<bool> syncAnnotation(AnnotterItem item,
      {String? route, String? screenshotPath}) async {
    if (kIsWeb || !_isConnected) return false; // Circuit breaker: skip network if disconnected
    try {
      final uri = _uri('/api/annotations');
      final request = await _httpClient.postUrl(uri).timeout(const Duration(seconds: 1));
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode(
          _itemToJson(item, route: route, screenshotPath: screenshotPath));

      request.write(payload);
      final response = await request.close().timeout(const Duration(seconds: 1));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  /// Syncs multiple annotations in bulk to the MCP server (e.g. on Copy/Export)
  /// If [replace] is true, replaces all existing annotations on server with these.
  Future<bool> syncAllAnnotations(List<AnnotterItem> items,
      {String? route, String? screenshotPath, bool replace = false}) async {
    if (kIsWeb || !_isConnected || items.isEmpty) return false;
    try {
      final path =
          replace ? '/api/annotations?replace=true' : '/api/annotations';
      final uri = _uri(path);
      final request = await _httpClient.postUrl(uri).timeout(const Duration(seconds: 1));
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode(items
          .map((item) =>
              _itemToJson(item, route: route, screenshotPath: screenshotPath))
          .toList());

      request.write(payload);
      final response = await request.close().timeout(const Duration(seconds: 1));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  /// Uploads screenshot image bytes directly to MCP server host
  /// Returns the host's saved local absolute file path, or null if upload failed.
  Future<String?> uploadScreenshot(List<int> bytes, String filename) async {
    if (kIsWeb || !_isConnected || bytes.isEmpty) return null;
    try {
      final uri = _uri('/api/upload-screenshot?filename=${Uri.encodeComponent(filename)}');
      final request = await _httpClient.postUrl(uri).timeout(const Duration(seconds: 1));
      request.headers.contentType = ContentType.binary;
      request.headers.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(const Duration(seconds: 1));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        if (json is Map && json['localPath'] != null) {
          return json['localPath'] as String;
        }
      }
    } catch (_) {
      _isConnected = false;
    }
    return null;
  }

  /// Deletes an annotation from the MCP server
  Future<bool> deleteAnnotation(int itemId) async {
    if (kIsWeb || !_isConnected) return false;
    try {
      final uri = _uri('/api/annotations/ann_$itemId');
      final request = await _httpClient.deleteUrl(uri).timeout(const Duration(seconds: 1));
      final response = await request.close().timeout(const Duration(seconds: 1));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  /// Clears all annotations on the MCP server
  Future<bool> clearAll() async {
    if (kIsWeb || !_isConnected) return false;
    try {
      final uri = _uri('/api/annotations');
      final request = await _httpClient.deleteUrl(uri).timeout(const Duration(seconds: 1));
      final response = await request.close().timeout(const Duration(seconds: 1));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  /// Polls server for resolved status updates from AI agent
  Future<Map<String, String>> fetchStatuses() async {
    if (kIsWeb || !_isConnected) return {};
    try {
      final uri = _uri('/api/annotations');
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 1));
      final response = await request.close().timeout(const Duration(seconds: 1));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List list = jsonDecode(body) as List;
        final Map<String, String> statuses = {};
        for (final entry in list) {
          if (entry is Map && entry['id'] != null && entry['status'] != null) {
            statuses[entry['id'].toString()] = entry['status'].toString();
          }
        }
        return statuses;
      }
    } catch (_) {
      _isConnected = false;
    }
    return {};
  }

  void dispose() {
    _httpClient.close();
  }
}
