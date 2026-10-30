import 'dart:io';
class LocalManifestServer {
  LocalManifestServer._internal();
  static final LocalManifestServer instance = LocalManifestServer._internal();
  HttpServer? _server;
  final Map<String, String> _manifests = {};
  Future<int> _ensureServer() async {
    final existing = _server;
    if (existing != null) return existing.port;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      final path = request.uri.path;
      final content = _manifests[path];
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      if (content == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType =
            ContentType('application', 'dash+xml', charset: 'utf-8')
        ..headers.set('Cache-Control', 'no-store')
        ..write(content);
      await request.response.close();
    }, onError: (_) {});
    return server.port;
  }
  Future<String> publish(String xmlContent) async {
    final port = await _ensureServer();
    final name = 'manifest_${DateTime.now().microsecondsSinceEpoch}.mpd';
    _manifests['/$name'] = xmlContent;
    return 'http://127.0.0.1:$port/$name';
  }
  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _manifests.clear();
  }
}
