@echo off
REM =====================================================
REM libフォルダ配下に以下の構造を作成するバッチファイル
REM =====================================================
REM 実行場所：lib フォルダ直下
REM （バッチが別の場所から呼ばれたときも lib に移動する例を含む）

REM バッチファイル自身のあるフォルダをカレントディレクトリに変更
pushd "%~dp0"

REM ----------------------------
REM ルート直下のファイルを作成
REM ----------------------------
if not exist "main.dart" (
    type nul > "main.dart"
)
if not exist "app.dart" (
    type nul > "app.dart"
)

REM ----------------------------
REM models ディレクトリとファイル
REM ----------------------------
if not exist "models" (
    mkdir "models"
)
if not exist "models\novel.dart" (
    type nul > "models\novel.dart"
)
if not exist "models\bookmark.dart" (
    type nul > "models\bookmark.dart"
)
if not exist "models\reading_history.dart" (
    type nul > "models\reading_history.dart"
)
if not exist "models\search_novel.dart" (
    type nul > "models\search_novel.dart"
)
if not exist "models\review.dart" (
    type nul > "models\review.dart"
)
if not exist "models\ranking_novel.dart" (
    type nul > "models\ranking_novel.dart"
)

REM ----------------------------
REM services ディレクトリとファイル
REM ----------------------------
if not exist "services" (
    mkdir "services"
)
if not exist "services\database_helper.dart" (
    type nul > "services\database_helper.dart"
)
if not exist "services\api_service.dart" (
    type nul > "services\api_service.dart"
)

REM ----------------------------
REM viewmodels ディレクトリとファイル
REM ----------------------------
if not exist "viewmodels" (
    mkdir "viewmodels"
)
if not exist "viewmodels\bookmark_viewmodel.dart" (
    type nul > "viewmodels\bookmark_viewmodel.dart"
)
if not exist "viewmodels\history_viewmodel.dart" (
    type nul > "viewmodels\history_viewmodel.dart"
)
if not exist "viewmodels\search_viewmodel.dart" (
    type nul > "viewmodels\search_viewmodel.dart"
)
if not exist "viewmodels\ranking_viewmodel.dart" (
    type nul > "viewmodels\ranking_viewmodel.dart"
)
if not exist "viewmodels\review_viewmodel.dart" (
    type nul > "viewmodels\review_viewmodel.dart"
)
if not exist "viewmodels\settings_viewmodel.dart" (
    type nul > "viewmodels\settings_viewmodel.dart"
)
if not exist "viewmodels\webview_viewmodel.dart" (
    type nul > "viewmodels\webview_viewmodel.dart"
)

REM ----------------------------
REM views 配下の階層を作成し、ファイルを生成
REM views/screens
REM views/tabs
REM ----------------------------
if not exist "views" (
    mkdir "views"
)
if not exist "views\screens" (
    mkdir "views\screens"
)
if not exist "views\tabs" (
    mkdir "views\tabs"
)

REM --- views/screens 内のファイル ---
if not exist "views\screens\main_screen.dart" (
    type nul > "views\screens\main_screen.dart"
)
if not exist "views\screens\reading_list_screen.dart" (
    type nul > "views\screens\reading_list_screen.dart"
)
if not exist "views\screens\search_screen.dart" (
    type nul > "views\screens\search_screen.dart"
)
if not exist "views\screens\ranking_screen.dart" (
    type nul > "views\screens\ranking_screen.dart"
)
if not exist "views\screens\review_screen.dart" (
    type nul > "views\screens\review_screen.dart"
)
if not exist "views\screens\settings_screen.dart" (
    type nul > "views\screens\settings_screen.dart"
)
if not exist "views\screens\webview_screen.dart" (
    type nul > "views\screens\webview_screen.dart"
)

REM --- views/tabs 内のファイル ---
if not exist "views\tabs\bookmark_tab.dart" (
    type nul > "views\tabs\bookmark_tab.dart"
)
if not exist "views\tabs\history_tab.dart" (
    type nul > "views\tabs\history_tab.dart"
)

REM ----------------------------
REM utils ディレクトリとファイル
REM ----------------------------
if not exist "utils" (
    mkdir "utils"
)
if not exist "utils\constants.dart" (
    type nul > "utils\constants.dart"
)

echo.
echo ディレクトリ構造とファイルを作成しました。
echo.

REM 最後に元のディレクトリに戻す（必要なければコメントアウト可）
popd

pause
