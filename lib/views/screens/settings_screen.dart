import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/settings_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SettingsViewModel();
    _viewModel.loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SettingsViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('設定'),
            ),
            body: ListView(
              children: [
                _buildSectionHeader('テーマ設定'),
                _buildThemeSettings(viewModel),
                
                const Divider(height: 32),
                
                _buildSectionHeader('広告設定'),
                _buildAdSettings(viewModel),
                
                const Divider(height: 32),
                
                _buildSectionHeader('その他'),
                _buildOtherSettings(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildThemeSettings(SettingsViewModel viewModel) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('ダークモード'),
          subtitle: const Text('暗いテーマを使用します'),
          value: viewModel.darkMode,
          onChanged: (value) {
            viewModel.updateDarkMode(value);
          },
          secondary: Icon(
            viewModel.darkMode ? Icons.dark_mode : Icons.light_mode,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildAdSettings(SettingsViewModel viewModel) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('広告表示'),
          subtitle: const Text('広告を表示してアプリ開発を支援'),
          value: viewModel.showAds,
          onChanged: (value) {
            viewModel.updateShowAds(value);
          },
          secondary: const Icon(
            Icons.ads_click,
            color: Colors.green,
          ),
        ),
        if (viewModel.showAds) ...[
          ListTile(
            leading: const Icon(Icons.place, color: Colors.orange),
            title: const Text('広告表示位置'),
            subtitle: Text(viewModel.adPosition == 'top' ? '上部' : '下部'),
            trailing: DropdownButton<String>(
              value: viewModel.adPosition,
              underline: Container(),
              items: const [
                DropdownMenuItem(
                  value: 'top',
                  child: Text('上部'),
                ),
                DropdownMenuItem(
                  value: 'bottom',
                  child: Text('下部'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  viewModel.updateAdPosition(value);
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOtherSettings(SettingsViewModel viewModel) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.clear_all, color: Colors.red),
          title: const Text('キャッシュクリア'),
          subtitle: const Text('アプリのキャッシュデータを削除します'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('キャッシュクリア'),
                content: const Text('キャッシュデータを削除しますか？\nこの操作は元に戻せません。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('削除'),
                  ),
                ],
              ),
            );

            if (result == true) {
              await viewModel.clearCache();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('キャッシュをクリアしました'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.blue),
          title: const Text('アプリについて'),
          subtitle: const Text('バージョン情報とライセンス'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: '小説リーダー',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2024 Novel Reader App',
              children: [
                const SizedBox(height: 16),
                const Text(
                  'このアプリは「なろう小説」を快適に読むためのリーダーアプリです。',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  '機能や不具合についてのご要望・ご報告をお待ちしています。',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            );
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, color: Colors.purple),
          title: const Text('プライバシーポリシー'),
          subtitle: const Text('個人情報の取り扱いについて'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('プライバシーポリシー'),
                content: const SingleChildScrollView(
                  child: Text(
                    'このアプリは以下の情報を収集・利用いたします：\n\n'
                    '• 読書履歴（端末内のみ保存）\n'
                    '• ブックマーク（端末内のみ保存）\n'
                    '• アプリ設定（端末内のみ保存）\n\n'
                    '収集した情報は、アプリの機能向上以外の目的で使用されることはありません。\n\n'
                    '外部サーバーへの個人情報の送信は行いません。',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            );
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.help_outline, color: Colors.teal),
          title: const Text('ヘルプ・サポート'),
          subtitle: const Text('使い方とよくある質問'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('ヘルプ'),
                content: const SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '■ 基本的な使い方\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '1. 検索タブで読みたい小説を探す\n'
                        '2. 作品をタップして読む\n'
                        '3. ブックマークして後で続きを読む\n'
                        '4. ランキングから人気作品を発見\n\n',
                      ),
                      Text(
                        '■ よくある質問\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Q: オフラインで読めますか？\n'
                        'A: いいえ、インターネット接続が必要です。\n\n'
                        'Q: 途中まで読んだ続きから読めますか？\n'
                        'A: はい、履歴から続きを読むことができます。\n\n'
                        'Q: 文字サイズは変更できますか？\n'
                        'A: はい、読書画面の設定から調整できます。',
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}