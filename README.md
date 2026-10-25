# 每餐

简单记录每一餐、每日热量与体重趋势的 Flutter 应用。

## 功能

- 按早餐、午餐、晚餐、加餐记录食物与克数，自动计算热量
- 内置常见食物库，也支持自定义食物
- 拍照识别食物清单，识别结果可逐项修改
- 识别后可点「和ai犟嘴（我没吃这么多）」，补充实际分量，让 AI 重算整份清单
- 已保存的餐次可以编辑餐型、食物、克数和备注
- 根据身体数据计算 BMR / TDEE 与每日热量缺口
- 记录体重，并按近期缺口预测到达目标体重的日期
- 私有云同步：启动、回到前台和每次修改后自动同步，手机上照常离线使用
- CSV / PDF 导出、kJ 与 kcal 换算
- 纯黑、原生 iOS 风格的界面与页面动效

## 本地运行

AI 识别密钥只在构建时注入，不写入仓库：

```bash
flutter pub get
flutter run --dart-define=MEICAN_AI_KEYS="key1,key2,key3,key4"
```

不传这个参数也能启动，但拍照识别会提示服务未启用。多个密钥可用逗号、分号或换行分隔；每次请求会随机轮转使用，遇到限流或失效时自动尝试下一把。

检查与测试：

```bash
dart format lib test
dart analyze lib test
flutter test
```

## AI 识别与照片

- iOS / Android 安装包不填 API Key，密钥在构建时注入，随机轮转使用。
- 网页版不包含任何 AI 密钥；登录云同步后，照片经自己的 Cloudflare Worker 转发到 AI 服务，跨域请求由 Worker 处理。
- 照片只在识别时发送到所配置的 AI 服务，不上传到其他服务，也不写入日志。

## 云同步

- 入口只在「我的 → 云同步」，登录后自动同步，无需手动保存。
- 本地数据照常读写：每次修改先落到本机，再在后台合并上传，网络失败不影响使用。
- 多设备按每条记录的更新时间、删除标记和资料更新时间合并，冲突时以较新的版本为准。
- 服务端是 Cloudflare Worker + D1，代码在 `server/`，从建库到绑定域名见 [server/README.md](server/README.md)。
- 登录状态、同步结果和最近日志都显示在云同步面板中；日志不记录密码、Token 或图片内容。
- 云同步是私人服务，账号由服务端 Secret 初始化，不在仓库中保存明文密码。

网页版构建（不要在网页构建里传 `MEICAN_AI_KEYS`）：

```bash
flutter build web --release \
  --dart-define=MEICAN_API_BASE=https://api.meican.dou.asia
```

构建产物在 `build/web`。部署到 Vercel 的步骤见 `meican-web` 仓库的 README；也可把 `build/web` 放到任意静态托管。

## Codemagic 构建

仓库根目录的 `codemagic.yaml` 包含两个工作流：

| 工作流 | 说明 |
| --- | --- |
| `ios-unsigned` | 无需 Apple 签名，构建真机 Release，产出未签名 `MeiCan-iOS-unsigned.ipa` |
| `android-release` | 构建 Android Release APK |

### 配置内置识别密钥

1. 在 Codemagic 中把本仓库添加为应用，并选择使用仓库里的 `codemagic.yaml`
2. 打开应用设置里的 Environment variables，新增 `MEICAN_AI_KEYS`，勾选 Secure
3. 值填多个密钥，用逗号分隔，例如 `key1,key2,key3,key4`
4. 重新触发构建；工作流会检查该变量，缺失时直接给出提示并停止

### iOS 自签安装

1. 选择 `ios-unsigned` 工作流，开始构建
2. 从 Artifacts 下载 `MeiCan-iOS-unsigned.ipa`
3. 用 AltStore、Sideloadly 或你自己的证书签名后安装到 iPhone

Codemagic 只负责产出未签名 IPA，不需要配置 Apple 开发者证书或描述文件；IPA 必须先自签才能安装。
