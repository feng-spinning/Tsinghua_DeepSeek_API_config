# DSH Desktop 接入清华 DeepSeek：配置与使用说明

## 关于本文

本文说明如何在 DSH Desktop 里使用清华的 DeepSeek 服务
（`madmodel.cs.tsinghua.edu.cn`），以及如何每 24 小时更换一次 token。

本文面向操作的人，用中文写作。写作风格参照 ASD-STE100 简化技术英语的
原则：句子短、一句一个意思、多用主动语态、一个词只表达一个意思。

完整的配置记录、排错过程和技术细节在 [AGENT_NOTES.md](AGENT_NOTES.md)（英文）。

### 先看哪一节

| 你的任务 | 去这一节 |
|---|---|
| 第一次配置（换新电脑做一次） | 第 1 节 |
| 换 token（每 24 小时一次） | 第 2 节 |
| 把配置搬到另一台电脑或别的用户 | 第 3 节 |
| 出问题要修 | 第 6 节 |
| 想知道为什么要这样配 | 第 0 节 |

**注意：** 第 1 节只需做一次。第 2 节每 24 小时做一次。

---

## 第 0 节 配置逻辑总览（先读这一节）

这一节讲清楚"为什么这样配"。看懂这一节，后面的步骤就不会记错。

### 0.1 一句话逻辑

DSH 不认识清华这个端点，所以要给它接一个**翻译器**；
清华的 token 每 24 小时过期，所以要把它**放在门外而不是写进墙里**；
"模型能做什么"不会自动被知道，所以每一项能力都要**先实测、再声明**。

全部配置就是这三件事。

### 0.2 四个东西，各管一件事

| 东西 | 是什么 | 谁写它 | 里面有没有密钥 |
|---|---|---|---|
| `tsinghua_token.txt` | 你放 token 的纯文本文件 | **你手动粘贴** | 有 |
| `.credentials.yaml` | DSH 的凭据库 | **脚本自动写入** | 有 |
| `cordis.patch.yml` | 配置文件（profile） | 你或界面 | **没有**，只有一个名字 |
| 清华端点 | 学校的服务器 | 学校 | — |

### 0.3 数据流：从你粘贴到模型应答

```
① 你从 madmodel 控制台复制 token
        ↓  手动粘贴
② tsinghua_token.txt                    ← 唯一的"人工入口"
        ↓  运行 Sync-TsinghuaToken.ps1（校验格式 + 校验有效期 + 写入）
③ .credentials.yaml 里 refs.TSINGHUA_DEEPSEEK_API_KEY
        ↓  DSH 每次发请求时按名字取用
④ cordis.patch.yml 里的 apiKeyEnv: TSINGHUA_DEEPSEEK_API_KEY
        ↓  发到 https://madmodel.cs.tsinghua.edu.cn/v1
⑤ 清华端点 → 返回模型结果
```

**关键点：配置文件里只写 token 的名字，不写 token 本身。**

### 0.4 为什么 token 要"放在门外"

这里有三层隔离，缺一层都会出问题：

1. **写进配置文件会泄密。** `cordis.patch.yml` 是要分享、要提交到
   GitHub、要复制到别的电脑的。token 一旦写进去，就跟着一起泄露出去了。
2. **写进配置文件也不方便。** token 每 24 小时换一次。如果写在配置文件里，
   每天都要改配置文件、每天都要重启应用。
3. **名字是稳定的，值是易变的。** 配置文件里写
   `apiKeyEnv: TSINGHUA_DEEPSEEK_API_KEY` 这个名字，名字永远不变；
   真正的 token 放在凭据库里，每天换值就行。**配置一次，之后只换值。**

DSH 的凭据库有一个重要特性：**token 是每次发请求时才去取的，不是启动时
读一次就缓存住。** 所以换完 token 不需要重启应用，下一次提问就已经用新
token 了。

### 0.5 为什么"必须声明能力"

**模型会做什么，DSH 不会自己知道。** 我们这条路由是"手工声明的路由"，
pi-ai 适配器在已安装的模型目录里查不到它，查不到就问不出能力，于是全部按
最保守的假设处理。

这个假设会体现在三个地方，每一个都必须靠配置显式声明才能打开：

| 不声明会怎样 | 后果 |
|---|---|
| 不写 `api`（协议） | **路由注册不上**，模型选择器里根本看不到这个模型 |
| 不写 `reasoningEfforts` | **没有思考等级控件**（Off/Low/High/Max 不显示） |
| 不写 `contextWindow` | 窗口显示 262,144（这是 DSH 的兜底默认值，不是服务器的真实值） |
| 不写 `input: image` | **图片发不出去**（详见第 5 节） |

**所以"端点支持"和"DSH 让你用"是两件事。**

### 0.6 为什么每个值都要实测

配置里的每一个数字和每一项能力，都是打真实请求量出来的，不是猜的、
也不是照抄文档的。原因是这个端点给的说明书和实际行为不一致：

| 说明书说 | 实测结果 |
|---|---|
| 可用模型是 `DeepSeek-R1-671B` / `DeepSeek-R1-32B` | **这两个模型不存在**；实际可用的是 `DeepSeek-V4.1-Flash` |
| token 有效期 5 小时 | JWT 里写的是 **24 小时** |
| 未说明上下文长度 | 实测 **1,048,576 token** |
| 未说明推理档位 | 实测只接受 `none` / `low` / `high` / `max` |
| 未说明图像支持 | 实测**支持**，而且真的能看懂图像 |

还有两个坑值得记住：

* **模型不存在时，网关返回的是 HTTP 200**，错误藏在响应体里：
  `{"status":10001,"message":"模型不存在","success":false}`。
  所以**只看状态码会误判成功**。
* **`thinking` 参数被网关完全忽略**：即使传
  `thinking:{type:disabled}`，模型仍然消耗了思考 token。真正能关掉思考的
  只有 `reasoning_effort=none`。所以配置里把发送格式**锁死**成 openai 风格。

### 0.7 实测出来的能力表

| 能力 | 结果 | 配置里对应哪一项 |
|---|---|---|
| 函数调用（Agent 工具） | 支持，流式和非流式都支持 | 无需声明，协议自带 |
| 多轮工具往返 | 支持 | 无需声明 |
| 思考等级 | `none` / `low` / `high` / `max` | `reasoningEfforts` |
| 上下文长度 | 1,048,576（输入+输出合计） | `contextWindow` + `maxTokens` |
| **图像输入** | **支持，能正确识别图像内容** | `input: [text, image]` |
| 提示缓存 | 支持 | 无需声明 |
| 限流 | 30,000 次/分钟 | 无需声明 |

### 0.8 完成的标志

配置成功的标志有三个，缺一个都说明没配好：

1. 模型选择器里出现 **Tsinghua DeepSeek** 组，里面有
   **Tsinghua_DeepSeek_v41**。
2. 该模型的上下文显示 **1M**，并且 Effort 行有
   **Off / Low / High / Max** 四档。
3. 让它读一个文件（或读一张图），它能调用工具并正确回答。

---

## 第 1 节 第一次配置

在新电脑上做一次。

### 步骤 1：拿到 token

1. 打开浏览器。
2. 进入清华 DeepSeek 大模型系统的页面。
3. 用学校账号登录。
4. 找到显示 token 的地方，通常有一个**复制**按钮。
5. 点复制，把完整 token 复制下来。

**token 长什么样：** 一长串由字母、数字、点（`.`）和连字符（`-`）组成的
字符，长度通常 200～400，中间有两个点把它分成三段。

**警告：** 不要把 token 发到邮件、聊天记录或任何别人能看到的地方。
这个 token 等于你学校账号的密码。

### 步骤 2：建立 token 文件

1. 打开记事本。
2. 粘贴 token。
3. **不要**加第二行，**不要**加引号。
4. 保存为纯文本文件，文件名 `tsinghua_token.txt`。

把这个文件放在 `Sync-TsinghuaToken.ps1` 所在目录（脚本默认就找这里）。

顺便说明：如果你复制时多带了 `Bearer ` 前缀或引号，脚本会自动去掉，
不用手工清理。

### 步骤 3：关掉 DSH Desktop

1. 关闭 DSH Desktop 窗口。
2. 确认进程也退出了（任务管理器里查 `DeepSeek Harness`）。

这一步不是必须的（token 是每次请求时读的），但第一次配置时做一次更省事。

### 步骤 4：找到 harness home

1. 打开 Windows PowerShell。
2. 输入：

```powershell
$env:USERPROFILE + "\.dsh"
```

3. 这个目录就是 harness home。
4. 确认里面有 `.credentials.yaml`。

如果这个文件不存在，就先启动一次 DSH Desktop 再关掉，应用会在第一次启动时
创建它。

### 步骤 5：备份原来的配置

把 `<HARNESS HOME>` 换成你上一步得到的路径：

```powershell
$h = "<HARNESS HOME>"
Copy-Item "$h\.credentials.yaml" "$h\.credentials.yaml.before-tsinghua"
Copy-Item "$h\profiles\desktop\cordis.patch.yml" "$h\profiles\desktop\cordis.patch.yml.before-tsinghua"
```

这两个副本就是回滚用的。

### 步骤 6：把 token 写进凭据库

在脚本所在目录打开终端：

```powershell
.\Sync-TsinghuaToken.ps1 -DryRun
```

先空的跑一次（不写入）。输出会显示 token 长度、过期时间和一个指纹，
**不会显示 token 本身**。确认 `Time left` 是正数，然后再真正写入：

```powershell
.\Sync-TsinghuaToken.ps1
```

看到这一行就算成功：

```
Result          : OK.
```

脚本每次都做三件事：**先备份**凭据库、**保留**其他凭据条目、写完**回读
校验**（比对指纹）。

### 步骤 7：把路由写进配置文件

1. 用文本编辑器打开
   `<HARNESS HOME>\profiles\desktop\cordis.patch.yml`。
2. 在文件开头的 `- id:` 列表里加入 `llm-pi-ai` 这一段
   （直接复制仓库里的 `cordis.patch.yml.example`，它是完整可用的版本）：

```yaml
- id: llm-pi-ai
  config:
    providers:
      tsinghua:
        apiKeyEnv: TSINGHUA_DEEPSEEK_API_KEY
        api: openai-completions
        baseURL: https://madmodel.cs.tsinghua.edu.cn/v1
        displayName: Tsinghua DeepSeek
        reasoning: high
        models:
          - id: DeepSeek-V4.1-Flash
            name: Tsinghua_DeepSeek_v41
            contextWindow: 1048576
            maxTokens: 131072
            input:
              - text
              - image
            reasoningEfforts:
              off: none
              low: low
              high: high
              max: max
            compat:
              supportsReasoningEffort: true
              maxTokensField: max_tokens
              thinkingFormat: openai
        defaultContextWindow: 1048576
        defaultMaxTokens: 131072
```

3. 保存。

**注意：** YAML 用空格缩进，**不要按 Tab 键**。缩进层级要和示例一致。

**注意：** `api: openai-completions` 必须放在 **`tsinghua` 这一层**
（路由层），放在 `models:` 里面**不生效**。这是最容易踩的坑。

### 步骤 8：设成默认模型（可选）

这一步不做也能用，只是在每个新会话里要手动选一次模型。

要设成默认，就改 `agent-default-model` 这一段：

```yaml
- id: agent-default-model
  name: "@deepseek-ai/dsh-agent-default-model"
  config:
    provider: tsinghua
    model: DeepSeek-V4.1-Flash
    reasoningEffort: high
```

**权衡：** token 每 24 小时过期。把它设成默认模型，意味着 token 过期后每个
新会话都会直接报认证错误。想更稳妥就保持默认模型为官方 DeepSeek，
用模型选择器临时切到清华这条路由。

### 步骤 9：启动应用并验证

1. 启动 DSH Desktop。
2. 打开模型选择器。
3. 找到 **Tsinghua DeepSeek** 组 → **Tsinghua_DeepSeek_v41**。
4. 选中它，确认上下文显示 **1M**（1,048,576）。
5. 确认 Effort 行有 **Off / Low / High / Max** 四档。
6. 发一条会用到工具的指令，例如"读一下 README.md"。
7. 能正确调用工具并回答，就说明整条链路通了。

---

## 第 2 节 每 24 小时换 token

token 每 24 小时过期，过期后 DSH 会报认证错误。换 token 只做三件事：

1. 重新复制一个新 token（同第 1 节步骤 1）。
2. 把 `tsinghua_token.txt` 里的内容**整行替换**成新 token。
3. 运行：

```powershell
.\Sync-TsinghuaToken.ps1
```

看到 `Result : OK.` 就完成了。**不需要改配置文件，不需要重启应用。**

### 查还剩多久

```powershell
.\Sync-TsinghuaToken.ps1 -DryRun
```

看输出里的 `Time left`（单位：分钟）。负数说明已经过期。

---

## 第 3 节 搬到另一台电脑或另一个用户

**配置文件可以搬，凭据库不能搬。** 原因见第 0.4 节：配置文件里只有 token
的名字，没有 token 本身。

在新电脑上：

1. 把 `cordis.patch.yml` 复制到新机器的
   `<HARNESS HOME>\profiles\desktop\` 目录。
   如果那里已有同名文件，要把两边的条目**合并**，不要把原来的直接覆盖掉。
2. 把 `Sync-TsinghuaToken.ps1` 复制到任意目录。
3. 启动一次 DSH Desktop 再关掉（让凭据库生成出来）。
4. **用你自己的账号**去清华控制台拿一个**你自己的** token。
5. 建立 `tsinghua_token.txt`，运行脚本。
6. 按第 1 节步骤 9 验证。

两点必须注意：

* **每个人要用自己的 token。** 不要拿别人的 token 跑，也不要共享凭据库——
  token 对应的是具体某个人的校园身份。
* **凭据库里还有一个浏览器会话签名密钥**，它和主机名、端口绑定，
  复制到别的机器上会失效。

---

## 第 4 节 配置项逐条说明

| 配置项 | 值 | 作用 |
|---|---|---|
| `apiKeyEnv` | `TSINGHUA_DEEPSEEK_API_KEY` | token 在凭据库里的名字。两边必须一致。 |
| `api` | `openai-completions` | 协议。**必须写在路由层（`tsinghua` 下一层）**。 |
| `baseURL` | `https://madmodel.cs.tsinghua.edu.cn/v1` | 端点地址。DSH 会自己补 `/chat/completions`。 |
| `reasoning` | `high` | 这条路由的默认思考档位。 |
| `displayName` | `Tsinghua DeepSeek` | 模型选择器里显示的分组名。 |
| `models[].id` | `DeepSeek-V4.1-Flash` | 端点侧真正的模型 id。**必须写这个**。 |
| `models[].name` | `Tsinghua_DeepSeek_v41` | 在 DSH 界面里显示的名字，可自定义。 |
| `contextWindow` | `1048576` | 实测的最大输入长度。 |
| `maxTokens` | `131072` | 输出预留额度。 |
| `input` | `text` + `image` | 声明支持的输入形态。**少写 image 就用不了图片**。 |
| `reasoningEfforts` | 四个档 | 界面上的思考等级。 |
| `compat.thinkingFormat` | `openai` | 锁死发送格式，防止被换成端点不认的字段。 |

### 4.1 为什么 `maxTokens` 不能也填 1M

端点的 1,048,576 是**输入和输出共用一个池子**。如果 `contextWindow` 和
`maxTokens` 都填 1,048,576，一旦输入接近满额，输入+输出就会超额，网关直接
返回 HTTP 400。

同时 DSH 的压缩机制要求 `contextWindow > maxTokens + 65536`。
`maxTokens = 131072` 同时满足这两个条件，也符合主流服务的输出上限惯例。

### 4.2 上下文长度是实测值

判定方法是**在超长提示词的末尾埋一个哨兵数字**——只有模型真的读到了结尾
才会答对。这样能区分"真支持"和"静默截断"：

| 目标长度 | 实际输入 token | 结果 |
|---|---|---|
| 400K | 400,853 | 通过，尾部哨兵答对 |
| 600K | 600,919 | 通过，尾部哨兵答对 |
| **1M** | **1,000,136** | **通过，尾部哨兵答对** |
| 1.05M 以上 | — | HTTP 400 拒绝 |

网关自己在报错里写明了上限：

```
This model's maximum context length is 1048576 tokens
max_model_len=max_total_tokens=1048576
```

### 4.3 262K 是哪来的

**262,144 不是清华服务器的限制，是 DSH 自己给未知模型的兜底默认值。**
pi-ai 适配器在已安装目录里查不到我们的模型，就一路回退到这个默认值。

所以原来的 262K 是"DSH 的保守假设"，不是测量结果。改配置之后显示的
1M 才是真实值。

---

## 第 5 节 图像支持

### 5.1 结论：支持，而且是真的看得懂

实测这个端点支持图像输入，而且**真的能理解图像内容**，不是收下就忽略。

最有说服力的验证是**用已知答案的自制图**去问，让它必须答出只有看到图才能
答对的东西：

| 测试 | 结果 |
|---|---|
| 自制图（白底+红竖线+蓝横线+绿色空心圆环），问"圆环是什么颜色" | 答 **Green**（正确） |
| 真实科研图（1.29 MB），问"有几个子图" | 答 **6**（与图中真实子图数一致） |
| 1302 / 2048 / 3072 px 三种分辨率 | 全部正确，图像 token 都约 995 |

网关自己的用量账本也承认收到了图：

```json
"prompt_tokens_details": { "multimodal_tokens": { "image": 1003 } }
```

### 5.2 必须靠配置打开

端点支持不等于 DSH 让你用。**pi-ai 有一道显式闸门**：只有模型声明了
`input` 里包含 `image`，它才会把图片发上线。而 DSH 侧还有三处检查点：

| 检查点 | 没声明 image 时的行为 |
|---|---|
| `projectImagesForTextModel` | 发请求前把图片**替换成占位文本** |
| `assertImageCapableRoute`（read 工具） | 拒绝读取图片路径，报 `does not declare image input` |
| 附件校验（会话控制器） | 报 `MODEL_DOES_NOT_SUPPORT_IMAGES` |

所以要改的就是这一处：

```yaml
            input:
              - text
              - image      # 没有这一行，上面三道闸门都会把图片拦掉
```

### 5.3 图像 token 的分辨率特性

实测发现图像消耗的 token **与分辨率基本无关**，都封顶在 1000 左右：

| 图像尺寸 | 图像 token |
|---|---|
| 1302 × 1302 | 约 995 |
| 2048 × 2048 | 约 995 |
| 3072 × 3072 | 约 995 |

而且端点**忽略 `detail: low`** 参数。

**这意味着：提高图片像素预算不会多花 token，只影响画面清晰度。**

因此配置里没有改这条路由默认的图片预算（`requestImagePixelBudget`，
默认 2048×2048 ≈ 4,194,304 像素；`requestImageMaxBytes` 默认 1 MiB）。
只有在特别看重细节时才在模型设置页调高。

### 5.4 怎么用

配好之后，直接把图片拖进对话、粘贴截图，或者让 Agent 用工具读图片文件
都会正常走通。DSH 会把它编码成 data URL 发给端点。

### 5.5 提醒

图片**占用上下文**（每张约 1000 token）。在接近 1M 的长会话里连续贴图，
会加快触发自动压缩。

---

## 第 6 节 排错

### 模型选择器里没有 Tsinghua DeepSeek 组

1. 确认配置文件里有 `llm-pi-ai` 这一段。
2. 确认 `api: openai-completions` 写在 **`tsinghua` 路由层**，不是写在
   `models:` 里面。
3. 保存文件，应用会自动重载。
4. 重新打开模型选择器。仍然看不到就重启应用。

### 报认证错误

1. 运行 `.\Sync-TsinghuaToken.ps1 -DryRun`，看 `Time left`。
2. 如果是负数，去拿新 token。
3. 确认凭据库里的名字和配置文件里的 `apiKeyEnv` 完全一样。
4. 重新运行脚本。

### 刚复制的新 token 就被拒绝

多半是 token 不完整。**用页面的"复制"按钮，不要用鼠标拖选**——拖选很容易
少一个字符。然后把 token 文件里的内容整行替换，重新运行脚本。

（这种错误很隐蔽：少一个字符，JWT 签名就必然失效，表现却和 token 过期一样。）

### 上下文显示 262K

1. 确认 `contextWindow: 1048576` 写在 **`models:` 条目里**。
2. 关掉模型选择器再打开。

### 图片发不出去

1. 确认 `input:` 列表里同时有 `text` 和 `image`。
2. 确认这一行写在 **`models:` 条目里**。
3. 保存后重新打开模型选择器。

### 出现 "Could not restrict the file permissions" 警告

可以忽略。Windows 修改某些文件的访问控制列表需要管理员权限。常规情况下
凭据库的权限本来就够安全。

### 回滚

把 `.before-tsinghua` 结尾的备份文件覆盖回原文件，然后重启应用。

---

## 第 7 节 安全规则

* token 只放在 token 文件和凭据库里，别的地方都不要放。
* **不要把 token 写进配置文件。**
* 不要把 token 提交到 git 仓库。
* 不要把 token 发到聊天记录或日志里。
* 确认配置文件里**不含任何个人信息**——它是要被分享和提交的。
* token 过期后，及时清掉旧 token 文件。

`.gitignore` 已经排除了 `tsinghua_token.txt` 和 `.credentials.yaml`，
但**不要依赖它**：提交前自己再看一眼。

---

## 第 8 节 技术参数汇总

| 项目 | 值 |
|---|---|
| 端点 | `https://madmodel.cs.tsinghua.edu.cn/v1` |
| 协议 | OpenAI Chat Completions |
| 端点侧模型 id | `DeepSeek-V4.1-Flash` |
| DSH 里显示的名字 | `Tsinghua_DeepSeek_v41` |
| 路由 id | `tsinghua` |
| 凭据名 | `TSINGHUA_DEEPSEEK_API_KEY` |
| token 有效期 | 24 小时 |
| 最大上下文 | 1,048,576 token（输入+输出合计） |
| 输出上限 | 131,072 token |
| 思考档位 | Off / Low / High / Max |
| 函数调用 | 支持（流式与非流式） |
| 图像输入 | 支持（每张约 1000 token） |
| 限流 | 30,000 次/分钟 |

---

## 名词表

| 名词 | 意思 |
|---|---|
| harness home | DSH 存放数据的目录，通常是 `%USERPROFILE%\.dsh` |
| profile | 一套 DSH 配置，本文用到的叫 `desktop` |
| 配置文件 / patch | `cordis.patch.yml`，存放你的配置改动 |
| 凭据库 | `.credentials.yaml`，存放密钥本体 |
| 路由（route） | 指向某个模型服务的一条配置 |
| 端点（endpoint） | 提供模型服务的网络地址 |
| token | 清华服务的校园身份凭据，24 小时有效 |
| JWT | token 的格式（JSON Web Token） |
| Effort | 模型回答前的思考量档位 |
| 指纹 | 用于识别某个值的一小段代码，不暴露原值 |
