# Tsinghua DeepSeek for DSH Desktop

Configuration for the Tsinghua DeepSeek model service
(`madmodel.cs.tsinghua.edu.cn`) in DSH Desktop, plus the 24-hour token
maintenance routine.

## The two documents

| File | For | Content |
|---|---|---|
| [SETUP.md](SETUP.md) | a person | Step-by-step procedure. Written in ASD-STE100 Simplified Technical English. Start here. |
| [AGENT_NOTES.md](AGENT_NOTES.md) | an agent | Full configuration record: work log, root causes, pitfalls, verification recipes, migration. |

## The one important point

The token expires every 24 hours. **The new token goes into a plain text file,
not into the profile file:**

```
tsinghua_token.txt   →   Sync-TsinghuaToken.ps1   →   <harness home>/.credentials.yaml
   (you paste here)         (validates, writes)          (DSH reads it per request)
```

```
.\Sync-TsinghuaToken.ps1
```

No restart. No profile edit.

## Files

| File | Purpose |
|---|---|
| `Sync-TsinghuaToken.ps1` | Validates the token and writes it into the DSH credential store. Keeps other entries. Makes a backup. Never prints the token. |
| `cordis.patch.yml.example` | The complete profile patch file. Copy it to `<harness home>/profiles/desktop/cordis.patch.yml`. |
| `tsinghua_token.txt.placeholder` | Shows the required format of the token file. |

## Result

| Item | Value |
|---|---|
| Model in the DSH model selector | `Tsinghua_DeepSeek_v41` (group **Tsinghua DeepSeek**) |
| Context window | 1,048,576 tokens (measured) |
| Output reservation | 131,072 tokens |
| Thinking levels | Off / Low / High / Max |
| Agent tools | Supported, streaming and not streaming |

## Safety

The profile file contains no secret data and is safe to share. The token is a
24-hour credential for your school account — keep it in the token file and in
the credential store only. See SETUP.md, Section 6.
