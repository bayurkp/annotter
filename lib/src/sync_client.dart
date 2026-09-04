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

  AnnotterSyncClient({required this.serverUrl}) {
    _httpClient.connectionTimeout = const Duration(seconds: 3);
  }

  Uri _uri(String path) {
    final cleanBase = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  /// Pings the MCP server to verify if it is reachable and running
  Future<bool> ping() async {
    if (kIsWeb) return false;
    try {
      final uri = _uri('/api/ping');
      final request = await _httpClient.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return body.contains('"status":"ok"') || body.contains('"pong":true');
      }
    } catch (_) {}
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
    if (kIsWeb) return false; // Native mobile & desktop sync first
    try {
      final uri = _uri('/api/annotations');
      final request = await _httpClient.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode(
          _itemToJson(item, route: route, screenshotPath: screenshotPath));

      request.write(payload);
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Syncs multiple annotations in bulk to the MCP server (e.g. on Copy/Export)
  /// If [replace] is true, replaces all existing annotations on server with these.
  Future<bool> syncAllAnnotations(List<AnnotterItem> items,
      {String? route, String? screenshotPath, bool replace = false}) async {
    if (kIsWeb || items.isEmpty) return false;
    try {
      final path =
          replace ? '/api/annotations?replace=true' : '/api/annotations';
      final uri = _uri(path);
      final request = await _httpClient.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode(items
          .map((item) =>
              _itemToJson(item, route: route, screenshotPath: screenshotPath))
          .toList());

      request.write(payload);
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Deletes an annotation from the MCP server
  Future<bool> deleteAnnotation(int itemId) async {
    if (kIsWeb) return false;
    try {
      final uri = _uri('/api/annotations/ann_$itemId');
      final request = await _httpClient.deleteUrl(uri);
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Clears all annotations on the MCP server
  Future<bool> clearAll() async {
    if (kIsWeb) return false;
    try {
      final uri = _uri('/api/annotations');
      final request = await _httpClient.deleteUrl(uri);
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Polls server for resolved status updates from AI agent
  Future<Map<String, String>> fetchStatuses() async {
    if (kIsWeb) return {};
    try {
      final uri = _uri('/api/annotations');
      final request = await _httpClient.getUrl(uri);
      final response = await request.close();
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
    } catch (_) {}
    return {};
  }

  void dispose() {
    _httpClient.close();
  }
}
