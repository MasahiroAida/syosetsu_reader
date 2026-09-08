import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syosetsu/app.dart';
import 'package:syosetsu/models/bookmark.dart';
import 'package:syosetsu/models/novel.dart';
import 'package:syosetsu/models/reading_history.dart';
import 'package:syosetsu/viewmodels/search_viewmodel.dart';
import 'package:syosetsu/viewmodels/settings_viewmodel.dart';
import 'package:syosetsu/views/screens/main_screen.dart';
import 'package:syosetsu/views/screens/search_screen.dart';
import 'package:syosetsu/widgets/banner_ad_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'show_ads': false});
    directory = await Directory.systemTemp.createTemp('syosetsu_widget_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NovelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BookmarkAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReadingHistoryAdapter());
    }
    await Hive.openBox<Novel>('novels');
    await Hive.openBox<Bookmark>('bookmarks');
    await Hive.openBox<ReadingHistory>('reading_history');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('real app starts and applies shared ad visibility and position',
      (tester) async {
    await tester.pumpWidget(const NovelReaderApp());
    await tester.pumpAndSettle();
    expect(find.text('ブックマーク'), findsWidgets);
    expect(find.byType(BannerAdWidget), findsNothing);
    final settings =
        tester.element(find.byType(MainScreen)).read<SettingsViewModel>();
    await settings.updateShowAds(true);
    await tester.pumpAndSettle();
    expect(find.byType(BannerAdWidget), findsOneWidget);
    final bottomY = tester.getTopLeft(find.byType(BannerAdWidget)).dy;
    await settings.updateAdPosition('top');
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.byType(BannerAdWidget)).dy, lessThan(bottomY));
    await settings.updateShowAds(false);
    await tester.pumpAndSettle();
    expect(find.byType(BannerAdWidget), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('R18 mode replaces the search state and filters', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    final oldModel =
        tester.element(find.byType(TextField).first).read<SearchViewModel>();
    oldModel.updateGenres({101});
    await tester.pumpWidget(const MaterialApp(home: SearchScreen(isR18: true)));
    final newModel =
        tester.element(find.byType(TextField).first).read<SearchViewModel>();
    expect(identical(oldModel, newModel), isFalse);
    expect(newModel.selectedGenres, isEmpty);
    if (!newModel.showFilters) newModel.toggleFilters();
    await tester.pumpAndSettle();
    expect(find.text('掲載サイト'), findsOneWidget);
    expect(find.text('ノクターンノベルズ'), findsOneWidget);
    expect(find.text('R15'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('search filters fit while the keyboard reduces available height',
      (tester) async {
    tester.view.physicalSize = const Size(360, 550);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    final model =
        tester.element(find.byType(TextField).first).read<SearchViewModel>();
    if (!model.showFilters) model.toggleFilters();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
