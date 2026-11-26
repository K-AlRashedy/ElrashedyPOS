import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persistent disk + memory cache for database-backed POS menu images.
///
/// Menu URLs include `?v=<image_version>` so updated product photos get a new
/// cache key automatically while cached bytes remain usable offline across app
/// restarts.
class ProductImageCache {
  ProductImageCache({
    Future<Directory> Function()? directoryProvider,
    http.Client? httpClient,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory,
       _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  static const Duration fetchTimeout = Duration(seconds: 12);

  final Future<Directory> Function() _directoryProvider;
  final http.Client _http;
  final bool _ownsClient;

  final Map<String, Uint8List> _memory = {};
  final Map<String, Future<Uint8List?>> _inFlight = {};
  Directory? _dir;

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'menu_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _ensureDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final dir = await _directoryProvider();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  static String cacheFileName(String url) {
    final bytes = utf8.encode(url);
    var hashA = 0x811c9dc5;
    var hashB = 0x9e3779b9;
    for (final byte in bytes) {
      hashA = ((hashA ^ byte) * 0x01000193) & 0xffffffff;
      hashB = ((hashB ^ (byte + 17)) * 0x85ebca6b) & 0xffffffff;
    }
    return 'img_${hashA.toRadixString(16).padLeft(8, '0')}'
        '${hashB.toRadixString(16).padLeft(8, '0')}.cache';
  }

  /// Synchronous RAM lookup so widget rebuilds don't flash a placeholder.
  Uint8List? cachedMemory(String url) => _memory[url];

  Future<Uint8List?> getOrFetch(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return Future.value(null);
    final mem = _memory[trimmed];
    if (mem != null) return Future.value(mem);
    return _inFlight.putIfAbsent(trimmed, () async {
      try {
        return await _loadOrFetch(trimmed);
      } finally {
        _inFlight.remove(trimmed);
      }
    });
  }

  Future<Uint8List?> _loadOrFetch(String url) async {
    final dir = await _ensureDir();
    final file = File(p.join(dir.path, cacheFileName(url)));
    try {
      if (await file.exists()) {
        final diskBytes = await file.readAsBytes();
        if (diskBytes.isNotEmpty) {
          _memory[url] = diskBytes;
          return diskBytes;
        }
      }
    } catch (_) {
      // Fall through to network fetch if the local file could not be read.
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    try {
      final response = await _http.get(uri).timeout(fetchTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final contentType = (response.headers['content-type'] ?? '')
          .toLowerCase();
      if (contentType.isNotEmpty && !contentType.startsWith('image/')) {
        return null;
      }
      final bytes = response.bodyBytes;
      _memory[url] = bytes;
      try {
        await file.writeAsBytes(bytes, flush: true);
      } catch (_) {
        // Disk write failure shouldn't stop in-memory rendering.
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> prefetchAll(
    Iterable<String> urls, {
    int concurrency = 4,
  }) async {
    final queue = urls.where((url) => url.trim().isNotEmpty).toSet().toList();
    if (queue.isEmpty) return;
    var cursor = 0;
    final workers = List.generate(
      concurrency < queue.length ? concurrency : queue.length,
      (_) async {
        while (cursor < queue.length) {
          final nextUrl = queue[cursor++];
          await getOrFetch(nextUrl);
        }
      },
    );
    await Future.wait(workers);
  }

  Future<void> pruneUnused(Set<String> activeUrls) async {
    final keepFiles = activeUrls
        .where((url) => url.trim().isNotEmpty)
        .map(cacheFileName)
        .toSet();
    _memory.removeWhere((url, _) => !activeUrls.contains(url));
    try {
      final dir = await _ensureDir();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('img_') &&
            name.endsWith('.cache') &&
            !keepFiles.contains(name)) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Cache cleanup is best-effort.
    }
  }

  void dispose() {
    if (_ownsClient) _http.close();
  }
}
