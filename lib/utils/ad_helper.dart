import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class AdHelper {
  static Future<void>? _initialization;

  // Only visible banners initialize ads, after the first app frame.
  static Future<void> initialize() {
    if (!isSupported) return Future.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      await requestTrackingPermission();
      await MobileAds.instance.initialize();
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  // テスト用広告ユニットID
  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-4298440430439400/5859166414'; // テスト用Android Banner
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // テスト用iOS Banner
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 本番用広告ユニットID（実際のアプリIDに置き換える）
  static String get productionBannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-4298440430439400/5859166414'; // 実際のAndroid Banner ID
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // 実際のiOS Banner ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // デバッグモードかどうかで使用する広告ユニットIDを切り替え
  static String get currentBannerAdUnitId {
    // リリースビルドでは本番用IDを使用（現在はテスト用のまま）
    return bannerAdUnitId;
  }

  // App Tracking Transparency権限をリクエスト
  static Future<void> requestTrackingPermission() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final TrackingStatus status =
          await AppTrackingTransparency.trackingAuthorizationStatus;

      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
    // Android 13以降では広告IDへのアクセスに権限が必要だが、
    // AdMobライブラリが自動的に処理するため、明示的な権限リクエストは不要
  }
}
