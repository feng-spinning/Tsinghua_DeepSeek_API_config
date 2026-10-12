# How to Configure the Tsinghua DeepSeek Route in DSH Desktop

## About this document

This document tells you how to use the Tsinghua DeepSeek service in DSH Desktop.
The document gives the procedure from the token download to the first test
request.

The text obeys the principles of ASD-STE100 Simplified Technical English:
short sentences, one instruction for each sentence, the active voice, and one
word for one meaning. See [ASD-STE100](https://www.asd-europe.org/standards-specifications/simplified-technical-english/).

### Find the right procedure

Use this table to find your procedure.

| Your task | Go to |
|---|---|
| Configure the route on a new computer | Section 1 |
| Replace an expired token | Section 2 |
| Move the configuration to an other computer | Section 3 |
| Repair a problem | Section 5 |

**Important:** Section 1 is necessary one time only. Section 2 is necessary
every 24 hours.

### Words in this document

| Word | Meaning |
|---|---|
| **harness home** | The folder that holds the DSH data. The usual path is `$env:USERPROFILE\.dsh` on Windows and `~/.dsh` on other systems. The environment variable `DSH_HOME` can change it. |
| **profile** | One DSH configuration set. This document uses the profile `desktop`. |
| **patch file** | The file that holds your configuration changes. Its path is `<harness home>\profiles\desktop\cordis.patch.yml`. |
| **credential store** | The file that holds the secret values. Its path is `<harness home>\.credentials.yaml`. |
| **token file** | The text file that holds the token. You make this file. |
| **token** | The login token from the Tsinghua DeepSeek service. |
| **route** | One connection to a model service. This document uses the route `tsinghua`. |

## Understand how the system works

The system has four parts. The parts work in this sequence:

1. You copy a new token from the Tsinghua service.
2. You put the token in the **token file**.
3. You run the script `Sync-TsinghuaToken.ps1`. The script moves the token into
   the **credential store**.
4. DSH reads the token from the credential store. DSH reads the token again for
   each request.

The **patch file** holds the route configuration. The patch file holds only the
**name** of the credential. The patch file never holds the token itself.

This design has two important results:

* You must replace the token every 24 hours. You do not change the patch file.
* You can give the patch file to an other person. The patch file contains no
  secret data.

### The token lifecycle

The Tsinghua service gives a token that is valid for 24 hours. After 24 hours,
the service refuses the token. Then DSH shows an authentication error.

The **token file** is the one place for the manual step. You copy the new token
into this file. The script does the rest.

## Section 1: Configure the route for the first time

Do these steps one time on each computer.

### Step 1: Get the token

1. Start a browser.
2. Open the Tsinghua DeepSeek model system.
3. Log in with your school account.
4. Find the page that shows the token. The page usually has a **Copy** button.
5. Copy the complete token.

**Note:** The token is a long string of letters, digits, dots, and hyphens. The
usual length is between 200 and 400 characters. The token has three parts that
dots separate.

**Caution:** Do not put the token in an email, a chat message, or a document
that other persons can read. The token is a password for your school account.

### Step 2: Make the token file

1. Open a text editor. Use Notepad on Windows.
2. Paste the token.
3. Do not add a second line. Do not add quotation marks.
4. Save the file as plain text with the name `tsinghua_token.txt`.

Put the file near the script `Sync-TsinghuaToken.ps1`. The default path is the
same folder as the script.

**Note:** The token file must have the UTF-8 encoding. Notepad uses UTF-8 by
default.

### Step 3: Stop the DSH Desktop application

1. Close the DSH Desktop window.
2. Make sure that the process stops. Open Task Manager and look for the process
   `DeepSeek Harness`.

**Note:** This step is safe, but it is not always necessary. The application
reads the credential store again for each request. Stop the application if you
have a problem.

### Step 4: Find the harness home

1. Open a terminal. Use Windows PowerShell on Windows.
2. Type this command:

```powershell
$env:USERPROFILE + "\.dsh"
```

3. Look at the result. This folder is the harness home.
4. Make sure that the file `.credentials.yaml` is in this folder.

**Note:** If the file `.credentials.yaml` is not there, start DSH Desktop one
time and close it again. The application makes the file at the first start.

### Step 5: Make a copy of the old files

1. Type these commands. Replace `<HARNESS HOME>` with your harness home.

```powershell
$h = "<HARNESS HOME>"
Copy-Item "$h\.credentials.yaml" "$h\.credentials.yaml.before-tsinghua"
Copy-Item "$h\profiles\desktop\cordis.patch.yml" "$h\profiles\desktop\cordis.patch.yml.before-tsinghua"
```

2. Look at the two new files. The two files are your rollback data.

### Step 6: Put the token in the credential store

1. Open a terminal in the folder that holds the script.
2. Type this command to test the token. This command does not write data:

```powershell
.\Sync-TsinghuaToken.ps1 -DryRun
```

3. Look at the result. The result shows the token length, the expiry time, and a
   fingerprint. The result does not show the token.
4. Make sure that the expiry time is in the future. The time left must be more
   than 0 minutes.
5. Type this command to write the token:

```powershell
.\Sync-TsinghuaToken.ps1
```

6. Look for this line in the result:

```
Result          : OK.
```

**If the result is not OK, go to Section 5.**

**Note:** The script makes a backup copy of the credential store before each
write. The script keeps all other credential entries.

### Step 7: Add the route to the patch file

1. Open the file `<harness home>\profiles\desktop\cordis.patch.yml` in a text
   editor.
2. Find the top-level list. The list has entries that start with `- id:`.
3. Add these two entries. Put each entry at the first position of the list. Do
   not change the other entries.

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

**Note:** The file `cordis.patch.yml.example` in this repository holds the same
text. You can copy the text from that file.

4. Save the file.

**Caution:** YAML uses spaces for the indentation. Do not use the Tab key. Keep
the same indentation as the example.

### Step 8: Set the default model (optional)

The route works without this step. Do this step if you want the Tsinghua model
for each new session.

1. Find the entry `agent-default-model` in the patch file.
2. Set the fields to these values:

```yaml
- id: agent-default-model
  name: "@deepseek-ai/dsh-agent-default-model"
  config:
    provider: tsinghua
    model: DeepSeek-V4.1-Flash
    reasoningEffort: high
```

**Note:** The token expires every 24 hours. A default model that points to an
expired token causes an error in each new session. Use the model selector
instead if you want a safe default.

### Step 9: Start the application and test the route

1. Start DSH Desktop.
2. Open the model selector.
3. Look for the group **Tsinghua DeepSeek**.
4. Look for the model **Tsinghua_DeepSeek_v41**.
5. Select the model.
6. Look at the context value of the model. The value must be **1M** or
   **1,048,576**.
7. Look at the effort control. The control must show **Off**, **Low**,
   **High**, and **Max**.
8. Send a message to the model. For example: "Read the file README.md".
9. Look at the answer. An answer that uses a tool shows that the route is
   correct.

## Section 2: Replace the token (each 24 hours)

The token expires every 24 hours. Do these steps after each expiry.

1. Get a new token. See Section 1, Step 1.
2. Put the new token in the token file. See Section 1, Step 2. Replace the old
   text fully.
3. Type this command:

```powershell
.\Sync-TsinghuaToken.ps1
```

4. Look for this line in the result:

```
Result          : OK.
```

5. Continue your work. A restart of the application is not necessary.

**Note:** Do not change the patch file in this procedure.

### Find the expiry time

Type this command to see the time that is left:

```powershell
.\Sync-TsinghuaToken.ps1 -DryRun
```

The line `Time left` shows the minutes.

## Section 3: Move the configuration to an other computer

The patch file contains no secret data. You can move the patch file to an other
computer and an other user.

Do these steps on the new computer:

1. Copy these files to the new computer:
   * `cordis.patch.yml` → the profile folder of the new harness home
   * `Sync-TsinghuaToken.ps1` → any folder
2. Start DSH Desktop one time. Close it again. The application makes the
   credential store.
3. Get your own token from the Tsinghua service.
4. Make the token file. See Section 1, Step 2.
5. Run the script:

```powershell
.\Sync-TsinghuaToken.ps1
```

6. Start DSH Desktop and test the route. See Section 1, Step 9.

**Note:** Each user needs an own token. The patch file is safe to move. The
credential store is not safe to move.

**Note:** The token references the user account. Do not run the script of an
other user with your token file.

## Section 4: Understand the configuration values

This section explains the important values in the patch file.

| Field | Value | Function |
|---|---|---|
| `apiKeyEnv` | `TSINGHUA_DEEPSEEK_API_KEY` | The name of the credential. The name must be the same in the credential store. |
| `api` | `openai-completions` | The protocol of the service. This value is necessary at the **route** level. |
| `baseURL` | `https://madmodel.cs.tsinghua.edu.cn/v1` | The address of the service. |
| `reasoning` | `high` | The default thinking level for the route. |
| `contextWindow` | `1048576` | The maximum input size. Section 4.1 gives the source of this value. |
| `maxTokens` | `131072` | The maximum output size. |
| `reasoningEfforts` | four entries | The thinking levels in the user interface. |
| `thinkingFormat` | `openai` | The field that the service accepts for the thinking level. |

### 4.1 The context value

The maximum context of the endpoint is **1,048,576 tokens**. This value is the
sum of the input tokens and the output tokens.

The value 1,048,576 is a measured value. The endpoint accepted these input
sizes:

| Input tokens | Result |
|---|---|
| 400,853 | Accepted |
| 600,919 | Accepted |
| 1,000,136 | Accepted |
| more than 1,048,576 | Refused with HTTP 400 |

The endpoint gave this message:

```
This model's maximum context length is 1048576 tokens
max_model_len=max_total_tokens=1048576
```

The text `reasoning_effort` accepts the values `low`, `high`, and `max`. The
text `none` stops the thinking. The endpoint refuses the values `minimal`,
`medium`, and `xhigh`.

**Note:** The input and the output use the same limit. Do not set the two values
`contextWindow` and `maxTokens` both to 1,048,576.

## Section 5: Repair a problem

### The model group is not in the model selector

Do these steps:

1. Make sure that the entry `llm-pi-ai` is in the patch file.
2. Make sure that the entry has the field `api: openai-completions` at the
   **route** level. The field at the model level does not work.
3. Save the file. The application reads the file again automatically.
4. Open the model selector again.

### The application shows an authentication error

The token is not correct or not in the credential store.

Do these steps:

1. Type this command:

```powershell
.\Sync-TsinghuaToken.ps1 -DryRun
```

2. Look at the line `Time left`. If the value is negative, get a new token.
3. Make sure that the name in the credential store is
   `TSINGHUA_DEEPSEEK_API_KEY`. Make sure that the name in the patch file is the
   same.
4. Run the script again.

### The token is refused directly after a new copy

The token is probably not complete. Do these steps:

1. Copy the token again. Use the **Copy** button of the service page.
2. Do not use the mouse to select the text. A mouse selection can lose one or
   two characters.
3. Put the new text in the token file. Replace the old text fully.
4. Run the script again.

### The script shows "Could not restrict the file permissions"

This message is not important. Windows needs administrator rights to change the
access control list of some files. The credential store is already safe for the
usual configurations.

### The context value is 262K

The value 262,144 is the default value of DSH for an unknown model. Do these
steps:

1. Make sure that the field `contextWindow` is in the **model** entry. The value
   must be `1048576`.
2. Make sure that the entry `llm-pi-ai` is in the patch file.
3. Close the model selector. Open it again.

### Return to the old configuration

1. Find the backup files. The names end with `.before-tsinghua`.
2. Copy the backup file over the current file.
3. Start DSH Desktop again.

## Section 6: Safety rules

Obey these rules:

* Keep the token in the token file and in the credential store only.
* Do not put the token in the patch file.
* Do not put the token in a git repository.
* Do not put the token in a chat message or a log.
* Make sure that the patch file contains no personal data. A patch file with
  personal data is not safe to share.
* Delete an old token file after the token expires.

## Section 7: Technical data

| Item | Value |
|---|---|
| Endpoint | `https://madmodel.cs.tsinghua.edu.cn/v1` |
| Protocol | OpenAI Chat Completions |
| Model id at the endpoint | `DeepSeek-V4.1-Flash` |
| Model name in DSH | `Tsinghua_DeepSeek_v41` |
| Route id | `tsinghua` |
| Credential name | `TSINGHUA_DEEPSEEK_API_KEY` |
| Token life | 24 hours |
| Maximum context | 1,048,576 tokens |
| Output limit | 131,072 tokens |
| Thinking levels | Off, Low, High, Max |
| Function calling | Supported, streaming and not streaming |
| Rate limit | 30,000 requests for each minute |

## Glossary

| Term | Meaning |
|---|---|
| endpoint | The network address that gives the model service. |
| effort | The amount of thinking that the model does before the answer. |
| fingerprint | A short code that identifies a value. The code does not show the value. |
| JWT | JSON Web Token. The token format of the Tsinghua service. |
| patch file | The configuration file of the profile. See "Words in this document". |
| route | The DSH configuration that points to one model service. |
| token | The login credential of the Tsinghua service. |
