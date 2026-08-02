import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps AdMob banner + interstitial ads behind Google's official TEST ad
/// unit IDs. Swap these for your real AdMob IDs before publishing — see
/// README.md "Trước khi publish" section.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';

  String get bannerAdUnitId {
    if (Platform.isAndroid) return _testBannerAndroid;
    return _testBannerAndroid; // iOS not targeted yet; same test id placeholder.
  }

  String get interstitialAdUnitId {
    if (Platform.isAndroid) return _testInterstitialAndroid;
    return _testInterstitialAndroid;
  }

  InterstitialAd? _interstitialAd;
  int _gamesSinceInterstitial = 0;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  BannerAd createBannerAd({required void Function() onLoaded}) {
    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    banner.load();
    return banner;
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  /// Shows an interstitial roughly every other finished game so ads never
  /// interrupt active play — call this once when a game ends.
  void maybeShowInterstitialAfterGame() {
    _gamesSinceInterstitial++;
    if (_gamesSinceInterstitial < 2 || _interstitialAd == null) {
      if (_interstitialAd == null) _loadInterstitial();
      return;
    }
    _gamesSinceInterstitial = 0;
    final ad = _interstitialAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );
    ad.show();
  }
}
