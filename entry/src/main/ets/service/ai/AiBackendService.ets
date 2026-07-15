import { http } from '@kit.NetworkKit';

export enum AiModelMode {
  LOCAL_FREE = 'LOCAL_FREE',
  BACKEND_API = 'BACKEND_API'
}

export interface AiReply {
  text: string;
  provider: string;
  steps: Array<string>;
}

interface BackendReply {
  answer?: string;
  provider?: string;
  steps?: Array<string>;
}

/**
 * 零费用、离线可运行的轻量开发诊断模型。
 * 它不是伪装成大语言模型，而是将本项目规则库、意图路由和报告模板组合为一个端侧 Mini 模型。
 */
export class DevAssistMiniModel {
  infer(prompt: string, agentMode: boolean): AiReply {
    const input = prompt.trim();
    const lower = input.toLowerCase();
    let answer = '建议按“现象确认 → 最小复现 → 定位首个错误 → 修复后回归”的顺序处理。';
    let steps: Array<string> = ['补充完整错误上下文', '定位第一条根因错误', '执行最小修改并重新构建'];

    if (lower.includes('ohpm') || lower.includes('not found') || lower.includes('package')) {
      answer = '这是典型的依赖版本或仓库同步问题。先核对 oh-package.json5，再检查 registry 与锁文件。';
      steps = ['核对依赖名和版本是否真实存在', '确认 OHPM registry 配置', '清理 oh_modules 与锁文件后重新安装'];
    } else if (lower.includes('arkts') || lower.includes('type') || lower.includes('compile')) {
      answer = '优先修复编译器输出中的第一条 ArkTS 类型错误，后续错误往往是连锁结果。';
      steps = ['为状态和回调补充明确类型', '检查组件参数与可空值', '重新执行 CompileArkTS'];
    } else if (lower.includes('permission') || lower.includes('权限')) {
      answer = '权限问题需要同时检查 module.json5 声明、运行时授权和用户拒绝后的降级路径。';
      steps = ['检查 requestPermissions 声明', '请求用户授权并处理返回值', '在拒绝时提供可用的降级功能'];
    } else if (lower.includes('json')) {
      answer = '可以先用 JSON Formatter Skill 校验语法，再定位字段类型和层级。';
      steps = ['解析 JSON', '格式化并定位语法位置', '按接口契约检查字段类型'];
    }

    if (agentMode) {
      return {
        text: `DevAssist Agent 已完成任务规划：${answer}`,
        provider: 'DevAssist Mini · Free Local Agent',
        steps: ['Planner：识别目标与约束', 'Skill Router：选择诊断能力', ...steps, 'Verifier：输出可验证结论']
      };
    }
    return { text: answer, provider: 'DevAssist Mini · Free Local Model', steps: steps };
  }
}

export class AiBackendService {
  private endpoint: string = 'http://10.0.2.2:8787';
  private localModel: DevAssistMiniModel = new DevAssistMiniModel();

  setEndpoint(endpoint: string): void {
    const normalized = endpoint.trim().replace(/\/$/, '');
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      this.endpoint = normalized;
    }
  }

  getEndpoint(): string {
    return this.endpoint;
  }

  chat(prompt: string, modelMode: AiModelMode): Promise<AiReply> {
    if (modelMode === AiModelMode.LOCAL_FREE) {
      return Promise.resolve(this.localModel.infer(prompt, false));
    }
    return this.call('/api/chat', prompt, false);
  }

  runAgent(prompt: string, modelMode: AiModelMode): Promise<AiReply> {
    if (modelMode === AiModelMode.LOCAL_FREE) {
      return Promise.resolve(this.localModel.infer(prompt, true));
    }
    return this.call('/api/agent/run', prompt, true);
  }

  async healthCheck(): Promise<boolean> {
    const client = http.createHttp();
    try {
      const response = await client.request(`${this.endpoint}/health`, {
        method: http.RequestMethod.GET,
        connectTimeout: 1500,
        readTimeout: 2500
      });
      return response.responseCode === 200;
    } catch (_) {
      return false;
    } finally {
      client.destroy();
    }
  }

  private async call(path: string, prompt: string, agentMode: boolean): Promise<AiReply> {
    const client = http.createHttp();
    try {
      const response = await client.request(`${this.endpoint}${path}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ prompt: prompt }),
        connectTimeout: 1800,
        readTimeout: 5000
      });
      if (response.responseCode >= 200 && response.responseCode < 300 && typeof response.result === 'string') {
        const parsed = JSON.parse(response.result) as BackendReply;
        return {
          text: parsed.answer ?? 'API 已响应，但没有返回文本。',
          provider: parsed.provider ?? 'Developer Assistant API',
          steps: parsed.steps ?? []
        };
      }
    } catch (_) {
      // API 不可达时必须保证课堂演示仍可继续。
    } finally {
      client.destroy();
    }
    const fallback = this.localModel.infer(prompt, agentMode);
    return {
      text: `${fallback.text}\n\n在线 API 当前不可达，已自动切换到免费端侧模型。`,
      provider: `${fallback.provider} · API Fallback`,
      steps: fallback.steps
    };
  }
}

export const aiBackendService: AiBackendService = new AiBackendService();
