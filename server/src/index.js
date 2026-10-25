const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const LOGIN_WINDOW_MS = 15 * 60 * 1000;
const MAX_LOGIN_FAILURES = 10;
// Workers 免费版 CPU 时间有限，登录与首次建号都要做哈希，因此这里取较低轮数。
const PBKDF2_ITERATIONS = 12000;
const MAX_LOGIN_BYTES = 4096;
const MAX_SYNC_BYTES = 2_000_000;
const MAX_AI_BYTES = 12_000_000;
const AI_ENDPOINT = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const AI_MODEL = 'glm-4v-flash';
const DUMMY_SALT = 'bWVpY2FuLWR1bW15LXNhbHQ=';

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const headers = corsHeaders(origin, env);
    if (request.method === 'OPTIONS') {
      if (headers === null) return new Response(null, { status: 403 });
      return new Response(null, { status: 204, headers });
    }
    if (headers === null) {
      return json({ error: '此来源未被允许。' }, 403, {});
    }

    try {
      const url = new URL(request.url);
      const path = url.pathname.replace(/\/+$/, '') || '/';
      const method = request.method;

      if (path === '/api/health' && method === 'GET') {
        return json({ ok: true, time: new Date().toISOString() }, 200, headers);
      }
      if (path === '/api/login' && method === 'POST') {
        return await handleLogin(request, env, headers);
      }
      if (path === '/api/logout' && method === 'POST') {
        return await handleLogout(request, env, headers);
      }
      if (path === '/api/me' && method === 'GET') {
        return await handleMe(request, env, headers);
      }
      if (path === '/api/sync' && method === 'GET') {
        return await handleSyncGet(request, env, headers);
      }
      if (path === '/api/sync' && method === 'PUT') {
        return await handleSyncPut(request, env, headers);
      }
      if (path === '/api/ai/analyze' && method === 'POST') {
        return await handleAnalyze(request, env, headers);
      }
      throw new HttpError(404, '接口不存在。');
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: error.message }, error.status, headers);
      }
      console.error('Unhandled server error:', error);
      return json({ error: '服务器内部错误，请稍后重试。' }, 500, headers);
    }
  },
};

function corsHeaders(origin, env) {
  if (!origin) return {};
  if (!isAllowedOrigin(origin, env)) return null;
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function isAllowedOrigin(origin, env) {
  if (origin === 'https://meican.dou.asia') return true;
  const extra = (env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  if (extra.includes(origin)) return true;
  try {
    const parsed = new URL(origin);
    if (
      parsed.protocol === 'http:' &&
      (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1')
    ) {
      return true;
    }
    if (
      parsed.protocol === 'https:' &&
      parsed.hostname.endsWith('.vercel.app')
    ) {
      return true;
    }
  } catch {
    return false;
  }
  return false;
}

function json(data, status, headers) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...headers,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function providerResponse(text, status, headers) {
  return new Response(text, {
    status,
    headers: {
      ...headers,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

async function readJson(request, maxBytes) {
  const declared = Number(request.headers.get('Content-Length') || 0);
  if (declared > maxBytes) throw new HttpError(413, '请求内容过大。');
  const raw = await request.text();
  if (new TextEncoder().encode(raw).length > maxBytes) {
    throw new HttpError(413, '请求内容过大。');
  }
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('not object');
    }
    return parsed;
  } catch {
    throw new HttpError(400, '请求格式不正确。');
  }
}

async function ensureBootstrap(env) {
  const count = await env.DB.prepare('SELECT COUNT(*) AS total FROM users').first();
  if (count && Number(count.total) > 0) return;

  const raw = (env.BOOTSTRAP_USERS || '').trim();
  if (!raw) {
    throw new HttpError(
      503,
      '服务器尚未创建账号，请设置 BOOTSTRAP_USERS 后重试。',
    );
  }

  for (const pair of raw.split(',')) {
    const separator = pair.indexOf(':');
    if (separator <= 0) continue;
    const username = pair.slice(0, separator).trim();
    const password = pair.slice(separator + 1);
    if (!username || !password) continue;
    const salt = bytesToBase64(crypto.getRandomValues(new Uint8Array(16)));
    const hash = await hashPassword(password, salt, PBKDF2_ITERATIONS);
    await env.DB.prepare(
      'INSERT OR IGNORE INTO users (id, username, password_hash, salt, iterations, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    )
      .bind(
        crypto.randomUUID(),
        username,
        hash,
        salt,
        PBKDF2_ITERATIONS,
        new Date().toISOString(),
      )
      .run();
  }

  const after = await env.DB.prepare('SELECT COUNT(*) AS total FROM users').first();
  if (!after || Number(after.total) === 0) {
    throw new HttpError(
      503,
      '服务器尚未创建账号，请检查 BOOTSTRAP_USERS 格式。',
    );
  }
}

async function handleLogin(request, env, headers) {
  await ensureBootstrap(env);
  const body = await readJson(request, MAX_LOGIN_BYTES);
  const username = typeof body.username === 'string' ? body.username.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (!username || !password || username.length > 64 || password.length > 200) {
    throw new HttpError(400, '请输入有效的账号和密码。');
  }

  const ip = request.headers.get('CF-Connecting-IP') || 'local';
  if (await isLoginBlocked(env, ip)) {
    throw new HttpError(429, '尝试次数过多，请 15 分钟后再试。');
  }

  const user = await env.DB.prepare(
    'SELECT id, username, password_hash, salt, iterations FROM users WHERE username = ?',
  )
    .bind(username)
    .first();

  let valid = false;
  if (user) {
    const candidate = await hashPassword(password, user.salt, user.iterations);
    valid = timingSafeEqual(candidate, user.password_hash);
  } else {
    await hashPassword(password, DUMMY_SALT, PBKDF2_ITERATIONS);
  }
  if (!valid) {
    await recordLoginFailure(env, ip);
    throw new HttpError(401, '账号或密码不正确。');
  }
  await clearLoginFailures(env, ip);

  const token = bytesToBase64Url(crypto.getRandomValues(new Uint8Array(32)));
  const tokenHash = await sha256Hex(token);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_MS);
  await env.DB.batch([
    env.DB.prepare('DELETE FROM sessions WHERE expires_at <= ?').bind(
      now.toISOString(),
    ),
    env.DB.prepare(
      'INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)',
    ).bind(
      tokenHash,
      user.id,
      now.toISOString(),
      expiresAt.toISOString(),
    ),
  ]);

  return json(
    {
      token,
      username: user.username,
      expiresAt: expiresAt.toISOString(),
    },
    200,
    headers,
  );
}

async function handleLogout(request, env, headers) {
  const user = await authenticate(request, env);
  if (!user) throw new HttpError(401, '登录已过期，请重新登录。');
  await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?')
    .bind(user.tokenHash)
    .run();
  return json({ ok: true }, 200, headers);
}

async function handleMe(request, env, headers) {
  const user = await authenticate(request, env);
  if (!user) throw new HttpError(401, '登录已过期，请重新登录。');
  return json({ username: user.username }, 200, headers);
}

async function handleSyncGet(request, env, headers) {
  const user = await authenticate(request, env);
  if (!user) throw new HttpError(401, '登录已过期，请重新登录。');
  const row = await env.DB.prepare(
    'SELECT revision, data, updated_at FROM sync_state WHERE user_id = ?',
  )
    .bind(user.userId)
    .first();
  if (!row) {
    return json({ revision: 0, data: null, updatedAt: null }, 200, headers);
  }
  let data;
  try {
    data = JSON.parse(row.data);
  } catch {
    throw new HttpError(500, '云端数据损坏，请联系作者。');
  }
  return json(
    {
      revision: Number(row.revision),
      data,
      updatedAt: row.updated_at,
    },
    200,
    headers,
  );
}

async function handleSyncPut(request, env, headers) {
  const user = await authenticate(request, env);
  if (!user) throw new HttpError(401, '登录已过期，请重新登录。');

  const body = await readJson(request, MAX_SYNC_BYTES);
  const baseRevision = Number(body.baseRevision);
  if (!Number.isInteger(baseRevision) || baseRevision < 0) {
    throw new HttpError(400, '同步版本号无效。');
  }
  const data = body.data;
  if (!isSyncSnapshot(data)) {
    throw new HttpError(400, '同步数据格式不正确。');
  }

  const currentRow = await env.DB.prepare(
    'SELECT revision, data, updated_at FROM sync_state WHERE user_id = ?',
  )
    .bind(user.userId)
    .first();
  const currentRevision = currentRow ? Number(currentRow.revision) : 0;
  if (baseRevision !== currentRevision) {
    return syncConflict(env, user, headers);
  }

  const payload = JSON.stringify(data);
  const nextRevision = currentRevision + 1;
  const updatedAt = new Date().toISOString();
  const result = currentRow
    ? await env.DB.prepare(
        'UPDATE sync_state SET revision = ?, data = ?, updated_at = ? WHERE user_id = ? AND revision = ?',
      )
        .bind(nextRevision, payload, updatedAt, user.userId, currentRevision)
        .run()
    : await env.DB.prepare(
        'INSERT OR IGNORE INTO sync_state (user_id, revision, data, updated_at) VALUES (?, ?, ?, ?)',
      )
        .bind(user.userId, nextRevision, payload, updatedAt)
        .run();

  if (!result.meta || Number(result.meta.changes) === 0) {
    return syncConflict(env, user, headers);
  }
  return json({ revision: nextRevision, updatedAt }, 200, headers);
}

async function syncConflict(env, user, headers) {
  const row = await env.DB.prepare(
    'SELECT revision, data, updated_at FROM sync_state WHERE user_id = ?',
  )
    .bind(user.userId)
    .first();
  let data = null;
  if (row) {
    try {
      data = JSON.parse(row.data);
    } catch {
      data = null;
    }
  }
  return json(
    {
      error: '云端数据已更新，请合并后重试。',
      revision: row ? Number(row.revision) : 0,
      data,
      updatedAt: row ? row.updated_at : null,
    },
    409,
    headers,
  );
}

async function handleAnalyze(request, env, headers) {
  const user = await authenticate(request, env);
  if (!user) throw new HttpError(401, '登录已过期，请重新登录。');

  const body = await readJson(request, MAX_AI_BYTES);
  if (!isValidMessages(body.messages)) {
    throw new HttpError(400, '识别请求格式不正确。');
  }

  const keys = (env.AI_KEYS || '')
    .split(',')
    .map((key) => key.trim())
    .filter(Boolean);
  if (keys.length === 0) {
    throw new HttpError(503, '服务器尚未配置图片识别服务。');
  }

  const payload = JSON.stringify({
    model: AI_MODEL,
    messages: body.messages,
  });
  const order = rotate(keys);
  let lastStatus = 0;

  for (const key of order) {
    let response;
    try {
      response = await fetch(AI_ENDPOINT, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${key}`,
          'Content-Type': 'application/json',
        },
        body: payload,
        signal: AbortSignal.timeout(65000),
      });
    } catch {
      lastStatus = 0;
      continue;
    }

    const text = await response.text();
    if (response.ok) {
      return providerResponse(text, 200, headers);
    }
    lastStatus = response.status;
    if (
      response.status !== 401 &&
      response.status !== 403 &&
      response.status !== 408 &&
      response.status !== 429 &&
      response.status < 500
    ) {
      return json(
        { error: `识别服务请求失败（HTTP ${response.status}）。` },
        502,
        headers,
      );
    }
  }

  if (lastStatus === 429) {
    throw new HttpError(429, '图片识别服务当前请求较多，请稍后重试。');
  }
  throw new HttpError(503, '图片识别服务暂时不可用，请稍后重试。');
}

function isValidMessages(messages) {
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > 8) {
    return false;
  }
  let hasImage = false;
  for (const message of messages) {
    if (!message || (message.role !== 'system' && message.role !== 'user')) {
      return false;
    }
    if (typeof message.content === 'string') continue;
    if (!Array.isArray(message.content)) return false;
    for (const part of message.content) {
      if (!part || typeof part !== 'object') return false;
      if (part.type === 'text') {
        if (typeof part.text !== 'string' || part.text.length > 8000) {
          return false;
        }
      } else if (part.type === 'image_url') {
        const url = part.image_url && part.image_url.url;
        if (
          typeof url !== 'string' ||
          !/^data:image\/(jpeg|jpg|png|webp);base64,/.test(url)
        ) {
          return false;
        }
        if (url.length > MAX_AI_BYTES) return false;
        hasImage = true;
      } else {
        return false;
      }
    }
  }
  return hasImage;
}

async function authenticate(request, env) {
  const header = request.headers.get('Authorization') || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) return null;
  const tokenHash = await sha256Hex(match[1].trim());
  const row = await env.DB.prepare(
    'SELECT sessions.user_id AS userId, sessions.expires_at AS expiresAt, users.username AS username FROM sessions JOIN users ON users.id = sessions.user_id WHERE sessions.token_hash = ?',
  )
    .bind(tokenHash)
    .first();
  if (!row) return null;
  if (Date.parse(row.expiresAt) <= Date.now()) {
    await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?')
      .bind(tokenHash)
      .run();
    return null;
  }
  return { userId: row.userId, username: row.username, tokenHash };
}

async function isLoginBlocked(env, ip) {
  const row = await env.DB.prepare(
    'SELECT failures, window_start FROM login_guards WHERE ip = ?',
  )
    .bind(ip)
    .first();
  if (!row) return false;
  if (Date.now() - Date.parse(row.window_start) > LOGIN_WINDOW_MS) {
    await env.DB.prepare('DELETE FROM login_guards WHERE ip = ?').bind(ip).run();
    return false;
  }
  return Number(row.failures) >= MAX_LOGIN_FAILURES;
}

async function recordLoginFailure(env, ip) {
  const now = new Date();
  const row = await env.DB.prepare(
    'SELECT failures, window_start FROM login_guards WHERE ip = ?',
  )
    .bind(ip)
    .first();
  if (!row || Date.now() - Date.parse(row.window_start) > LOGIN_WINDOW_MS) {
    await env.DB.prepare(
      'INSERT INTO login_guards (ip, failures, window_start) VALUES (?, 1, ?) ON CONFLICT(ip) DO UPDATE SET failures = 1, window_start = excluded.window_start',
    )
      .bind(ip, now.toISOString())
      .run();
    return;
  }
  await env.DB.prepare(
    'UPDATE login_guards SET failures = failures + 1 WHERE ip = ?',
  )
    .bind(ip)
    .run();
}

async function clearLoginFailures(env, ip) {
  await env.DB.prepare('DELETE FROM login_guards WHERE ip = ?').bind(ip).run();
}

function isSyncSnapshot(data) {
  return (
    data &&
    typeof data === 'object' &&
    !Array.isArray(data) &&
    data.version === 1 &&
    Array.isArray(data.meals) &&
    Array.isArray(data.weights) &&
    data.profile &&
    typeof data.profile === 'object'
  );
}

async function hashPassword(password, saltBase64, iterations) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      salt: base64ToBytes(saltBase64),
      iterations: Number(iterations) || PBKDF2_ITERATIONS,
    },
    key,
    256,
  );
  return bytesToBase64(new Uint8Array(bits));
}

async function sha256Hex(value) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function timingSafeEqual(first, second) {
  if (
    typeof first !== 'string' ||
    typeof second !== 'string' ||
    first.length !== second.length
  ) {
    return false;
  }
  let difference = 0;
  for (let index = 0; index < first.length; index += 1) {
    difference |= first.charCodeAt(index) ^ second.charCodeAt(index);
  }
  return difference === 0;
}

function bytesToBase64(bytes) {
  let binary = '';
  for (let index = 0; index < bytes.length; index += 1) {
    binary += String.fromCharCode(bytes[index]);
  }
  return btoa(binary);
}

function bytesToBase64Url(bytes) {
  return bytesToBase64(bytes)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function base64ToBytes(value) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function rotate(items) {
  const random = crypto.getRandomValues(new Uint32Array(1))[0] % items.length;
  return [...items.slice(random), ...items.slice(0, random)];
}
