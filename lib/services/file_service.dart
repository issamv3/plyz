import 'package:http/http.dart' as http;
import 'dash_xml_sanitizer.dart';
import 'local_manifest_server.dart';
class FileService {
  Future<String> saveMpdToFile(String rawXml) async {
    return LocalManifestServer.instance.publish(DashXmlSanitizer.sanitize(rawXml));
  }
  Future<String?> fetchMpdContent(String url,
      {Map<String, String>? headers}) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = response.body;
        if (body.contains('<MPD') || body.contains('urn:mpeg:dash')) {
          return DashXmlSanitizer.sanitize(body);
        }
      }
    } catch (_) {}
    return null;
  }
  bool isMpdXml(String input) {
    final trimmed = input.trimLeft();
    return trimmed.startsWith('<MPD') ||
        trimmed.startsWith('<?xml') ||
        trimmed.contains('urn:mpeg:dash:schema:mpd');
  }
  bool isMpdUrl(String input) {
    final lower = input.toLowerCase();
    return (lower.startsWith('http://') || lower.startsWith('https://')) &&
        (lower.contains('.mpd') ||
            lower.contains('manifest') ||
            lower.contains('dash'));
  }
  bool isNetworkUrl(String input) =>
      input.startsWith('http://') || input.startsWith('https://');
}
