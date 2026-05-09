# `/snippet` — local prompt library for Pythia-webview2

> Purpose of this document: illustrate the user and developer value of the `/snippet` command in an application based on Pythia-webview2.  
> This document does not cover plugin installation or registration in the host application.

<br>

>[!IMPORTANT]
>
> The `/snippet` command is available only when the corresponding plugin is installed and loaded by the host application.  
> Without this plugin, the command is not interpreted by Pythia-webview2 and should be considered unavailable in the runtime environment.

___

<br>

## 1. Why a `/snippet` command?

An application that integrates an LLM quickly accumulates recurring prompts:

- request a code review;
- produce a short summary;
- rephrase an answer;
- generate a technical note;
- prepare a developer-facing message;
- apply a stable business instruction before pasting variable content.

The `/snippet` command turns these recurring prompts into **local, persistent shortcuts that can be managed directly from the prompt input field**.

Instead of typing this repeatedly:

```
You are a senior Delphi reviewer. Be concise.
```

the user can save it once:

```
/snippet save review "You are a senior Delphi reviewer. Be concise."
```

and reuse it later:

```
/snippet use review
```

The prompt input field is then pre-filled with the snippet content. The user stays in control: they can edit, extend, or send the prompt manually.

---

## 2. What this command demonstrates

`/snippet` is intentionally simple from the user’s point of view, but it is interesting from an integration point of view:

1. it demonstrates a Pythia command with multiple actions;
2. it manipulates persistent state;
3. it writes into the prompt input field;
4. it provides clear user feedback: success, warning, error;
5. it illustrates centralized argument validation;
6. it exposes documented tokenizer limits;
7. it shows JSON import/export that remains useful to a developer.

This is therefore not only a convenience command. It is a compact example of what a developer can add to a Pythia-webview2 application to improve prompt workflows.

---

## 3. Command surface

```
/snippet save   <name> "<content>"
/snippet use    <name>
/snippet show   <name>
/snippet list
/snippet rename <oldName> <newName>
/snippet delete <name>
/snippet import <jsonFile>
/snippet export <jsonFile>
```

### Quick reference

| Command | Purpose |
|---|---|
| `/snippet save name "content"` | Saves or replaces a snippet. |
| `/snippet use name` | Injects the snippet content into the prompt input field. |
| `/snippet show name` | Displays the snippet content in the chat without modifying the input field. |
| `/snippet list` | Lists available snippets. |
| `/snippet rename old new` | Renames an existing snippet. |
| `/snippet delete name` | Deletes a snippet. |
| `/snippet export file.json` | Exports the current storage to a JSON file. |
| `/snippet import file.json` | Imports and merges snippets from a JSON file. |

---

## 4. Progressive discovery

### 4.1. First run

When no snippet exists yet:

```
/snippet list
```

Expected result:

```
No snippet stored
```

This message is useful because it confirms that the command is active and that the storage is empty.

---

### 4.2. Create two snippets

```
/snippet save review "You are a senior Delphi reviewer. Be concise."
```

Expected result: success, with creation of the storage file if needed.

Then:

```
/snippet save tldr "Summarize the following in 3 bullet points."
```

There are now two independent snippets:

- `review`;
- `tldr`.

An equivalent JSON file may look like this:

```json
{
    "review": "You are a senior Delphi reviewer. Be concise.",
    "tldr": "Summarize the following in 3 bullet points."
}
```

---

### 4.3. List snippets

```
/snippet list
```

Expected result: a Markdown list of available names.

Example:

```markdown
**Snippets**

- review
- tldr
```

The list intentionally shows names only. To inspect the content, use `/snippet show`.

---

### 4.4. Display a snippet without using it

```
/snippet show review
```

Expected result: a block displayed in the chat.

Example:

````markdown
**review**

~~~
You are a senior Delphi reviewer. Be concise.
~~~
````

The content is displayed inside a `~~~` fenced block so it stays readable even if the snippet contains Markdown or code.

---

### 4.5. Use a snippet

```
/snippet use review
```

Expected result: the prompt input field is pre-filled with:

```
You are a senior Delphi reviewer. Be concise.
```

This is the central behavior of the command.

`use` does not submit the prompt automatically. It also does not concatenate the snippet with the text already present. It simply places the snippet content into the input field, then lets the user edit or send it.

---

## 5. Common point of confusion: `review` and `tldr` are independent

With this storage:

```json
{
    "review": "You are a senior Delphi reviewer. Be concise.",
    "tldr": "Summarize the following in 3 bullet points."
}
```

the command:

```
/snippet use review
```

loads only the value associated with `review`.

It does not load `tldr`, and it does not load the entire JSON file.

Conversely:

```
/snippet use tldr
```

loads only:

```
Summarize the following in 3 bullet points.
```

The JSON file is therefore a **snippet library**, not an automatically composed prompt.

---

## 6. Naming and normalization

Snippet names are normalized:

- leading and trailing whitespace is removed;
- case is ignored;
- storage uses lowercase keys.

Therefore:

```
/snippet save Review "AAA"
/snippet save REVIEW "BBB"
/snippet show review
```

will display `BBB`, because `Review`, `REVIEW`, and `review` all refer to the same normalized key.

### Forbidden characters

The following characters are rejected in snippet names:

```
. [ ] / \
```

Invalid examples:

```
/snippet save my.name "x"
/snippet save my[0] "x"
/snippet save my/name "x"
/snippet save my\name "x"
```

These restrictions keep the JSON storage simple and avoid ambiguity with path syntax or JSON-reading conventions.

---

## 7. Content handling

### 7.1. Multi-word content

Multi-word content must be wrapped in quotes:

```
/snippet save x "one two three"
```

Without quotes:

```
/snippet save x one two three
```

the command receives too many arguments and fails with an arity error.

---

### 7.2. Backslashes are preserved

Windows paths are preserved:

```
/snippet save path "C:\Temp\file.txt"
```

The snippet contains exactly:

```
C:\Temp\file.txt
```

---

### 7.3. Known tokenizer limitation

The tokenizer does not support escape sequences such as `\"`.

The following command is therefore a known limitation:

```
/snippet save quote "he said \"hello\""
```

Content containing literal quotes should instead be imported from JSON, or handled by a future tokenizer improvement.

This limitation is deliberately documented: it avoids presenting the command as a full mini-language when it is meant to remain a fast prompt utility.

---

## 8. Snippet size

Two thresholds are applied per snippet:

| Size | Behavior |
|---|---|
| empty or whitespace-only content | rejected |
| up to 8192 characters | accepted |
| over 8192 characters | accepted with a warning |
| over 65536 characters | rejected |

Examples:

```
/snippet save x ""
```

Expected result:

```
Snippet content is empty
```

Very long content below the hard limit is stored with a warning:

```
Snippet "bigger" stored, content larger than 8192 characters
```

The goal is not to arbitrarily restrict the user, but to protect the prompt input field and avoid accidentally abusive prompts.

---

## 9. Persistence

Snippets are stored in a local application support JSON file:

```
<support-dir>\<AppName>-snippets.json
```

The format is intentionally flat:

```json
{
    "review": "You are a senior Delphi reviewer. Be concise.",
    "summary": "Summarize the following in 3 bullet points."
}
```

This format has several advantages:

- human-readable;
- easy to back up;
- easy to diff;
- easy to import/export;
- sufficient for a local prompt library.

### Simple persistence test

1. save two snippets;
2. completely close the application;
3. inspect the `support\<AppName>-snippets.json` file;
4. restart the application;
5. run:

```
/snippet list
```

Both snippets should still be present.

---

## 10. Rename and delete

### Rename

```
/snippet rename tldr summary
```

Expected result:

- `summary` exists;
- `tldr` no longer exists;
- the content is preserved.

Rejected cases:

```
/snippet rename a a
```

Expected result:

```
Old and new names are identical
```

```
/snippet rename a b
```

if `b` already exists:

```
Snippet "b" already exists
```

### Delete

```
/snippet delete review
```

Expected result: `review` is deleted.

If the snippet does not exist:

```
Snippet "review" not found
```

---

## 11. Export / import

### Export

```
/snippet export C:\tmp\backup.json
```

Expected result:

```
Snippets exported to C:\tmp\backup.json
```

The exported file contains the same keys and values as the current storage.

### Import

```
/snippet import C:\tmp\backup.json
```

Expected result:

```
N snippet(s) imported
```

Import merges snippets into the existing storage. In case of conflict, the imported value replaces the local value with the same normalized name.

---

## 12. Degraded import

Import accepts only a flat JSON object whose values are strings.

### Accepted example

```json
{
    "review": "You are a senior Delphi reviewer. Be concise.",
    "tldr": "Summarize the following in 3 bullet points."
}
```

### Invalid JSON format

File:

```
not json at all
```

Command:

```
/snippet import C:\tmp\bad-format.txt
```

Expected result:

```
Import file is not a JSON object
```

### Invalid value types

File:

```json
{
    "ok": "valid value",
    "wrong": 42,
    "also_wrong": ["x"]
}
```

Command:

```
/snippet import C:\tmp\bad-types.json
```

Expected result:

```
1 snippet(s) imported, 2 skipped
```

### Invalid names

File:

```json
{
    "a.b": "rejected",
    "valid": "ok",
    "with/slash": "rejected"
}
```

Command:

```
/snippet import C:\tmp\bad-names.json
```

Expected result:

```
1 snippet(s) imported, 2 skipped
```

### Missing file

```
/snippet import C:\tmp\absent.json
```

Expected result:

```
Import file not found: C:\tmp\absent.json
```

---

## 13. Command registry validation

Some errors are not handled by the snippet service itself, but by command validation.

| Command | Expected status |
|---|---|
| `/snippet save x` | `csWrongArgCount`: 1 argument received, 2 expected |
| `/snippet use` | `csWrongArgCount`: 0 arguments received, 1 expected |
| `/snippet list extra` | `csWrongArgCount`: 1 argument received, 0 expected |
| `/snippet bogus x` | `csUnknownAction` |
| `/snippeT save x "y"` | OK if the command name is normalized to lowercase |

This separation matters to the developer:

- the registry validates action existence and arity;
- the service validates names, content, files, and business logic.

---

## 14. Suggested walkthrough

This scenario is enough to show the command’s value in a few minutes.

### Preparation

1. run the application in debug mode;
2. delete the `support\<AppName>-snippets.json` file if it exists;
3. keep the `support` folder open in File Explorer.

### Walkthrough

| # | Command | Expected result |
|:---:|---|---|
| 1 | `/snippet list` | `No snippet stored` |
| 2 | `/snippet save review "You are a senior Delphi reviewer. Be concise."` | success; JSON file created |
| 3 | `/snippet save tldr "Summarize the following in 3 bullet points."` | success; two keys in the file |
| 4 | `/snippet list` | Markdown list with `review` and `tldr` |
| 5 | `/snippet show review` | fenced block containing the text |
| 6 | `/snippet use review` | input field pre-filled with the content |
| 7 | `/snippet rename tldr summary` | success; `summary` exists, `tldr` no longer exists |
| 8 | `/snippet delete review` | success; only `summary` remains |
| 9 | `/snippet list` | one entry |

### Persistence walkthrough

1. save two snippets;
2. completely close the application;
3. verify the JSON file;
4. restart the application;
5. run `/snippet list`.

The snippets should be restored.

### Export/import walkthrough

```
/snippet export C:\tmp\backup.json
```

Then delete the support file, restart the application, and run:

```
/snippet list
```

Expected result:

```
No snippet stored
```

Then:

```
/snippet import C:\tmp\backup.json
/snippet list
```

Expected result: snippets restored.

---

## 15. What the developer should observe

### 15.1. A command with immediate utility

The developer sees a command that directly improves day-to-day usage of an LLM application: it removes repetition from stable prompts.

### 15.2. A cautious UX

`/snippet use` fills the input field, but does not submit automatically. This is an important product decision: the user remains responsible for the final prompt.

### 15.3. Simple persistence

The flat JSON file is easy to inspect, back up, and version. For an integration sample, this is more transparent than opaque storage.

### 15.4. Clear separation of responsibilities

The command exposes a clear surface. The service handles:

- validation;
- normalization;
- storage;
- import/export;
- interaction with the prompt input field.

The developer can see how to add a business command without turning the main interface into a monolith.

### 15.5. Explicit limitations

The command documents its limits: no `\"` escaping in the tokenizer, no templating, no auto-submit, no secret storage.

That is a useful signal for a developer: the command is simple, but its scope is clear.

---

## 16. Limits and possible extensions

### Append

The current command replaces the input field content. An `append` action could be added, but it requires a reliable primitive to read or extend the current input field text.

Possible example:

```
/snippet append review
```

Expected effect: append the snippet to the text already present.

### Templates

A possible extension would be placeholder support:

```
Hello {{name}}, could you review this section?
```

That would be a different responsibility. Snippet storage should remain independent from a possible templating engine.

### Stricter import

The current import favors robustness: it imports valid entries and counts skipped ones. A strict version could reject the whole file at the first problem.

### Secure storage

Snippets are plain text. They should not contain secrets. API keys, tokens, and sensitive information should use dedicated secure storage.

---

## 17. Summary

`/snippet` is a small command, but it demonstrates real value for Pythia-webview2:

- it gives the user a local prompt library;
- it makes repetitive LLM workflows faster;
- it shows how a command can modify the prompt input field;
- it persists its state in readable JSON;
- it exposes a complete surface: create, read, use, rename, delete, import, export;
- it documents its limits clearly.

For an application that integrates an LLM, this command is simple enough to understand quickly and rich enough to demonstrate a real extension mechanism.

