# Tsinghua DeepSeek for DSH Desktop

把清华 DeepSeek 服务（`madmodel.cs.tsinghua.edu.cn`）接入 DSH Desktop 的配置，
以及每 24 小时更换 token 的维护流程。

## 两份文档

| 文件 | 给谁看 | 内容 |
|---|---|---|
| [SETUP.md](SETUP.md) | **人** | 中文。先看第 0 节"配置逻辑总览"，再按步骤操作。 |
| [AGENT_NOTES.md](AGENT_NOTES.md) | **Agent** | 英文。完整配置记录：工作流程、根因分析、踩过的坑、验证方法、迁移说明。 |

## 最关键的一点

token 每 24 小时过期一次。**新 token 粘贴到一个纯文本文件里，不是粘到配置文件里：**

```
tsinghua_token.txt   →   Sync-TsinghuaToken.ps1   →   <harness home>/.credentials.yaml
    （你粘贴到这儿）        （校验格式与有效期后写入）        （DSH 每次请求时读取）
```

```
.\Sync-TsinghuaToken.ps1
```

不需要重启应用，不需要改配置文件。

## 文件说明

| 文件 | 作用 |
|---|---|
| `Sync-TsinghuaToken.ps1` | 校验 token 并写入 DSH 凭据库。保留其他凭据条目，写入前自动备份，**不打印 token**，写完回读按指纹校验。 |
| `cordis.patch.yml.example` | 完整的 profile 配置文件。复制到 `<harness home>/profiles/desktop/cordis.patch.yml`。 |
| `tsinghua_token.txt.placeholder` | 示范 token 文件该有的格式。 |

## 配置结果

| 项目 | 值 |
|---|---|
| 模型选择器里的名字 | `Tsinghua_DeepSeek_v41`（分组 **Tsinghua DeepSeek**） |
| 上下文窗口 | 1,048,576 token（实测值） |
| 输出预留 | 131,072 token |
| 思考档位 | Off / Low / High / Max |
| 工具调用 | 支持（流式与非流式） |
| 图像输入 | 支持，能正确识别图像内容（每张约 1000 token） |

## 安全

配置文件里不含任何密钥，可以放心分享、提交、迁移到别的电脑。
token 是你校园账号的 24 小时凭据，只放在 token 文件和凭据库里。
详见 SETUP.md 第 7 节。
