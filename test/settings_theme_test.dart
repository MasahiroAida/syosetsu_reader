import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syosetsu/providers/theme_provider.dart';
import 'package:syosetsu/viewmodels/settings_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loading preferences does not overwrite a simultaneous ad change',
      () async {
    SharedPreferences.setMockInitialValues(
        {'show_ads': true, 'ad_position': 'top'});
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    final loading = settings.loadSettings();
    await settings.updateShowAds(false);
    await loading;
    expect(settings.showAds, isFalse);
    expect(settings.adPosition, 'top');
    expect(settings.isInitialized, isTrue);
    expect(
        (await SharedPreferences.getInstance()).getBool('show_ads'), isFalse);
  });

  test('invalid stored ad position defaults to a valid dropdown option',
      () async {
    SharedPreferences.setMockInitialValues({'ad_position': 'invalid'});
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    await settings.loadSettings();
    expect(settings.adPosition, 'bottom');
    await settings.updateAdPosition('top');
    await settings.updateAdPosition('invalid');
    expect(settings.adPosition, 'top');
  });

  test('a theme selection made during startup wins over stored preferences',
      () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 2});
    final theme = ThemeProvider();
    addTearDown(theme.dispose);
    final loading = theme.initialize();
    await theme.setThemeMode(AppThemeMode.light);
    await loading;
    expect(theme.isDarkMode, isFalse);
    expect((await SharedPreferences.getInstance()).getInt('app_theme_mode'), 1);
  });

  test('preference loading safely completes after models are disposed',
      () async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeProvider();
    final settings = SettingsViewModel();
    final loading = [theme.initialize(), settings.loadSettings()];
    theme.dispose();
    settings.dispose();
    await Future.wait(loading);
  });
}
