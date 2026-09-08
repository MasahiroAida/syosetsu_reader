/// The identity of a novel page, independent of tracking queries and fragments.
class NovelUrl {
  const NovelUrl._(this.ncode, this.chapter, this.isR18);

  final String ncode;
  final int chapter;
  final bool isR18;

  static NovelUrl? parse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        (uri.host != 'ncode.syosetu.com' &&
            uri.host != 'novel18.syosetu.com')) {
      return null;
    }
    final match =
        RegExp(r'^/(n[0-9]+[a-z]+)(?:/([0-9]+))?/?$', caseSensitive: false)
            .firstMatch(uri.path);
    if (match == null) return null;
    final chapter = match.group(2) == null ? 0 : int.tryParse(match.group(2)!);
    if (chapter == null || (match.group(2) != null && chapter <= 0)) {
      return null;
    }
    return NovelUrl._(match.group(1)!.toLowerCase(), chapter,
        uri.host == 'novel18.syosetu.com');
  }

  bool isSamePage(NovelUrl other) =>
      ncode == other.ncode && chapter == other.chapter && isR18 == other.isR18;

  static bool matches(String first, String second) {
    final page = parse(first);
    final other = parse(second);
    return page != null && other != null && page.isSamePage(other);
  }
}
