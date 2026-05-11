# NutriVision — 栄養成分表示スキャナー

食品パッケージの栄養成分表示をカメラでリアルタイムに読み取り、構造化データとして出力する Flutter アプリのプロトタイプです。

## 対応フォーマット

| フォーマット | 規格 | 必須項目 |
|---|---|---|
| **JP** | 食品表示基準（消費者庁） | 熱量・たんぱく質・脂質・炭水化物・食塩相当量 |
| **FDA** | 21 CFR 101.9（2020年改正） | Calories, Total Fat, Sodium, Total Carbohydrate, Protein |
| **EU** | EU 規則 1169/2011 | Energy, Fat, Saturated Fat, Carbohydrate, Sugars, Protein, Salt |

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter (Dart)                          │
│                                                         │
│  CameraScreen ─► OcrService ─► LabelParser              │
│       │           (MethodChannel)    │                  │
│       │                        ┌────┴────┐              │
│       │                  JpParser  FdaParser  EuParser  │
│       ▼                                                 │
│  ResultScreen ─► ExportService                          │
│                  (JSON / CSV / Clipboard)               │
└──────────────────┬────────────────┬────────────────────┘
                   │                │
          ┌────────▼───┐   ┌────────▼──────┐
          │ iOS Vision │   │ Android ML Kit │
          │ (Swift)    │   │ (Kotlin)       │
          └────────────┘   └───────────────┘
```

## ディレクトリ構成

```
lib/
├── main.dart
├── models/
│   ├── nutrition_data.dart   # NutritionData, Nutrient, NutrientValue
│   └── ocr_block.dart        # OCR結果の1テキストブロック
├── services/
│   ├── ocr_service.dart      # MethodChannel ブリッジ
│   └── export_service.dart   # JSON / CSV 出力
├── parser/
│   ├── label_parser.dart     # フォーマット自動検出 + ディスパッチ
│   ├── jp_parser.dart        # 食品表示基準パーサー
│   ├── fda_parser.dart       # FDA Nutrition Facts パーサー
│   ├── eu_parser.dart        # EU 栄養表示パーサー
│   └── parser_utils.dart     # 共通ユーティリティ（全角数字正規化など）
├── screens/
│   ├── camera_screen.dart    # カメラプレビュー + 自動検出 UI
│   └── result_screen.dart    # 解析結果表示 + 出力ボタン
└── widgets/
    ├── scan_overlay_painter.dart    # カメラオーバーレイ描画
    └── nutrition_table_widget.dart  # 栄養成分テーブル

ios/Runner/
├── NativeOCRPlugin.swift   # Vision framework ブリッジ
└── AppDelegate.swift

android/app/src/main/kotlin/com/nutrivision/app/
├── NativeOCRPlugin.kt      # ML Kit ブリッジ
└── MainActivity.kt
```

## スキャンフロー

```
カメラ起動
    │
    ▼  1.2秒ごと
takePicture() → JPEG
    │
    ▼  MethodChannel
native OCR (Vision / ML Kit)
    │
    ▼
OcrBlock[] （テキスト + 正規化座標）
    │
    ▼
LabelParser.detect()  → JP / FDA / EU を自動判定
    │
    ▼
各パーサー → NutritionData（confidence 0〜1）
    │
    ├── confidence < 0.8 → スキャン継続（プログレスバー更新）
    │
    └── confidence ≥ 0.8 → 「栄養成分表を検出」バナー → 1.2秒後に結果画面へ
```

## データモデル（JSON 出力例）

```json
{
  "format": "JP",
  "capturedAt": "2026-01-01T12:00:00.000",
  "confidence": 1.0,
  "servingSize": "1食あたり 200g",
  "nutrients": {
    "energy":       { "value": 358, "unit": "kcal" },
    "protein":      { "value": 12.4, "unit": "g" },
    "fat":          { "value": 8.0,  "unit": "g" },
    "carbohydrate": { "value": 56.2, "unit": "g" },
    "salt":         { "value": 1.8,  "unit": "g" }
  }
}
```

## ネイティブ OCR

### iOS — Vision framework
- `VNRecognizeTextRequest` (accurate モード)
- 認識言語: `["ja-JP", "en-US"]`
- 言語補正: ON
- 最小テキスト高さフィルター: 1%（ノイズ除去）

### Android — ML Kit Text Recognition
- `TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)`
- ML Kit Japanese モデル (`text-recognition-japanese:16.0.0`) をオンデバイスバンドル
- `AndroidManifest.xml` で `com.google.mlkit.vision.DEPENDENCIES=ocr_japanese` を宣言し初回起動時ダウンロード

## 出力形式

| 形式 | 操作 |
|------|------|
| JSON（インデント付き） | クリップボードにコピー / ファイル共有 |
| CSV | ファイル共有（`share_plus`） |

## セットアップ

```bash
flutter pub get
flutter run          # 実機またはシミュレータ
flutter test         # パーサー単体テスト（カメラ不要）
```

### iOS 追加設定
`ios/Runner/Info.plist` に `NSCameraUsageDescription` が記載済みです。

### Android 追加設定
`android/app/src/main/AndroidManifest.xml` の `CAMERA` パーミッションと ML Kit 依存が設定済みです。
