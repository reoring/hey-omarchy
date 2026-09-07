# Hey Omarchy — Quattro 対応

reoring の個人設定を **Omarchy Quattro（4.x）** に適用するバンドルです。Hyprland のネイティブ Lua と Quickshell を使用し、Omarchy 3 向けの `.conf` や Waybar 設定はインストールしません。

Omarchy 管理下のソースは変更しません。`apply.sh` は変更前のユーザーファイルをバックアップし、専用 Lua モジュールを読み込む行を追加します。既存の標準 Lua モジュールやバーの標準ウィジェット、無関係な `shell.json` 設定は保持します。

関連: [English README](README.md)、[ショートカット一覧](user-guide.ja.md)、[CSKK の説明](japanese/cskk.md)。

## 引き継ぐ機能

- メインモニターのワークスペース 1〜20・25、別画面への parking 99〜90、1画面時の 11〜20 フォールバック。Shift 併用でウィンドウ移動。
- 右 Alt とかなキーによるワークスペース操作。Lua では `ALT`（Mod1）を使用します。旧 `ALTGR` 表記の実際の挙動と同じで、左 Alt にも反応します。Lua に `ALTGR` と書くことはできません。
- tmux と競合する Alt+H/J/K/L は Shift 併用も含めて割り当てなし。
- Caps→Ctrl、かな→Alt_R、キーリピート 40/600、自然スクロール 0.4、入力中のタッチパッド操作。
- Super+H/J/K/L のフォーカス移動、個人用アプリ・Web アプリ起動、透明度、ブラー、余白、画面スケール・位置・リフレッシュレート、夜間モード。
- メインモニター、DDC 輝度、JP/EN、ふた閉じサスペンド、キーボード清掃、カーソル、roBa、WWAN、Tailscale、CPU/btop のネイティブバー操作。
- 無操作15分でロック、16分で画面オフ。先行するスクリーンセーバーなし。復帰時に明るさを復元。
- ディスプレイ・タッチ・ペンの自動回転。サービスの有効・無効状態は保持。
- Fcitx5/CSKK の ASCII パススルー、日本語入力設定、GTK の Emacs 風キー操作。

`waybar-*` という名前の補助コマンドは、Quickshell が読む JSON ステータス生成器として使います。Waybar/Walker 本体は不要です。

## 設定ファイル

| 場所 | 内容 |
|---|---|
| `~/.config/hypr/hey-omarchy.lua` | 入力、透明度・ウィンドウルール、ハードウェア条件 |
| `~/.config/hypr/hey-omarchy-bindings.lua` | キーバインド。標準の競合キーは明示的に解除 |
| `~/.config/hypr/keymap-kana-altgr.xkb` | かな・Caps キーマップ |
| `~/.config/hypr/hey-omarchy-options.lua` | インストーラーが生成する画面/NVIDIA オプション |
| `~/.config/omarchy/shell.json` | 既存バーに独自ウィジェットを追加、アイドル設定 |
| `~/.config/omarchy/plugins/hey-omarchy/` | 共有ステータスサービスとバー部品 |
| `~/.config/omarchy/plugins/hey-omarchy-lock/` | 元の画面オフ時間を再現するロック部品 |
| `~/.local/bin/` | 操作・入力・ネットワーク・ハードウェア補助コマンド |
| `~/.config/systemd/user/` | ふた閉じ抑止と自動回転のサービス |

ロック部品は **Omarchy 4.0.2** のユーザー側コピーです。認証・セッションロックは元実装を使用し、`idle.dpms` で画面オフ時間を設定します。ローカルコピーはパッケージ更新で自動更新されないため、今後 Omarchy のロック実装が変わったら差分を確認・追従してください。

## 適用

このディレクトリで実行します。

```sh
bash ./apply.sh --check
bash ./apply.sh --dry-run --skip-packages
bash ./apply.sh --skip-packages
```

入力メソッドや DDC の依存パッケージも必要なら `--skip-packages` を外します。適用時は稼働中の `omarchy-fcitx5.service` を短時間再起動し、Hyprland の再読み込み・エラー確認後、古い QML キャッシュを残さないようシェルを再起動します。アプリやログインセッションは終了しません。

同一内容のファイルはスキップします。再適用で独自ウィジェットが増殖したり、変更した配置・個別設定が初期化されたりしません。ただしアイドル時間などバンドル管理の値は再適用するため、変更はバンドル側にも保存してください。旧 `.conf` や Quattro 移行時バックアップは削除しません。

### オプション

- `--check`: ファイルとコマンドを確認。ユーザー設定の変更なし。
- `--dry-run`: 予定される操作だけ表示。
- `--skip-packages`: yay のパッケージ導入を省略。
- `--no-bar`: シェルのウィジェットとアイドル設定を省略。
- `--gtk-gsettings` / `--no-gtk-gsettings`: GTK 設定の反映を有効/無効化（標準は有効）。
- `--force-monitors`: preferred 解像度・自動配置・自動スケールの汎用設定を適用。通常は既存 `monitors.lua` を保持。
- `--force-nvidia-env` / `--skip-nvidia-env`: NVIDIA 自動判定を上書き。通常の AMD/Intel 環境には NVIDIA 変数を設定しません。
- `--with-shaders`: Aether のシェーダーへのユーザー側シンボリックリンクを作成。

### 任意のハードウェア設定

```sh
bash ./setup-ddcutil.sh
bash ./setup-wwan-latency-switcher.sh --help
bash ./setup-mpvpaper-live-wallpaper.sh --help
```

DDC は対応外部モニター、WWAN はモデムと関連ツールが必要です。未接続・未対応ならその状態を表示します。自動回転には iio-sensor-proxy の `monitor-sensor` が必要です。

CSKK が必要とする場合のみ、従来どおり sudo で `/etc/ld.so.conf.d/cskk.conf` に `/usr/lib/cskk` を登録します。詳細は CSKK の説明を参照してください。

## 確認とカスタマイズ

```sh
hyprctl configerrors
omarchy shell hey-omarchy status
omarchy shell idle status
omarchy shell lock status
bash tests/run.sh
```

`home/` 以下を変更して再適用するか、ユーザー側のインストール済みファイルを編集します。`home/.config/omarchy/hey-omarchy.json` はマージ用の断片であり、`shell.json` 全体の置き換えではありません。

`Super+Ctrl+Y` は Quattro のバー表示切替、`Super+Ctrl+Alt+O` は自動回転の切替です。標準から変更されるキーはショートカット一覧を参照してください。

## ロールバック

変更前のファイルは隣に `*.bak.YYYYmmdd-HHMMSS` として保存します。

```sh
bash ./rollback.sh --dry-run
bash ./rollback.sh
```

Lua の読み込み元とシェル設定を含め、管理対象の最新バックアップを復元して Hyprland とシェルを再読み込みします。元ファイルが存在しなかった新規ファイルは残します。戻すのは個人設定バンドルであり、**Quattro のシステムアップグレードではありません**。

## ライセンス

MIT（`LICENSE` 参照）。
