// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../domain/ports/site_icon_fetcher_port.dart';

/// Descarga el ícono directamente del sitio (ADR 0029), sin servicios de
/// terceros. Solo `https` (también en las redirecciones), con límites de
/// tiempo y tamaño, sin cookies, y reduciendo la imagen a 48 px para que la
/// bóveda no crezca.
class HttpSiteIconFetcher implements SiteIconFetcherPort {
  static const _pixels = 48;
  static const _maxHtmlBytes = 256 * 1024;
  static const _maxImageBytes = 300 * 1024;
  static const _timeout = Duration(seconds: 6);
  static const _maxRedirects = 3;

  final http.Client _client;

  /// Solo en [HttpSiteIconFetcher.duckDuckGo]: de dónde se pide.
  final Uri Function(String host)? _service;

  HttpSiteIconFetcher({http.Client? client})
    : _client = client ?? http.Client(),
      _service = null;

  /// Respaldo opcional (ADR 0030): le pide el ícono a DuckDuckGo, que
  /// recibe solo el dominio.
  HttpSiteIconFetcher.duckDuckGo({http.Client? client})
    : _client = client ?? http.Client(),
      _service = _duckDuckGoUrl;

  static Uri _duckDuckGoUrl(String host) =>
      Uri.https('icons.duckduckgo.com', '/ip3/$host.ico');

  @override
  Future<Uint8List?> fetchPng(String host) async {
    final service = _service;
    if (service != null) {
      final image = await _get(service(host), _maxImageBytes);
      return image == null ? null : _toPng(image.body);
    }
    final home = Uri.https(host, '/');
    final page = await _get(home, _maxHtmlBytes);
    final candidates = <Uri>[
      if (page != null)
        ...iconCandidates(page.url, String.fromCharCodes(page.body)),
      Uri.https(host, '/favicon.ico'),
    ];
    for (final url in candidates.toSet()) {
      final image = await _get(url, _maxImageBytes);
      if (image == null) continue;
      final png = await _toPng(image.body);
      if (png != null) return png;
    }
    return null;
  }

  /// GET que solo sigue redirecciones `https`. `null` si no hay respuesta
  /// usable; [SiteIconOfflineException] si no hubo conexión.
  Future<({Uri url, Uint8List body})?> _get(Uri url, int maxBytes) async {
    var current = url;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      if (current.scheme != 'https') return null;
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers['User-Agent'] = 'Mozilla/5.0 (compatible; Lockspire)'
        ..headers['Accept'] = 'text/html,image/*;q=0.9,*/*;q=0.5';
      final http.StreamedResponse response;
      try {
        response = await _client.send(request).timeout(_timeout);
      } on SocketException {
        throw const SiteIconOfflineException();
      } on TimeoutException {
        return null;
      } on HandshakeException {
        return null;
      } on http.ClientException {
        return null;
      } catch (_) {
        return null; // Cualquier otra falla: sin ícono, nunca un error.
      }
      if (response.isRedirect || (response.statusCode ~/ 100 == 3)) {
        final location = response.headers['location'];
        await response.stream.drain<void>();
        if (location == null) return null;
        current = current.resolve(location);
        continue;
      }
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      try {
        await for (final chunk in response.stream.timeout(_timeout)) {
          bytes.add(chunk);
          if (bytes.length > maxBytes) return null;
        }
      } on TimeoutException {
        return null;
      }
      return (url: current, body: bytes.toBytes());
    }
    return null;
  }

  static Future<Uint8List?> _toPng(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _pixels,
        targetHeight: _pixels,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null; // SVG u otro formato que no se puede decodificar.
    }
  }
}

final _linkTag = RegExp(r'<link\b[^>]*>', caseSensitive: false);
final _attr = RegExp(
  r'''([a-zA-Z-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
);

/// Íconos que declara la página, del mejor al peor: `apple-touch-icon`
/// (grande y cuadrado), luego `icon` por tamaño declarado. Solo `https` y
/// nunca SVG ni `data:`.
List<Uri> iconCandidates(Uri page, String html) {
  final found = <(int, Uri)>[];
  for (final tag in _linkTag.allMatches(html)) {
    final attrs = <String, String>{
      for (final a in _attr.allMatches(tag.group(0)!))
        a.group(1)!.toLowerCase(): a.group(2) ?? a.group(3) ?? a.group(4) ?? '',
    };
    final rel = (attrs['rel'] ?? '').toLowerCase();
    final href = attrs['href'] ?? '';
    if (!rel.contains('icon') || href.isEmpty) continue;
    if (href.startsWith('data:') || href.toLowerCase().contains('.svg')) {
      continue;
    }
    final url = page.resolve(href);
    if (url.scheme != 'https') continue;
    final size =
        int.tryParse(
          RegExp(r'(\d+)x\d+').firstMatch(attrs['sizes'] ?? '')?.group(1) ?? '',
        ) ??
        (rel.contains('apple-touch-icon') ? 180 : 16);
    final score = rel.contains('apple-touch-icon') ? 1000 + size : size;
    found.add((score, url));
  }
  found.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final (_, url) in found) url];
}
