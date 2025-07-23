import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class AdHelper {
  // テスト用広告ユニットID
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4298440430439400/5859166414'; // テスト用Android Banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // テスト用iOS Banner
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 本番用広告ユニットID（実際のアプリIDに置き換える）
  static String get productionBannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4298440430439400/5859166414'; // 実際のAndroid Banner ID
    } else if (Platform.isIOS) {
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
    if (Platform.isIOS) {
      final TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;
      
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
    // Android 13以降では広告IDへのアクセスに権限が必要だが、
    // AdMobライブラリが自動的に処理するため、明示的な権限リクエストは不要
  }
}