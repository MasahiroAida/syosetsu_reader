import 'package:flutter_test/flutter_test.dart';
import 'package:syosetsu/utils/novel_url.dart';

void main() {
  test('parses chapter independently of metadata and normalizes ncode', () {
    final page =
        NovelUrl.parse('https://novel18.syosetu.com/N1234AB/42/?x=1#top');
    expect(page?.ncode, 'n1234ab');
    expect(page?.chapter, 42);
    expect(page?.isR18, isTrue);
    expect(NovelUrl.parse('http://ncode.syosetu.com/n1234ab')?.chapter, 0);
  });

  test('rejects non-novel pages and URLs that only contain a novel URL', () {
    for (final url in [
      'https://ncode.syosetu.com/novelview/infotop/ncode/n1234ab/',
      'https://ncode.syosetu.com/login/',
      'https://example.com/?next=https://ncode.syosetu.com/n1234ab/',
      'https://ncode.syosetu.com.evil.example/n1234ab/',
      'https://ncode.syosetu.com/n1234ab/42/extra/',
      'https://ncode.syosetu.com/n1234ab/0/',
      'javascript:https://ncode.syosetu.com/n1234ab/',
    ]) {
      expect(NovelUrl.parse(url), isNull, reason: url);
    }
  });

  test('restoration is limited to the same novel, domain and chapter', () {
    const saved = 'https://ncode.syosetu.com/n1234ab/7/';
    expect(NovelUrl.matches(saved, 'http://ncode.syosetu.com/N1234AB/7?x=1#p'),
        isTrue);
    for (final other in [
      'https://ncode.syosetu.com/n1234ab/8/',
      'https://ncode.syosetu.com/n9999ab/7/',
      'https://novel18.syosetu.com/n1234ab/7/',
      'https://ncode.syosetu.com/n1234ab/',
    ]) {
      expect(NovelUrl.matches(saved, other), isFalse, reason: other);
    }
    expect(NovelUrl.matches('invalid', 'invalid'), isFalse);
  });
}
