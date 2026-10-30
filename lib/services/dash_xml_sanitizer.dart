/// Repairs the single most common way "real world" DASH manifests (copied
/// out of a browser network tab, a chat message, a script's stdout, etc.)
/// turn into invalid XML: bare `&` characters inside BaseURL query strings
/// (`?_nc_cat=102&_nc_sid=...`) that were never escaped to `&amp;`.
///
/// Why this matters: a bare `&` not followed by a known entity name and `;`
/// is a fatal XML well-formedness error per the XML spec. Browsers (and
/// dash.js, which parses the manifest with a lenient JS-based parser) will
/// often shrug this off and keep going. Android's `XmlPullParser` — which
/// ExoPlayer's DASH manifest parser is built on — does not. It throws
/// immediately, before ExoPlayer ever opens a network connection. That
/// produces a generic, message-less "Source error" instantly, which is
/// indistinguishable at the UI layer from a network/auth failure but has
/// nothing to do with the URL, headers, or cookies — the manifest never
/// even got that far.
class DashXmlSanitizer {
  static final RegExp _bareAmpersand =
      RegExp(r'&(?!amp;|lt;|gt;|quot;|apos;|#\d+;|#x[0-9a-fA-F]+;)');

  /// Escapes any `&` in [xml] that isn't already part of a valid XML entity.
  static String sanitize(String xml) {
    return xml.replaceAll(_bareAmpersand, '&amp;');
  }
}
