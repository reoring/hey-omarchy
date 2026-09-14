# Hey Omarchy — Quattro 対応

reoring の個人設定を **Omarchy Quattro（4.x）** に適用するバンドルです。Hyprland のネイティブ Lua と Quickshell を使用し、Omarchy 3 向けの `.conf` や Waybar 設定はインストールしません。

Omarchy 管理下のソースは変更しません。`apply.sh` は変更前のユーザーファイルをバックアップし、専用 Lua モジュールを読み込む行を追加します。また、後述のシステム用 keyd 設定を sudo で導入します。既存の標準 Lua モジュールや無関係な `shell.json` 設定は保持します。バーはWS表示を外し、既存の時計を左のメニュー横へ移し、独自操作を右側のトグルにまとめます。

関連: [English README](README.md)、[ショートカット一覧](user-guide.ja.md)、[CSKK の説明](japanese/cskk.md)。

## 引き継ぐ機能

- Hyper でメインモニターのワークスペース 1〜20・25、別画面への parking 99〜90、1画面時の 11〜20 フォールバックを切り替えます。かな／roBa／moNa2 共通の Hyper+Shift と同じキーでウィンドウを移動でき、従来の Alt+Shift も使えます。
- かなキーを単独で200 ms未満で離すと Enter、押しながら別のキーを押すと Hyper（`Super+Ctrl+Alt+Shift`）になります。同時押しは200 ms待たず即座に有効になり、単独で長押しして離しても Enter は出ません。通常の Alt ではワークスペースを切り替えません。
- roBa／moNa2 の右親指はファームウェアのタップ Enter／ホールド Right Command を維持します。このホストの keyd がホールドを共通 Hyper レイヤーに変換し、左 Super とトラックボールは変更しません。かな・変換・無変換・A のリマップは登録済み内蔵キーボード限定で、これらの外付けキーボードには適用しません。
- 変換キーはタップで Backspace、ホールドで Shift。無変換キーはタップ時の無変換を残し、ホールドで Shift にします。どちらもタップ判定は200 ms未満、他キーとの併用では即座に Shift となり、単独の長押し後はタップを送りません。
- A はタップで通常入力、250 msホールドで Ctrl。ただし直前の文字入力から200 ms未満なら通常の A を優先します。他キーの素早いタップでは Ctrl に切り替えません。即座の Ctrl 操作より誤爆防止を優先し、間を空けた後の A はキーを離した時点で入力されます。
- tmux と競合する Alt+H/J/K/L は Alt+Shift 併用も含めて割り当てなし。
- Caps→Ctrl は引き続き Hyprland 側で設定。キーリピート 40/600、自然スクロール 0.4、入力中のタッチパッド操作を保持。
- Super+H/J/K/L のフォーカス移動、個人用アプリ・Web アプリ起動、透明度、ブラー、余白、画面スケール・位置・リフレッシュレート、夜間モード。
- メインモニター、DDC 輝度、JP/EN、ふた閉じサスペンド、キーボード清掃、カーソル、roBa、WWAN、Tailscale、CPU/btop、CPU周波数上限・ブーストのネイティブバー操作。
- 無操作15分でロック、16分で画面オフ。先行するスクリーンセーバーなし。復帰時に明るさを復元。
- ディスプレイ・タッチ・ペンの自動回転。サービスの有効・無効状態は保持。
- Fcitx5/CSKK の ASCII パススルー、日本語入力設定、GTK の Emacs 風キー操作。

`waybar-*` という名前の補助コマンドは、Quickshell が読む JSON ステータス生成器として使います。Waybar/Walker 本体は不要です。

## 設定ファイル

| 場所 | 内容 |
|---|---|
| `~/.config/hypr/hey-omarchy.lua` | 入力、透明度・ウィンドウルール、ハードウェア条件 |
| `~/.config/hypr/hey-omarchy-bindings.lua` | キーバインド。標準の競合キーは明示的に解除 |
| `/etc/keyd/kana-hyper.conf` | 内蔵キーボード限定のかな・変換・無変換・A のタップ／ホールド設定。`hyper` を include |
| `/etc/keyd/roba-hyper.conf` | roBa／moNa2 キーボードの完全一致 ID と `rightmeta = layer(hyper)`。`hyper` を include |
| `/etc/keyd/hyper` | ワークスペース切替とウィンドウ移動に使う共通の `[hyper:C-A-S-M]`・`[hyper+shift]` レイヤー |
| `~/.config/hypr/hey-omarchy-options.lua` | インストーラーが生成する画面/NVIDIA オプション |
| `~/.config/omarchy/shell.json` | 既存バーに独自ウィジェットを追加、アイドル設定 |
| `~/.config/omarchy/plugins/hey-omarchy/` | 共有ステータスサービスとバー部品 |
| `~/.config/omarchy/plugins/hey-omarchy-lock/` | 元の画面オフ時間を再現するロック部品 |
| `~/.config/omarchy/plugins/reoring.rain/` | 壁紙の雨とガラスの水滴（コンパイル済みシェーダー同梱）。有効化設定は変更しません |
| `~/.local/bin/` | 操作・入力・ネットワーク・ハードウェア補助コマンド |
| `~/.config/systemd/user/` | ふた閉じ抑止と自動回転のサービス |

ロック部品は **Omarchy 4.0.2** を基に、このホストの顔認証拡張を復元したものです。`idle.dpms` で画面オフ時間を設定します。顔認証には既存の信頼済み `/etc/pam.d/omarchy-lock-face`、`/opt/howdy/` 以下の Howdy・アカウント検査、カメラ設定、登録済み顔モデル、`dbus-monitor` が必要です。このバンドルは認証基盤の導入・上書きや生体情報のコピーを行いません。顔認証用PAMがなければ顔認証は無効となり、パスワード・指紋は既存の設定に従います。F2／顔認証メッセージのクリックで再試行でき、パスワード送信・スリープ・画面オフで認証を中断します。ローカルコピーはパッケージ更新で自動更新されないため、Omarchy更新時には差分を確認してください。

`cpu-frequency` ウィジェットは同梱の `hey-cpu-frequency` を使い、30秒ごとに読み取り専用で状態を取得します。左クリックで上限・上限解除・ブーストのメニュー、右クリックで btop を開きます。変更には `pkexec` によるPolkit認証、対応するLinux cpufreq制御、Omarchyのメニュー・通知コマンドが必要です。周波数固定ではなく一時的な上限設定で、再起動や電源管理によりリセットされる場合があります。

右側の `⋯` をクリックすると独自操作13個を表示し、`‹` で再び隠します。シェル再起動後は閉じた状態です。非表示にしても機能やステータス取得は停止しません。標準のネットワーク・音量・電源などは常時表示のままです。

## 適用

このディレクトリで実行します。

```sh
bash ./apply.sh --check
bash ./apply.sh --dry-run --skip-packages
bash ./apply.sh --skip-packages
```

keyd は必須です。keyd・入力メソッド・DDC の依存パッケージも必要なら `--skip-packages` を外します。`--skip-packages` 使用時は keyd を事前にインストールしてください。`apply.sh` は既存の `setup-keyd.sh` を呼び、`etc/keyd/` の3ファイルを `/etc/keyd/` に一括導入します。セットアップ1回につき対話端末の通常の sudo 昇格を1回使用し、keyd を有効化・起動します。すでに稼働中なら設定を再読み込みします。この処理が成功するまでユーザーの Hyprland 既定設定は変更しません。`--check` と `--dry-run` は認証もホストの変更も行わず、サービスの起動・再読み込みもしません。

`etc/keyd/kana-hyper.conf` は内蔵キーボード ID `0001:0001:3cf016cc` のみを対象に、`katakanahiragana = overload(hyper, enter)` と `[global] overload_tap_timeout = 200` を使用します。ワイルドカードのフォールバックはありません。`etc/keyd/roba-hyper.conf` は roBa の `k:1d50:615e:c4fd5cd7`／`k:1d50:615e:a41a014e` と、moNa2 の `k:1d50:615e:90998e90`／`k:1d50:615e:534ac1e7` を登録します。これらの外付けキーボードには内蔵用の A→Ctrl リマップを適用しません。別のファームウェアやデバイス名では ID が異なるため、`keyd monitor` で識別してからバンドル側の ID を調整してください。

両設定は `include hyper` で `etc/keyd/hyper` を共有し、Hyper+Shift によるウィンドウ移動にも対応します。roBa／moNa2 のファームウェアは右親指のタップで Enter、ホールドで Right Command（`RIGHT_WIN`、keyd では `rightmeta`）を送ります。ホスト側ではそのホールドだけを Hyper に変換し、左 Super とトラックボール入力は変更しません。roBa の MAC レイヤーの有無にかかわらず同じ `RIGHT_WIN` が出るため、どちらでも適用されます。別のマシンやファームウェアは変更しません。リポジトリへの登録だけでは実機に適用されません。

keyd の導入済み環境で、keyd 部分だけを確認・再現する場合:

```sh
bash ./setup-keyd.sh --dry-run
bash ./setup-keyd.sh
```

Hyprland の `kb_file` は空にし、`kb_options = "ctrl:nocaps"` を保持します。不要になったインストール済みの `~/.config/hypr/keymap-kana-altgr.xkb` はバックアップ後に削除します。

適用時は稼働中の `omarchy-fcitx5.service` を短時間再起動し、Hyprland の再読み込み・エラー確認後、古い QML キャッシュを残さないようシェルを再起動します。アプリやログインセッションは終了しません。keyd の設定で入力できなくなった場合は **Backspace+Escape+Enter を同時押し**して keyd を停止し、設定を修正してから再起動してください。

同一内容のファイルはスキップします。再適用では旧来の個別ウィジェットを1つの開閉式コントロールに置き換え、WS表示を外し、時計の書式を保持して左へ移します。他のウィジェットは保持します。**管理対象ファイルはマージではなくリポジトリの内容で置換**し、変更前を隣の日時付きバックアップに保存します。適用前に実機との差分を確認し、残したい変更を先にバンドルへ取り込んでください。シェルJSONはマージしますが、アイドル時間やコンパクトなバー配置は再適用します。旧 `.conf` や Quattro 移行時バックアップは削除しません。

### オプション

- `--check`: ファイルとコマンドを確認。認証・ホストの変更なし。
- `--dry-run`: 予定される操作だけ表示。認証・ホストの変更なし。
- `--skip-packages`: yay のパッケージ導入を省略。keyd の事前インストールが必要。
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

変更前のファイルは隣に `*.bak.YYYYmmdd-HHMMSS` として保存します。`/etc/keyd/` のバンドル3ファイルと、存在する場合は不要になったかな XKB ファイルも対象です。

```sh
bash ./rollback.sh --dry-run
bash ./rollback.sh
```

Lua の読み込み元とシェル設定を含め、管理対象ユーザーファイルの最新バックアップを復元して Hyprland とシェルを再読み込みします。keyd 設定は sudo とファイルごとの所有・バックアップ記録で以前の内容に戻し、元ファイルがなければバンドルが作成したファイルを安全に削除します。戻すのは適用後に変更されていないバンドル所有のファイルだけで、後から行ったユーザー編集は保持し、最初から同一内容だったファイルは所有扱いにしません。残す設定が共通の `hyper` include に依存する場合は、安全のためその共有ファイルも保持します。keyd が稼働中なら再読み込みしますが、サービスの無効化や無関係なリマップの削除はしません。keyd だけ戻す場合は `bash ./setup-keyd.sh --rollback` を使います（`--dry-run` を追加すると認証・ホスト変更なしで確認できます）。かな XKB ファイルも適用時のバックアップがあれば復元します。それ以外の、元ファイルが存在しなかった新規ファイルは残します。`--dry-run` は何も変更しません。戻すのは個人設定バンドルであり、**Quattro のシステムアップグレードではありません**。

## ライセンス

MIT（`LICENSE` 参照）。
