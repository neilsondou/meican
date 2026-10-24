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

仓库根目录的 `codemagic.yaml` 包含两个工作流：

| 工作流 | 说明 |
| --- | --- |
| `ios-unsigned` | 无需 Apple 签名，构建真机 Release，产出未签名 `MeiCan-iOS-unsigned.ipa` |
| `android-release` | 构建 Android Release APK |

iOS 自签安装：

1. 在 Codemagic 中把本仓库添加为应用，并选择使用仓库里的 `codemagic.yaml`
2. 选择 `ios-unsigned` 工作流，开始构建
3. 从 Artifacts 下载 `MeiCan-iOS-unsigned.ipa`
4. 用 AltStore、Sideloadly 或你自己的证书签名后安装到 iPhone

Codemagic 只负责产出未签名 IPA，不需要配置 Apple 开发者证书或描述文件；IPA 必须先自签才能安装。
