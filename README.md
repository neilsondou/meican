# 每餐

简单记录每一餐、每日热量与体重趋势的 Flutter 应用。

## 功能

- 按早餐、午餐、晚餐、加餐记录食物与克数，自动计算热量
- 内置常见食物库，也支持自定义食物
- 拍照识别食物清单，识别结果可逐项修改
- 识别后可点「和ai犟嘴（我没吃这么多）」，补充实际分量，让 AI 重算整份清单
- 已保存的餐次可以编辑餐型、食物、克数和备注
- 根据身体数据计算 BMR / TDEE 与每日热量缺口
- 记录或补录任意一天的体重，同一天只保留一条，也可以修改历史记录
- 按身高、年龄、性别和当前体重估算体脂率，并在趋势页展示体脂变化
- 从备忘录、健康 App 等截图识别体重记录，核对日期、单位后批量导入
- 公斤 / 市斤显示单位可全局切换（1 公斤 = 2 市斤），已有数据自动换算
- 私有云同步：启动、回到前台和每次修改后自动同步，手机上照常离线使用
- 网页首次进入会提示下载 iOS / Android 安装包，也可以添加到主屏幕
- CSV / PDF 导出、kJ 与 kcal 换算
- 纯黑、原生 iOS 风格的界面与页面动效

## 本地运行

AI 识别使用内置的 ChatGLM 免费测试密钥（`lib/ai_keys.dart`），原生端直连
`open.bigmodel.cn`，不经过任何自建服务：

```bash
flutter pub get
flutter run
```

需要换密钥时用 `--dart-define=MEICAN_AI_KEYS="key1,key2,key3,key4"` 覆盖。多个密钥可用逗号、分号或换行分隔；每次请求会随机轮转使用，遇到限流或失效时自动尝试下一把。

检查与测试：

```bash
dart format lib test
dart analyze lib test
flutter test
```

## AI 识别与照片

- iOS / Android 直连 ChatGLM，内置四个测试密钥随机轮转，不依赖云同步或自建服务器。
- 浏览器不允许跨域直连 ChatGLM（预检请求没有 CORS 头），所以网页版经同源 `/api/ai` 原样转发到 ChatGLM；这个转发不需要登录、不保存图片，匿名请求按 IP 限流。
- 拍照识别是本地功能，不依赖云同步；云同步只负责在后台备份和合并记录。
- 照片只在识别时发送到所配置的 AI 服务，不上传到其他服务，也不写入日志。

## 云同步

- 入口只在「我的 → 云同步」，登录后自动同步，无需手动保存；不登录也能使用全部本地功能。
- 本地数据照常读写：每次修改先落到本机，再在后台合并上传，网络失败不影响使用。体重单位偏好也会随资料一起同步。
- 多设备按每条记录的更新时间、删除标记和资料更新时间合并，冲突时以较新的版本为准。
- 服务端是 Vercel Serverless + Neon Postgres，代码在 `meican-web` 仓库的 `api/` 与 `lib/cloud-server.js`，从建库到初始化账号见 [meican-web README](https://github.com/neilsondou/meican-web#云同步部署vercel--neon)。
- 登录状态、同步结果和最近日志都显示在云同步面板中；日志不记录密码、Token 或图片内容。
- 云同步是私人服务，账号由 Vercel 环境变量 `MEICAN_USERS` 初始化，不在仓库中保存明文密码。

网页版构建（不要在网页构建里传 `MEICAN_AI_KEYS`）：

```bash
flutter build web --release --no-web-resources-cdn
```

网页端云同步与 AI 代理都走同源 `/api/...`，不需要再传 `MEICAN_API_BASE`。原生 App 默认使用 `https://meican.dou.asia`，需要换域名时再传 `--dart-define=MEICAN_API_BASE=...`。

`--no-web-resources-cdn` 会让网页从同域的 `canvaskit/` 加载 CanvasKit，而不是每次去 `gstatic` 下载约 6 MB 的引擎文件。中文字体 `MeicanSans` 不再写进 `FontManifest`（Flutter 会在首帧前阻塞下载全部字体），而是启动时由 `FontLoader` 从 jsDelivr 国内镜像加载 WOFF2，失败再回退到打包字体。

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
