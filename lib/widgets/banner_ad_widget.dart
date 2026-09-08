import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_helper.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    if (AdHelper.isSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadBannerAd();
      });
    }
  }

  Future<void> _loadBannerAd() async {
    try {
      await AdHelper.initialize();
      if (!mounted) return;
      _bannerAd = BannerAd(
        adUnitId: AdHelper.currentBannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted || !identical(_bannerAd, ad)) return;
            setState(() {
              _isAdLoaded = true;
            });
            debugPrint('バナー広告が読み込まれました');
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('バナー広告の読み込みに失敗しました: $error');
            ad.dispose();
            if (!mounted || !identical(_bannerAd, ad)) return;
            _bannerAd = null;
            setState(() {
              _isAdLoaded = false;
            });
          },
          onAdOpened: (ad) {
            debugPrint('バナー広告が開かれました');
          },
          onAdClosed: (ad) {
            debugPrint('バナー広告が閉じられました');
          },
        ),
      );

      await _bannerAd?.load();
    } catch (e) {
      debugPrint('バナー広告初期化エラー: $e');
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) setState(() => _isAdLoaded = false);
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      // 広告が読み込まれていない場合は空のコンテナを返す
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
