# HelloWorldATV — Apple TV 2/3 向け Hello World frappliance

## ファイル構成

```
HelloWorldATV/
├── Makefile                          ← theos ビルド定義
├── build.sh                          ← ビルド & インストール一括スクリプト
├── Info.plist                        ← バンドル定義
├── Classes/
│   ├── HelloWorldAppliance.mm        ← Appliance クラス (ランタイム動的生成)
│   └── HelloWorldController.mm       ← Controller クラス (ランタイム動的生成)
└── layout/
    └── Applications/
        └── AppleTV.app/
            └── Appliances/           ← theos が自動的にインストール先とする
```

---

## 設計の根拠

### なぜ通常の @implementation が使えないのか

iOS 5.x 以降、Apple は BackRow.framework を廃止し、`BRBaseAppliance` や
`BRController` などの全クラスを **AppleTV.app バイナリ内** に移した。

通常の Objective-C サブクラス化 (`@interface Foo : BRBaseAppliance`) は
リンク時にシンボルが解決できないため不可。

KodiAppliance.mm / KodiController.mm (xbmc 14.2-Helix) と同じ手法で、
**Objective-C ランタイム関数** を使って起動時に動的にサブクラスを生成・登録する。

```
objc_allocateClassPair("BRBaseAppliance", "HelloWorldAppliance")
  ↓
MSHookMessageEx でメソッドを登録
  ↓
objc_registerClassPair
```

この処理は `__attribute__((constructor))` 関数内で行うため、
dylib ロード時に自動実行される。

### iOS バージョンによるインストール先の違い

| iOS バージョン | インストール先 | killall 対象 |
|---|---|---|
| 4.1 以前 | `/Applications/Lowtide.app/Appliances/` | `killall -9 Lowtide` |
| **4.2 以降 (ATV2/3 対象)** | `/Applications/AppleTV.app/Appliances/` | `killall -9 AppleTV` |

### ビルド設定値の根拠

| 設定 | 値 | 根拠 |
|---|---|---|
| `ARCHS` | `armv7` | project.pbxproj (Kodi-ATV2 ターゲット) |
| `IPHONEOS_DEPLOYMENT_TARGET` | `4.2` | project.pbxproj (Kodi-ATV2 ターゲット) |
| `SDKVERSION` | `4.3` | nitoTV Makefile |
| `WRAPPER_EXTENSION` | `frappliance` | project.pbxproj |
| `TARGETED_DEVICE_FAMILY` | `2,3` | project.pbxproj (iPad + AppleTV) |

---

## 環境構築

### 必要なもの

1. **macOS** (Intel / Apple Silicon どちらでも可)
2. **Xcode** (古い SDK を使うため Xcode 4.x〜5.x 推奨、または Command Line Tools)
3. **theos**
4. **iOS 4.3 SDK**
5. **substrate.h** (MobileSubstrate ヘッダ)

### theos のセットアップ

```bash
export THEOS=/opt/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
```

### iOS 4.3 SDK の配置

Xcode 4.x アーカイブから抽出するか、サードパーティアーカイブから取得して配置する。

```bash
ls $THEOS/sdks/
# → iPhoneOS4.3.sdk  が存在すること

# Xcode 4.x から抽出する場合:
cp -r /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/\
Developer/SDKs/iPhoneOS4.3.sdk $THEOS/sdks/
```

### substrate.h の配置

nitoTV リポジトリの `substrate/` ディレクトリから取得する。

```bash
# nitoTV をクローンして substrate.h を Classes/ にコピー
git clone https://github.com/lechium/nitoTV /tmp/nitoTV
cp /tmp/nitoTV/substrate/substrate.h $THEOS/include/
```

---

## ビルド手順

### 方法 A : build.sh (推奨)

```bash
cd HelloWorldATV/

# Apple TV の IP アドレスを設定
export THEOS=/opt/theos
export THEOS_DEVICE_IP=192.168.x.x

bash build.sh
# → clean → build → stage → install → killall AppleTV
```

### 方法 B : make を個別実行

```bash
export THEOS=/opt/theos
export THEOS_DEVICE_IP=192.168.x.x
export THEOS_DEVICE_PORT=22

make clean
make
make stage
make install
```

### 方法 C : 手動で scp インストール

ビルドのみ行い SSH で転送する場合。

```bash
make                # ビルドのみ

ATV_IP=192.168.x.x

# .frappliance を Apple TV に転送
scp -r obj/HelloWorldATV.frappliance \
  root@$ATV_IP:/Applications/AppleTV.app/Appliances/

# Apple TV の SpringBoard (AppleTV.app) を再起動
ssh root@$ATV_IP "killall -9 AppleTV"
```

SSH のデフォルト認証情報: ユーザー `root` / パスワード `alpine`

---

## 動作確認

1. Apple TV のホーム画面に **"Hello World"** のアイコンが表示される
2. 選択すると黒背景に **"Hello, World!"** と白文字が表示される
3. リモコンの **Menu ボタン** でホーム画面に戻れる

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `SDK not found: iPhoneOS4.3` | SDK 未配置 | `$THEOS/sdks/iPhoneOS4.3.sdk` を配置する |
| `substrate.h not found` | ヘッダ未配置 | `$THEOS/include/substrate.h` を配置する |
| ホーム画面にアイコンが出ない | Info.plist のキー誤り | `NSPrincipalClass` が `HelloWorldAppliance` と一致しているか確認 |
| 起動直後にクラッシュ | 脱獄環境に MobileSubstrate がない | Cydia から `org.theos.substrate` をインストールする |
| 画面が黒いまま | `BRWindow` が取れていない | SSH で `syslog` を確認し `[HelloWorldATV]` のログを追う |
| Lowtide にアイコンが出ない | iOS 4.1 以前の環境 | `HW_INSTALL_PATH` を `Lowtide.app/Appliances` に変更し `killall -9 Lowtide` |

---

## 参考リポジトリ・ソース

| ソース | 参照内容 |
|---|---|
| [lechium/nitoTV](https://github.com/lechium/nitoTV) | Makefile 構造、substrate.h |
| [xbmc/xbmc (14.2-Helix)](https://github.com/xbmc/xbmc/tree/14.2-Helix) | KodiAppliance.mm / KodiController.mm のランタイムフック手法 |
| [NSSpiral/Blackb0x](https://github.com/NSSpiral/Blackb0x) | 脱獄ツール、動作確認環境 |
| [xbmc/atv2](https://github.com/xbmc/atv2) | 旧 XBMC ATV2 実装 |
| The Apple Wiki — Appliances | 標準 .frappliance 一覧、Hello World Makefile の原型 |
| Kodi project.pbxproj (Kodi-ATV2 ターゲット) | ARCHS / DEPLOYMENT_TARGET / TARGETED_DEVICE_FAMILY の正確な値 |
