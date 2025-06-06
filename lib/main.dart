import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/novel.dart';
import 'models/bookmark.dart';
import 'models/reading_history.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(NovelAdapter());
  Hive.registerAdapter(BookmarkAdapter());
  Hive.registerAdapter(ReadingHistoryAdapter());
  await Hive.openBox<Novel>('novels');
  await Hive.openBox<Bookmark>('bookmarks');
  await Hive.openBox<ReadingHistory>('reading_history');
  runApp(const NovelReaderApp());
}