# DSH Desktop + Tsinghua DeepSeek: Full Configuration Record (Agent Notes)

**Audience:** a DSH agent that must reproduce, migrate, audit, or repair this
route. Written to be read cold — no context from the original sessions needed.

**Status at time of writing:** route live and verified end-to-end. Token
refreshes every 24 h through one manual file paste plus one script run.

**Sensitive-data policy for this document:** no token, no account identity, no
personal paths, no machine name. All secrets appear as placeholders. Sections
marked *[masked]* were redacted from the source evidence.

---

## 1. Objective and hard constraints

| Item | Value |
|---|---|
| Endpoint | `https://madmodel.cs.tsinghua.edu.cn/v1` |
| Wire protocol | OpenAI Chat Completions (`/v1/chat/completions`) |
| Endpoint-side model id | `DeepSeek-V4.1-Flash` |
| DSH-visible model name | `Tsinghua_DeepSeek_v41` |
| DSH route (provider) id | `tsinghua` |
| DSH adapter package | `@deepseek-ai/dsh-llm-pi-ai` (bundle id `llm-pi-ai`) |
| Credential reference | `TSINGHUA_DEEPSEEK_API_KEY` |
| Token lifetime | 24 h (JWT `exp`) |
| Real context window | 1,048,576 tokens (input + output share the pool) |
| Output reservation | 131,072 tokens |
| Thinking levels | `off` / `low` / `high` / `max` |
| Agent capability | Full — streaming and non-streaming `tool_calls`, multi-turn tool round-trip |

Constraints that shaped the design:

1. The token expires every 24 h. The refresh must not require editing the profile.
2. The profile file must be portable to another computer and another OS user.
3. No secret may enter the profile file, the repository, or any log.

---

## 2. The one manual step, and where it goes

**This is the answer to "where do I paste the token".**

The manual paste target is a **plain text file** — not the profile file.

```
tsinghua_token.txt        ← you paste the new token here (one line, no quotes)
        │
        │  Sync-TsinghuaToken.ps1   (reads, validates, strips "Bearer ", fingerprints)
        ▼
<harness home>/.credentials.yaml
   refs:
     TSINGHUA_DEEPSEEK_API_KEY: <token>     ← machine writes here, never a human
        │
        │  pi-ai resolves apiKeyEnv per request through the credentials seam
        ▼
<harness home>/profiles/desktop/cordis.patch.yml
   providers.tsinghua.apiKeyEnv: TSINGHUA_DEEPSEEK_API_KEY   ← reference only, no secret
```

Refresh loop, every 24 h:

```powershell
# 1. paste the new token into tsinghua_token.txt
# 2. then:
.\Sync-TsinghuaToken.ps1
```

No application restart, no profile edit. Verified: `dsh-credentials-local`
watches the store (`watch: true`) and `apiKeyEnv` resolves per request.

### Credential precedence (from `dsh-credentials-local/README.md`)

Highest wins:

| Place | Writable | Wins over |
|---|---|---|
| Launch environment (`DSH_HOME`-scoped process env) | no | everything |
| The stored file `<harness home>/.credentials.yaml` | yes | both `.env` files |
| Project `.env` (`<invocation cwd>/.env`) | not here | home `.env` |
| Home `.env` (`<harness home>/.env`) | not here | nothing |

Consequence: if the launching environment already exports
`TSINGHUA_DEEPSEEK_API_KEY`, the script's write is **shadowed** — the store is
not consulted at all. `dsh-credentials-local` reports such a write as refused.
Check for this before debugging anything else.

### Why the script exists instead of a GUI paste

The UI route is legitimate: the Models page writes the key through
`credentials.set` under the route's `apiKeyEnv`, and it never echoes the value.
The script exists because (a) the requirement names a text file as the paste
target, (b) a 24 h cadence favors one command, and (c) the script validates
shape and expiry before writing. Both paths land in the same place, so they do
not conflict.

---

## 3. Exact final state

### 3.1 `profiles/desktop/cordis.patch.yml`

The Tsinghua block, verbatim (comments trimmed):

```yaml
- id: llm-pi-ai
  config:
    providers:
      tsinghua:
        apiKeyEnv: TSINGHUA_DEEPSEEK_API_KEY
        displayName: Tsinghua DeepSeek
        api: openai-completions          # ROUTE level — see pitfall P1
        baseURL: https://madmodel.cs.tsinghua.edu.cn/v1
        reasoning: high                  # route-level default effort
        models:
          - id: DeepSeek-V4.1-Flash
            name: Tsinghua_DeepSeek_v41
            contextWindow: 1048576
            maxTokens: 131072
            input:
              - text
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

The default-model entry in the same file:

```yaml
- id: agent-default-model
  name: "@deepseek-ai/dsh-agent-default-model"
  config:
    provider: tsinghua
    model: DeepSeek-V4.1-Flash
    reasoningEffort: high
```

Pre-existing entries in this file that are unrelated to Tsinghua: `ui-chat`,
`ui-settings`, `ui-settings-account`.

### 3.2 `<harness home>/.credentials.yaml`

```yaml
version: 1
refs:
  TAVILY_API_KEY: <unrelated>            # [masked]
  DEEPSEEK_API_KEY: <unrelated>          # [masked]
  TSINGHUA_DEEPSEEK_API_KEY: <token>     # [masked] — written by the script
records:
  client-connection/browser-session:     # harness-generated cookie signing grant
    kind: grant
    payload:
      version: 1
      secret: <masked>
```

### 3.3 Profile root `profiles/desktop/cordis.yml`

```yaml
# dsh profile root — an empty entry list. The tree is composed as patches:
# each bundle in package.json's dsh.profile.bundles, then cordis.patch.yml, then any
# --patch overlays. Edit cordis.patch.yml, not this file.
[]
```

Do not put configuration here — `cordis.patch.yml` is the writable layer.

### 3.4 Where settings actually persist

`@deepseek-ai/dsh-settings` persists form edits **through the active profile's
Cordis patch**, i.e. back into `cordis.patch.yml`. There is no second settings
document for this profile. `settings.yaml.imported` in the harness home is a
one-time legacy import artifact; note that it can hold **stale** values (in our
instance it still names `agent-default-model.provider: deepseek-official` while
the live patch names `tsinghua`). Trust the patch file and the live RPC, not
`settings.yaml.imported`.

**Consequence:** the GUI and the file are the same source. Editing the file in
an editor and editing the Models page are equivalent, and the running instance
hot-reloads the file. But a GUI save can rewrite the file, so re-read it after
any GUI edit before concluding the file is wrong.

---

## 4. Chronological work log and the gate model

The work used a **gate model**: no configuration was written until the previous
gate was proven by evidence. Six phases, six gates.

### Phase 0 — Feasibility gate

Question: does DSH support an OpenAI-compatible custom endpoint at all?

Evidence: DSH has a "Custom model API" entry (`llm-pi-ai`) whose
`openai-completions` implementation sends `Authorization: Bearer <key>` to
`baseURL + /chat/completions`, matching the documented curl exactly. The
official `deepseek-official` route is *wrong* here — it speaks DeepSeek's
Messages API with an `x-api-key` header and cannot address this gateway.

Gate 0: **pass** — a compatible adapter exists.

### Phase 1 — Token and capability gate

Question: is the endpoint real, and can it drive an agent (tool calls)?

Method: send the token raw from a file, never retyped. Test list:

| Test | Result |
|---|---|
| Basic chat | HTTP 200, `served_as: deepseek-ai/DeepSeek-V4.1-Flash`, backend `vllm-0.13.0-tp8-ep` |
| Non-streaming `tools` + `tool_choice:auto` | `finish_reason: tool_calls`, valid argument JSON |
| Streaming `tools` | `text/event-stream`, `delta.tool_calls` fragments assemble correctly |
| Multi-turn round trip | assistant(`tool_calls`) → `role:tool` result → model consumes and concludes |
| DSH-shaped tool schema | two parallel calls in one turn (`pwsh` + file read), escaping correct |
| `system` role | respected |
| `temperature` / `repetition_penalty` / `top_p` | accepted |
| Prompt cache | `prompt_tokens_details.cached_tokens` populated |
| Rate limit | 30,000 req/min (`x-ratelimit-limit`) — not a constraint |

Two findings contradicted the supplied PDF and were resolved in favor of
measurement:

* **The PDF's model ids do not exist on this endpoint.**
  `DeepSeek-R1-671B` and `DeepSeek-R1-32B` return **HTTP 200 with an error body**:
  `{"data":null,"status":10001,"message":"模型不存在","success":false}`.
  Status-code checks therefore mis-classify this as success. Only
  `DeepSeek-V4.1-Flash` is served.
* **The PDF's stated lifetime** ("5 hours") disagreed with the JWT. Both the
  original token and a later one decoded to a **24 h** `exp`. Trust the JWT.
  The document's own curl mentions a `v3.2` fallback model; that id was not
  validated for agent use.

Gate 1: **pass** — real endpoint, full agent capability, one usable model id.

### Phase 2 — Profile write gate

Wrote the credential ref and the `llm-pi-ai` route. Validated the YAML and the
provider config shape against `dsh-llm-pi-ai`'s own schemastery `Config`
(0 issues on the positive case; a fake protocol and a model without `id` both
raised `ValidationError`, proving the check was not a no-op).

Gate 2: **pass, but the route did not appear in the UI** — which opened Phase 3.

### Phase 3 — Root-cause gate (the expensive one)

Symptom: the model group was absent from the desktop model selector, even
though the file parsed and merged cleanly.

Dead ends, each eliminated by evidence:

* Profile not reloading — disproved: HMR enabled, patch merged with 0 warnings.
* Wrong patch semantics (replace vs merge) — disproved: patches are
  field-level overrides and an entry without `name` is valid.
* Another config source shadowing the file — disproved: a full scan of the
  user data directory found only this one patch file.
* A `settings` layer overriding the patch — partially true (see below) but not
  the cause.

Method that worked: **query the running instance's own RPC** instead of
reasoning about behavior. The browser cookie is
`v1.<base64 payload>.<HMAC>` signed with the owner-scoped
`client-connection/browser-session` grant secret stored in
`.credentials.yaml`. From there:

```
llm/listConfigurableProviders   →  permission and per-route error field
credentials/describe            →  { configured, source, writable }, never the value
session/modelCatalog            →  the live catalogue the model selector renders
settings/describe, settings/update, settings/replace  →  live settings layer
```

The first query returned the answer verbatim:

```
provider "tsinghua" model "DeepSeek-V4.1-Flash" needs an api;
the installed catalog does not describe it, so set the route's api ...
```

Root cause: **the `api` field was missing, and it is a *route-level* field, not
a model-level field.** The resolution order in `dsh-llm-pi-ai` is:

```js
const api = request.api ?? base?.api ?? routeApi;
if (api === undefined) invalid(provider, `model "${id}" needs an api; …`);
```

A route pi-ai does not ship must declare `api`, `baseURL`, and a non-empty
`models` list. Writing `api:` on the model was silently ineffective, which is
why the identical error persisted through the first fix attempt.

Gate 3: **pass** — after moving `api` to the route level, the error field
disappeared and the live catalogue returned the group.

### Phase 4 — Thinking-level gate

Question: can Off / Low / High / Max be exposed?

First finding: the live catalogue entry for `Tsinghua_DeepSeek_v41` had **no
`reasoning` field at all**, while `deepseek-official` had four levels. This is
deliberate, not a bug. `reasoningInfo()` documents it: a model without
reasoning metadata — *every hand-declared route* — reports only `off`, and
passing that through would offer a control that cannot do what it says, so the
**whole `reasoning` field is omitted**.

Fix: declare `reasoningEfforts` explicitly on the model.

Then measure which levels the gateway really accepts, with a task hard enough
that thinking is actually spent (missionaries-and-cannibals), reading
`reasoning_tokens`:

| Request | `reasoning_tokens` |
|---|---|
| baseline, no parameter | 1182 |
| `reasoning_effort=none` | **0** — genuinely off |
| `reasoning_effort=low` | 1334 |
| `reasoning_effort=high` | 1872 |
| `reasoning_effort=max` | 2400 (hit the output cap) |
| `minimal` / `medium` / `xhigh` | **HTTP 400** |

The gateway states its own contract:

```
DeepSeek V4.1 reasoning_effort must be low, high, max, or an integer within [1, 100]
```

So the four UI levels are the endpoint's native set, with `off` implemented by
`none` — not an invented mapping.

Second trap in this phase: `thinkingFormat`. pi-ai defaults an *unknown*
gateway to the OpenAI style (top-level `reasoning_effort`), but if it resolves
to `deepseek` it emits `thinking:{type:…}` instead. Measured:

```
thinking={type:disabled}   → reasoning_tokens = 20   ← gateway ignores the field
reasoning_effort=none      → reasoning_tokens = 0    ← actually works
```

The gateway does not understand the `thinking` object at all. Therefore
`compat.thinkingFormat: openai` is **pinned explicitly** so the unknown-gateway
default can never drift.

Gate 4: **pass** — live catalogue reports
`efforts=[off,low,high,max]`, route default `high`.

### Phase 5 — Context-window gate

Question: is the displayed 262K the server's limit or a DSH default?

Answer to the second half first, from source: `dsh-llm-pi-ai` has

```js
const DEFAULT_CONTEXT_WINDOW = 262144;
defaultContextWindow: source.defaultContextWindow ?? 262144
```

and resolves `entry.contextWindow ?? base?.contextWindow ?? request.defaultContextWindow`.
For a hand-declared route the installed catalogue has no entry, so the lookup
falls all the way to `262144`. **The number was DSH's conservative assumption
for an undescribed model, not a measurement.**

Then measure the real ceiling. The critical test design: place a **sentinel
number at the very end of an oversized prompt**, so a correct answer proves the
model really read the tail — distinguishing true support from silent truncation.

| Target | Actual `prompt_tokens` | Result |
|---|---|---|
| 400K | 400,853 | HTTP 200, tail sentinel correct |
| 600K | 600,919 | HTTP 200, tail sentinel correct |
| **1M** | **1,000,136** | **HTTP 200, tail sentinel correct** |
| 1.05M / 1.1M / 1.2M | — | **HTTP 400** |

The 400 body states the limit outright:

```
This model's maximum context length is 1048576 tokens
your prompt contains at least 1048513 input tokens
max_tokens=10000000 cannot be greater than max_model_len=max_total_tokens=1048576
```

So the ceiling is **1,048,576 shared by input + output**. That is why
`contextWindow` and `maxTokens` cannot both be 1,048,576.

`maxTokens: 131072` was chosen because it satisfies both constraints: DSH's
compaction policy requires `contextWindow > maxTokens + headroomTokens
(65536)`, and input + output must stay within 1,048,576.

End-to-end proof, from the harness's own durable log (`request/context`
records, appended as multiple zstd frames):

```json
{"type":"request/context","seq":12,
 "data":{"provider":"tsinghua","model":"DeepSeek-V4.1-Flash","contextWindow":1048576}}
```

Gate 5: **pass** — the running instance resolves 1,048,576 for this route.

### Phase 6 — Maintenance and portability

Token refresh moved to the file + script pattern in Section 2. Portability
verified by inspection: the patch file contains only public values plus a
credential *name*; the credential store is machine-local and is regenerated
from each user's own token.

---

## 5. Pitfalls and their fixes

| # | Pitfall | Root cause | Fix |
|---|---|---|---|
| **P1** | Route missing from the model selector; `needs an api` error | `api` written at model level; it is a **route-level** field (`request.api ?? base?.api ?? routeApi`) | `providers.tsinghua.api: openai-completions` |
| **P2** | Editing only `cordis.patch.yml` had no visible effect | The GUI's settings layer writes *through* the profile patch and can rewrite the file; the two can diverge | Re-read the file after any GUI save; treat the file as the single source and the live RPC as truth |
| **P3** | Effort selector absent | Adapter intentionally omits `reasoning` for models with no declared reasoning metadata | Declare `reasoningEfforts` explicitly |
| **P4** | `thinking` object had no effect | Gateway ignores `thinking:{…}` entirely (20 reasoning tokens remained with `disabled`) | `compat.thinkingFormat: openai`, plus `supportsReasoningEffort: true` |
| **P5** | 262K shown although the server allows 1M | `dsh-llm-pi-ai`'s `DEFAULT_CONTEXT_WINDOW = 262144` fallback for undescribed models | Set `contextWindow` / `defaultContextWindow` to the measured 1048576 |
| **P6** | Unknown model returned **HTTP 200** with an error body | Gateway wraps errors: `{"status":10001,"message":"模型不存在","success":false}` | Validate the JSON body, never the status code |
| **P7** | 401 with a token that looked right | One character lost while transcribing the token by hand — base64 segment 188 chars / 141 bytes instead of 192 / 142; first divergence at byte 44 | Never retype a token. Read it from a file; verify by decoded length and fingerprint |
| **P8** | Empty replies at large prompt sizes | The probe script mis-parsed chunked output; the request had actually succeeded (600,919 prompt tokens, correct sentinel) | Capture and inspect the raw body before concluding failure |
| **P9** | A stray web server appeared on port 3080 | Side effect of a probe script | Kill it; never start a second server — the user's GUI is on its own port and must stay untouched |
| **P10** | Warning "Could not restrict the file permissions" | `Set-Acl` outside the sandbox / without elevation | Treat as non-fatal; the harness provider performs its own permissions check |
| **P11** | `Bearer ` prefix or surrounding quotes inside the pasted file | Copy-paste variation | The script strips quotes, whitespace, and a leading `Bearer`/`Bearer:` |

---

## 6. Verification recipes

### 6.1 Static checks (no running instance needed)

```powershell
# YAML parses?
python -c "import yaml,sys; yaml.safe_load(open(sys.argv[1],encoding='utf-8'))" cordis.patch.yml

# no secret in the profile file?
Select-String -Path cordis.patch.yml -Pattern 'eyJ|sk-|tvly-'
```

### 6.2 Live checks (running instance)

The host RPC accepts a browser session cookie. Construct it from the stored
grant secret, then query:

```
llm/listConfigurableProviders  → "routableProviders": ["tsinghua","deepseek-official"], "failures": []
credentials/describe           → TSINGHUA_DEEPSEEK_API_KEY: configured true, source file
session/modelCatalog           → group tsinghua / Tsinghua_DeepSeek_v41,
                                 reasoning.efforts = off,low,high,max
settings/describe              → effective merged values for llm-pi-ai
```

Never print the cookie or the grant secret. Do not persist a cookie to disk.

### 6.3 Durable log check

The harness appends the resolved capacity per request as `request/context`
records (zstd-framed, multiple frames per file). Expect:

```json
{"data":{"provider":"tsinghua","model":"DeepSeek-V4.1-Flash","contextWindow":1048576}}
```

### 6.4 End-to-end agent check

Send a message through the route that requires a tool call. A successful tool
round trip proves the whole chain: credential resolution → protocol → streaming
tool fragments → agent loop.

### 6.5 Effective credential check without printing the secret

Compare a SHA-256 prefix of the token file against a SHA-256 prefix of the
stored value. `Sync-TsinghuaToken.ps1` does exactly this on every run and
reports only a 12-hex fingerprint.

---

## 7. Migration to another computer or user

Requirements: DSH Desktop installed; a Tsinghua token **belonging to that
user**; the two repository files.

Steps:

1. Copy `cordis.patch.yml` to
   `<new harness home>/profiles/desktop/cordis.patch.yml`.
   Merge with an existing file if one exists — never blind-overwrite a file
   that already carries other entries.
2. Start DSH Desktop once and close it, so `.credentials.yaml` exists.
3. Get the new user's own token and put it in `tsinghua_token.txt`.
4. Run `Sync-TsinghuaToken.ps1`.
5. Verify with Sections 6.2–6.4.

Portability facts:

* The patch file is user- and machine-independent. It contains no secret.
* `.credentials.yaml` is machine-specific and must **not** be moved.
* The credential *name* `TSINGHUA_DEEPSEEK_API_KEY` is a reference, not an
  account binding — it is safe to keep the same name in the new installation.
* No absolute personal path appears in the configuration.

**Do not** copy `.credentials.yaml` between users: the token identifies the
original account, and the file also holds a browser-session signing secret that
is host- and port-bound.

---

## 8. Security notes

* The token is a **24 h account credential**, not an API key. It decodes to an
  identification payload (school id, name, unit, category) plus `iat`/`exp`.
  Treat it as a password. Do not put it in a repository, a chat, or a log.
* The profile file carries only the reference name. Keep it that way. A literal
  `apiKey` field is possible in some configs; do not use it here.
* The mechanism that makes the patch file shareable is exactly the
  `apiKeyEnv` indirection: `cordis.patch.yml` never holds a key value.
* Prefer a file read over retyping for any long credential — pitfall P7 is a
  one-character transcription error, and a JWT signature makes it an
  all-or-nothing failure.
* If a token leaks, it expires within 24 h; rotate immediately and check
  `llm/listConfigurableProviders` for unexpected routes.
* Publishing a patch file: scan it for identity-bearing strings before pushing.

---

## 9. Rollback

Restore from the pre-change copies of `cordis.patch.yml` and
`.credentials.yaml`, then restart the application. The script additionally
writes a timestamped `.credentials.yaml.bak-<timestamp>` before every write.

Removing the route entirely: delete the `llm-pi-ai` entry (and the
`agent-default-model` entry if it points at `tsinghua`) from
`cordis.patch.yml`, then remove the `TSINGHUA_DEEPSEEK_API_KEY` entry from
`.credentials.yaml`.

---

## 10. Open items and known limitations

* **Boundary saturation:** input + output share 1,048,576. A maximal input with
  a maximal output returns HTTP 400. DSH compaction (about 0.8 × window ≈ 838K)
  intervenes before that in practice.
* **`max` is slow:** one measured `max` request took about 66 s because
  thinking consumed the output budget.
* **Unvalidated ids:** the PDF's `v3.2` fallback id was never tested for tool
  calling; only `DeepSeek-V4.1-Flash` is proven.
* **`name` field on the `llm-pi-ai` entry:** omitted intentionally. The entry
  targets an already-composed bundle row by `id`, so `name` is not needed.
* **Redundant model-level leftovers:** earlier fix attempts left fields that
  are ignored because the route level wins. They are harmless; cleaning them
  needs the precise `settings` unset-op schema.
* **Token cadence:** 24 h. There is no refresh mechanism — the lifecycle is
  manual by design.
