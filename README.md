# 每餐

简单记录每一餐、每日热量与体重趋势的 Flutter 应用。

## 功能

- 按早餐、午餐、晚餐、加餐记录食物与克数，自动计算热量
- 内置常见食物库，也支持自定义食物
- 拍照识别食物清单，识别结果可逐项修改，也可继续对话调整
- 根据身体数据计算 BMR / TDEE 与每日热量缺口
- 记录体重，并按近期缺口预测到达目标体重的日期
- CSV / PDF 导出、kJ 与 kcal 换算
- 纯黑、原生 iOS 风格的界面与页面动效

## 本地运行

```bash
flutter pub get
flutter run
```

检查与测试：

```bash
dart format lib test
dart analyze lib test
flutter test
```

## API Key 与照片

在「我的 → API Key」中填入自己的 Key。Key 只保存在本机，不会写入日志，也不会上传到其他服务；照片只在识别时发送到所配置的识别接口。

网页预览受浏览器跨域限制，拍照识别请在 iOS / Android / 桌面 App 中使用。

## Codemagic 构建

仓库根目录的 `codemagic.yaml` 包含三个工作流：

| 工作流 | 说明 |
| --- | --- |
| `ios-simulator-preview` | 无需签名，构建 iOS 模拟器版本，产出 `MeiCan-iOS-Simulator.zip` |
| `ios-release` | 构建签名 IPA，需在 Codemagic 中配置 App Store 签名 |
| `android-release` | 构建 Android Release APK |

iOS 正式包要求：

1. 在 Codemagic 中把本仓库添加为应用
2. 在 Team settings → Code signing identities 中上传 iOS 证书与描述文件，或在 App Store Connect 集成中配置 API Key
3. Bundle ID 为 `com.neilsondou.meican`
4. 选择 `ios-release` 工作流开始构建，产物为 `build/ios/ipa/*.ipa`

签名未配置前，可先选择 `ios-simulator-preview` 验证 iOS 编译。
