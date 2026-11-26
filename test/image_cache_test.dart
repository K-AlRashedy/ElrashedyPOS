import 'dart:io';
import 'dart:typed_data';

import 'package:elrashedy_pos/core/image_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'fetches DB product image, persists to disk, and serves offline',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('pos_img_cache_');
      addTearDown(() => tempDir.delete(recursive: true));

      final sampleBytes = Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0x00,
        0x01,
        0x57,
        0x45,
        0x42,
        0x50,
      ]);
      var hits = 0;
      final onlineCache = ProductImageCache(
        directoryProvider: () async => tempDir,
        httpClient: MockClient((request) async {
          hits++;
          return http.Response.bytes(
            sampleBytes,
            200,
            headers: {'content-type': 'image/webp'},
          );
        }),
      );
      const url = 'https://app.herokuapp.com/factory/product/2/image/?v=1';
      final first = await onlineCache.getOrFetch(url);
      expect(first, sampleBytes);
      expect(hits, 1);
      onlineCache.dispose();

      // Simulate restart while offline: memory cache is empty and network fails.
      final offlineCache = ProductImageCache(
        directoryProvider: () async => tempDir,
        httpClient: MockClient((request) async {
          throw const SocketException('Offline');
        }),
      );
      final restored = await offlineCache.getOrFetch(url);
      expect(restored, sampleBytes);
      expect(offlineCache.cachedMemory(url), sampleBytes);
      offlineCache.dispose();
    },
  );

  test(
    'rejects non-image payloads, updates on new ?v=, and prunes stale files',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('pos_img_prune_');
      addTearDown(() => tempDir.delete(recursive: true));

      final v1Bytes = Uint8List.fromList([1, 2, 3, 4]);
      final v2Bytes = Uint8List.fromList([5, 6, 7, 8]);
      final cache = ProductImageCache(
        directoryProvider: () async => tempDir,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/product/3/')) {
            return http.Response(
              '<html>login</html>',
              200,
              headers: {'content-type': 'text/html'},
            );
          }
          if (request.url.queryParameters['v'] == '1') {
            return http.Response.bytes(
              v1Bytes,
              200,
              headers: {'content-type': 'image/webp'},
            );
          }
          if (request.url.queryParameters['v'] == '2') {
            return http.Response.bytes(
              v2Bytes,
              200,
              headers: {'content-type': 'image/webp'},
            );
          }
          return http.Response('not found', 404);
        }),
      );
      addTearDown(cache.dispose);

      const urlV1 = 'https://app.herokuapp.com/factory/product/2/image/?v=1';
      const urlV2 = 'https://app.herokuapp.com/factory/product/2/image/?v=2';
      const htmlUrl = 'https://app.herokuapp.com/factory/product/3/image/?v=1';

      expect(await cache.getOrFetch(htmlUrl), isNull);
      expect(await cache.getOrFetch(urlV1), v1Bytes);
      expect(await cache.getOrFetch(urlV2), v2Bytes);

      await cache.pruneUnused({urlV2});
      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
    },
  );
}
