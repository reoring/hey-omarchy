# Hyprland ショートカットガイド（omarchy-reoring-taisyo）

このガイドは、このディレクトリに含まれる Hyprland のキーバインド（ショートカット）をまとめたものです。

このリポジトリ内: `home/.config/hypr/hey-omarchy-bindings.lua`
適用後の場所: `~/.config/hypr/hey-omarchy-bindings.lua`（`apply.sh` で反映）

## 修飾キーの表記

- `Super`: Windows/Command キー
- `Hyper`: `Super+Ctrl+Alt+Shift`。keyd の共通レイヤーにより、内蔵かなキーまたは登録済み roBa／moNa2 の右親指をホールドして使用できます。
- `Alt`: 通常の左右どちらかの Alt キー。Shift 併用でウィンドウを移動し、ワークスペースの切替には使いません。
- `code:10..19`: 数字キー列（多くの配列で `1..0`）

かなキーを単独で200 ms未満で離すと Enter になります。かなキーを押しながら別のキーを押すと、タップ判定の200 msを待たず即座に Hyper が有効になります。単独で長押しして離しても Enter は出ません。Caps は Hyprland の `ctrl:nocaps` オプションで引き続き Ctrl にします。

変換キーはタップで Backspace、ホールドで Shift。無変換キーはタップで元の無変換、ホールドで Shift になります。どちらもタップ判定は200 ms未満、他キーとの併用は即座に Shift です。単独で長押しして離したときはタップを送りません。両方をホールドした場合、両方を離すまで Shift を維持します。

A は `overloadi(a, overloadt(control, a, 250), 200)` を使用します。直前の文字入力から200 ms未満で押した A は、長押ししても通常の A のままです。それ以外では250 ms未満で離すと A、250 ms以上のホールドで Ctrl になります。`lettermod`/`overloadt2` と異なり、他キーを素早くタップしても Ctrl への切り替えを早めません。間を空けた後の A は離した時点で入力され、長押しリピートより Ctrl が優先されます。入力直後にすぐ Ctrl を使いたい場合は通常の Ctrl／Caps を使ってください。

これらのかな・変換・無変換・A リマップは内蔵キーボード ID `0001:0001:3cf016cc` 限定で、`[ids] *` のフォールバックはありません。roBa／moNa2 はファームウェアの右親指タップ Enter／ホールド Right Command を維持し、ホストの keyd が `rightmeta` を `layer(hyper)` に変換します。左 Super とトラックボールは変更せず、A→Ctrl もこれらの外付けキーボードには適用しません。登録する roBa ID は `k:1d50:615e:c4fd5cd7`／`k:1d50:615e:a41a014e`、moNa2 ID は `k:1d50:615e:90998e90`／`k:1d50:615e:534ac1e7` です。別のファームウェアやデバイス名では `keyd monitor` で識別してからバンドル側の ID を調整してください。roBa の MAC レイヤーの有無にかかわらず適用され、ファームウェアは書き換えません。

keyd は必須です。`apply.sh` は既存の `setup-keyd.sh` を使い、`etc/keyd/kana-hyper.conf`・`etc/keyd/roba-hyper.conf`・共通の `etc/keyd/hyper` を `/etc/keyd/` に一括導入してから Hyprland の既定設定を変更します。セットアップ1回につき対話端末の sudo 昇格を1回使用し、`--skip-packages` 使用時は keyd の事前インストールが必要です。`apply.sh --check`・`apply.sh --dry-run`・`setup-keyd.sh --dry-run` は認証もホストの変更も行いません。keyd 設定だけの適用には `bash ./setup-keyd.sh` を使い、リポジトリへの登録だけでは実機を変更しません。管理対象ファイルはバックアップ後に置換するため、適用前に実機との差分を確認してください。詳細は [README](README.ja.md#適用) を参照してください。

緊急時: リマップで入力できなくなったら **Backspace+Escape+Enter を同時押し**して keyd を停止し、設定を修正してから再起動してください。

ヒント: `Super+I` で Omarchy のキーバインド一覧（`omarchy menu keybindings`）を開けます。

## アプリ起動

| キー | 動作 |
| --- | --- |
| `Super+Enter` | ターミナル（"terminal cwd" で起動） |
| `Super+Shift+F` | ファイルマネージャ（Nautilus） |
| `Super+Shift+B` | ブラウザ |
| `Super+Shift+Alt+B` | ブラウザ（プライベート） |
| `Super+Shift+M` | 音楽（Spotify） |
| `Super+Shift+N` | エディタ |
| `Super+Shift+D` | Docker TUI（lazydocker） |
| `Super+Shift+G` | Signal |
| `Super+Shift+O` | Obsidian |
| `Super+Shift+W` | Typora |
| `Super+Shift+/` | 1Password |

## Web アプリ

| キー | 動作 |
| --- | --- |
| `Super+Shift+A` | ChatGPT |
| `Super+Shift+Alt+A` | Grok |
| `Super+Shift+C` | HEY Calendar |
| `Super+Shift+E` | HEY Mail |
| `Super+Shift+Y` | YouTube |
| `Super+Shift+Alt+G` | WhatsApp |
| `Super+Shift+Ctrl+G` | Google Messages |
| `Super+Shift+P` | Google Photos |
| `Super+Shift+X` | X |
| `Super+Shift+Alt+X` | X（投稿画面） |

## ワークスペース（Hyper 運用）

この設定は、どちらか一方のディスプレイを "main monitor" として扱います。

- `Hyper+QWERTASDFG` は、常に main monitor 側のワークスペース `1..10` を対象にします。
- `Hyper+ZXCVB` は、main monitor 側のワークスペース `11..15` を対象にします。
- `Hyper+YUIOP` は `16..20`、`Hyper+;` は `25` を対象にします。Hyper+H/J/K/L のワークスペース割り当てはなく、Alt+H/J/K/L と Alt+Shift+H/J/K/L は tmux 用に空けています。
- `Hyper+1..0` は、外部モニター接続時に "parking" 用ワークスペースを non-main 側に表示します。
  - `1=99` .. `0=90`
  - 2枚目のモニターが無い場合は `11..20` にフォールバックします。

main monitor の切替は `Super+Ctrl+M` です。

Quattro のバーの "main monitor" ウィジェットはクリック操作に対応しています。

- 左クリック: main monitor 切替
- 右クリック: 外部モニター位置を設定（left/right/up/down）

ターミナルから `hypr-monitor-position menu` または `hypr-monitor-position left|right|up|down` を実行してもOKです。

### ワークスペースに移動

| キー | 動作 |
| --- | --- |
| `Hyper+Q/W/E/R/T` | ワークスペース `1/2/3/4/5`（main） |
| `Hyper+A/S/D/F/G` | ワークスペース `6/7/8/9/10`（main） |
| `Hyper+Z/X/C/V/B` | ワークスペース `11/12/13/14/15`（main） |
| `Hyper+Y/U/I/O/P` | ワークスペース `16/17/18/19/20`（main） |
| `Hyper+;` | ワークスペース `25`（`H/J/K/L` のワークスペース割り当てなし） |
| `Hyper+1..0` | parking `99..90`（フォールバック `11..20`） |

### ウィンドウを移動

内蔵かなキーまたは roBa／moNa2 の Hyper と追加の Shift を押しながら、切替と同じ英字・セミコロン・数字列のキーを使います:

- Hyper+Shift+キーで、アクティブウィンドウをそのワークスペースへ移動します（フォーカスも移動）。左右の Shift、Shift に割り当てられた変換・無変換のホールドが使え、押す順番はどちらでも構いません。keyd の共通 `[hyper+shift]` が追加の Shift と Hyper 内部の Shift を区別し、既存の Alt+Shift 移動操作へ変換します。通常の Alt+Shift も使えます。この区別には内蔵用・roBa／moNa2 用の設定が共有する Hyper レイヤーに入る必要があり、キーボードが4修飾キーを送るだけでは区別できません。
- 旧 Alt 単独のワークスペース切替バインドは明示的に解除します。

## 復元した顔認証・CPU周波数操作

- ロック画面に顔認証の状態を表示し、F2／クリックで再試行できます。パスワード送信・スリープ・画面オフでは認証を中断します。既存の信頼済み Howdy/PAM 設定と登録済み顔モデルが前提で、バンドルによる導入・コピーは行いません。顔認証用PAMがなければ顔認証は無効です。
- CPU周波数ウィジェットは上限とブーストを30秒ごとに表示します。左クリックでメニュー、右クリックで btop を開きます。変更にはPolkit認証と対応cpufreq制御が必要で、下限を維持する一時的な設定です。`hey-cpu-frequency status` は読み取り専用です。

## ウィンドウ / 表示 調整

| キー | 動作 |
| --- | --- |
| `Super+H/J/K/L` | フォーカスを左/下/上/右へ移動 |
| `Super+U` | 分割方向トグル（dwindle） |
| `Super+Ctrl+-` / `Super+Ctrl+=` | 夜間モードを暖色/寒色へ（hyprsunset） |
| `Super+Alt+-` / `Super+Alt+=` | アクティブウィンドウの透明度を下げる/上げる |
| `Super+Alt+Shift+-` / `Super+Alt+Shift+=` | 全体のブラーを下げる/上げる |
| `Super+Shift+;` / `Super+Shift+'` | 現在ワークスペースの gaps を下げる/上げる |
| `Super+Shift+Ctrl+-` / `Super+Shift+Ctrl+=` | 外部モニターのスケールを下げる/上げる |
| `Super+Ctrl+R` | リフレッシュレート切替（利用可能なら 60/120） |
| `Super+Ctrl+Y` | Quattro バー表示トグル |
| `Super+Ctrl+M` | main monitor 切替 + ワークスペース再配置 |
| `Super+Ctrl+P` | 内蔵ディスプレイの ON/OFF（外部無しで消えない安全設計） |
| `Super+Ctrl+O` | ふた閉じサスペンドの ON/OFF（systemd user service） |
| `Super+Ctrl+Alt+O` | 自動回転の ON/OFF（次回ログインにも保存） |

## 設定の場所

- キーバインドは `~/.config/hypr/hey-omarchy-bindings.lua`、入力・透明度は `~/.config/hypr/hey-omarchy.lua` にあります。
- バンドルの `etc/keyd/kana-hyper.conf` で内蔵限定のかな・変換・無変換・A のタップ／ホールド、`etc/keyd/roba-hyper.conf` で完全一致 ID の roBa／moNa2 右親指ホールド、`etc/keyd/hyper` で共通の Hyper／Hyper+Shift を設定します。両 `.conf` は `include hyper` を使い、`setup-keyd.sh` が3ファイルを `/etc/keyd/` に導入します。Hyprland の `kb_file` は空で、旧かな XKB ファイルは使用しません。
- ワークスペースの "main/park" ルーティングは `~/.local/bin/hypr-ws` と `~/.local/bin/hypr-main-monitor-toggle` で実装されています。

## 標準から上書きするキー

標準の Super+J（分割）は U、Super+K（キー一覧）は I に移動し、H/J/K/L をフォーカス移動にします。Super+Ctrl+R（リマインダー）、P（電源パネル）、O（メニュー）はそれぞれ画面リフレッシュレート、内蔵画面、ふた閉じサスペンドの操作に置き換えます。既存の競合バインドは先に解除しています。
