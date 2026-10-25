# 每餐云端服务（Cloudflare Worker + D1）

这个 Worker 提供三件事：

- 两个私人账号的登录与会话（可选，仅用于云同步）
- 全量快照同步（带版本号，冲突时由客户端合并后重试）
- 网页端的 AI 图片识别代理（密钥只放在 Worker 的 Secret 中，匿名可用但按 IP 限流）

客户端默认访问 `https://api.meican.dou.asia`。下面每一步都在 `server/` 目录执行。

## 1. 安装与登录

```bash
cd server
npm install
npx wrangler login
```

浏览器会打开 Cloudflare 授权页面。

## 2. 创建 D1 数据库

```bash
npx wrangler d1 create meican
```

命令会输出一段 TOML，把其中的 `database_id` 填进 `wrangler.toml`（文件里现在是全零占位符）：

```toml
[[d1_databases]]
binding = "DB"
database_name = "meican"
database_id = "这里填命令输出的 ID"
```

然后建表：

```bash
npx wrangler d1 execute meican --remote --file=schema.sql
```

`ai_usage` 表用于网页端匿名识别的每小时限额。Worker 在没有这张表时也会自动创建一次；如果你更新了旧库，重新执行上面的 schema 命令或访问一次识别接口即可。

## 3. 写入两个账号

```bash
npx wrangler secret put BOOTSTRAP_USERS
```

粘贴一行，格式为 `账号:密码,账号:密码`。按你指定的两组账号密码填写即可。

- 只会在 `users` 表为空、且第一次有人登录时自动建号。
- 密码会加随机盐后用 PBKDF2 哈希保存，不会以明文写入数据库。
- 不要把这张 Secret 写进仓库或发到公开渠道。

## 4. 写入 AI 密钥

```bash
npx wrangler secret put AI_KEYS
```

粘贴四个密钥，用英文逗号分隔。密钥只保存在 Cloudflare Secret 中，不会进入网页包，也不会出现在客户端日志里。

这四个密钥此前已经在聊天中出现过，建议到图片识别服务后台重新生成后再填入这里。

## 5. 部署

```bash
npx wrangler deploy
```

记下输出里的 `https://meican-api.<你的子域>.workers.dev` 地址。

验证：

```bash
curl https://meican-api.<你的子域>.workers.dev/api/health
```

看到 `{"ok":true,...}` 就说明服务已启动。

## 6. 绑定自定义域名（推荐）

在 Cloudflare 控制台：

1. 进入 **Workers & Pages** → `meican-api`。
2. 打开 **Settings** → **Domains & Routes**。
3. 选择 **Add** → **Custom domain**。
4. 填入 `api.meican.dou.asia`，保存。

前提：`dou.asia` 这个域名已经接入 Cloudflare（Nameserver 在 Cloudflare）。绑定成功后：

```bash
curl https://api.meican.dou.asia/api/health
```

如果暂时不想绑定自定义域名，也可以直接用 `workers.dev` 地址，但构建网页版时要把
`MEICAN_API_BASE` 换成那个地址（见 `meican-web` 仓库说明）。

## 7. 允许的来源

Worker 默认允许：

- `https://meican.dou.asia`
- 任意 `localhost` / `127.0.0.1` 端口（本地调试）
- 任意 `*.vercel.app`（Vercel 预览与生产地址）

如果以后换了域名，可以在 Cloudflare 的 Worker 设置里添加环境变量
`ALLOWED_ORIGINS`，值为逗号分隔的完整来源。App 原生请求没有 `Origin` 头，不受此限制。

## 8. 接口概览

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/health` | 健康检查 |
| POST | `/api/login` | `{username,password}` → `{token}` |
| POST | `/api/logout` | 需要 Bearer Token |
| GET | `/api/sync` | 读取云端快照与版本号 |
| PUT | `/api/sync` | `{baseRevision,data}`，版本不一致返回 409 |
| POST | `/api/ai/analyze` | 转发图片识别；匿名可用，带 Bearer Token 时额度更高 |

同一个账号在多个设备上同时改动时，客户端按每条记录的 `updatedAt`、删除墓碑和资料更新时间合并；合并完成后带最新版本号重新上传。

## 9. 安全说明

- 仓库中没有任何 AI 密钥、账号或密码。
- Token 只保存其 SHA-256 摘要；会话 30 天过期。
- 登录失败按 IP 限制：15 分钟内最多 10 次。
- AI 接口匿名可用，按 IP 限制每小时 20 次；登录用户按账号限制每小时 120 次。
- AI 接口只接受 `data:image/...` 的内嵌图片，且仍然校验允许的来源；其他 Vercel 站点无法直接跨域调用。
- 照片只在转发识别时经过 Worker，不写入 D1，也不记录图片内容。
- 不要把 `.dev.vars`、Secret 导出文件或数据库导出提交到 GitHub。
