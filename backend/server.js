'use strict';

const http = require('http');

const port = Number(process.env.PORT || 8787);

function classify(prompt) {
  const text = String(prompt || '').toLowerCase();
  if (text.includes('ohpm') || text.includes('package') || text.includes('not found')) {
    return {
      answer: '依赖诊断：核对包名和版本，确认 OHPM registry，再清理缓存与锁文件后重新安装。',
      steps: ['检查 oh-package.json5', '验证 registry 可访问', '重新执行 ohpm install']
    };
  }
  if (text.includes('arkts') || text.includes('compile') || text.includes('类型')) {
    return {
      answer: 'ArkTS 诊断：先修复 CompileArkTS 输出中的第一条类型错误，再处理连锁错误。',
      steps: ['定位第一条错误', '补全明确类型与空值处理', '重新构建并回归']
    };
  }
  if (text.includes('permission') || text.includes('权限')) {
    return {
      answer: '权限诊断：检查 module.json5 声明、运行时授权结果以及拒绝授权后的降级路径。',
      steps: ['核对权限声明', '处理授权结果', '验证拒绝后的可用性']
    };
  }
  return {
    answer: '建议按“复现现象、保留首个错误、缩小范围、最小修复、回归验证”的顺序排查。',
    steps: ['补充完整日志', '构造最小复现', '修改并重新验证']
  };
}

function json(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payload),
    'Access-Control-Allow-Origin': '*'
  });
  res.end(payload);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 1024 * 1024) req.destroy();
    });
    req.on('end', () => {
      try { resolve(body ? JSON.parse(body) : {}); } catch (error) { reject(error); }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    return json(res, 200, { status: 'ok', provider: 'DevAssist Demo API', model: 'free-rule-model-v1' });
  }
  if (req.method === 'GET' && req.url === '/api/models') {
    return json(res, 200, { models: [{ id: 'free-rule-model-v1', price: 0, offlineFallback: true }] });
  }
  if (req.method === 'POST' && (req.url === '/api/chat' || req.url === '/api/agent/run')) {
    try {
      const body = await readBody(req);
      const result = classify(body.prompt);
      const agent = req.url.endsWith('/agent/run');
      return json(res, 200, {
        answer: agent ? `Agent 已完成规划与 Skill 调用：${result.answer}` : result.answer,
        provider: agent ? 'DevAssist Demo Agent API' : 'DevAssist Demo Chat API',
        steps: agent ? ['Planner', 'Skill Router', ...result.steps, 'Verifier'] : result.steps
      });
    } catch (_) {
      return json(res, 400, { error: 'invalid_json' });
    }
  }
  if (req.method === 'POST' && req.url === '/api/vision/analyze') {
    return json(res, 200, {
      answer: '视觉识别由 HarmonyOS Core Vision Kit 在设备端完成，本接口只接收脱敏后的文本结果。',
      provider: 'Privacy-safe Vision Gateway'
    });
  }
  return json(res, 404, { error: 'not_found' });
});

if (require.main === module) {
  server.listen(port, '0.0.0.0', () => console.log(`DevAssist API listening on http://0.0.0.0:${port}`));
}

module.exports = { server, classify };
