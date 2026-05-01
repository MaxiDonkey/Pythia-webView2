# `/git` — repository context collector for Pythia-webview2

> Purpose of this document: illustrate the user and developer value of the `/git` command in an application based on Pythia-webview2.  
> This document presents the Git plugin as a second plugin example after `/snippet`: where `/snippet` demonstrates local prompt reuse, `/git` demonstrates external context collection from a developer tool.  
> This document does not cover full plugin installation or project creation in the host application.

<br>

>[!IMPORTANT]
>
> The `/git` command is available only when the corresponding plugin is installed and loaded by the host application.  
> It also requires a configured Git working directory and a `git` executable available from the process `PATH`.  
> Without this plugin, the command is not interpreted by Pythia-webview2 and should be considered unavailable in the runtime environment.

___

<br>

## 1. Why a `/git` command?

An application that integrates an LLM becomes much more useful when it can receive real project context:

- the current branch;
- the working tree status;
- the unstaged diff;
- the staged diff;
- recent commits;
- a specific commit or object;
- blame information for a file or a line range.

Without a command plugin, a developer usually has to leave the LLM interface:

```
terminal → git diff → copy → return to LLM UI → paste → format → ask a question
```

The `/git` command turns that workflow into a controlled context-collection step that happens directly from the prompt input field.

For example:

```
/git diff
```

fills the prompt input field with the collected diff. The user can then add a question such as:

```
Could you review this diff and identify likely edge cases, regressions, or memory issues?
```

The command does not submit anything automatically. It only prepares the context. The user stays in control: they can edit, extend, or send the final prompt manually.

---

## 2. Position in the plugin examples

`/git` is the second plugin example.

The first example, `/snippet`, demonstrates a local prompt library: it stores user-defined prompt fragments, persists them locally, and writes selected snippets into the prompt input field.

`/git` demonstrates a different kind of extension: it collects context from an external developer tool, formats it, and injects it into the prompt input field.

| Plugin | Demonstrates | Context source | Main value |
|---|---|---|---|
| `/snippet` | local prompt reuse and persistence | user-authored prompt fragments | avoid retyping stable instructions |
| `/git` | external process-based context collection | Git repository state | bring live development context into the LLM workflow |

This progression matters: the goal is not to show two isolated commands, but to show that a Pythia-webview2 application can be extended with focused business plugins without modifying the core UI component.

---

## 3. What this command demonstrates

`/git` is intentionally limited from the user's point of view, but it is more advanced than a simple convenience command from an integration point of view.

It demonstrates:

1. a Pythia command with multiple Git-oriented actions;
2. controlled execution of an external tool;
3. concurrent capture of `stdout` and `stderr`;
4. timeout handling for external processes;
5. injection of generated context into the prompt input field;
6. clear user feedback for Git errors and environment errors;
7. fixed action mapping instead of arbitrary shell execution;
8. argument validation before reaching Git;
9. truncation of large outputs;
10. Markdown fenced formatting for LLM-readable context;
11. a reusable process-runner abstraction for future plugins;
12. separation between the command adapter, business service, and process execution layer.

This is therefore not only a Git sample. It is a compact example of how a developer can add a business-specific context collector to a Pythia-webview2 application.

---

## 4. Command surface

```
/git branch
/git status
/git diff [ref]
/git staged
/git log [n]
/git show <ref>
/git blame <file> [range]
```

### Quick reference

| Command | Purpose |
|---|---|
| `/git branch` | Injects the current branch name. |
| `/git status` | Injects `git status --short`. |
| `/git diff` | Injects the unstaged diff. |
| `/git diff ref` | Injects a diff against a specific reference or range. |
| `/git staged` | Injects the staged diff, equivalent to `git diff --cached`. |
| `/git log` | Injects recent commits using the default count. |
| `/git log n` | Injects the last `n` commits. |
| `/git show ref` | Injects the output of `git show <ref>`. |
| `/git blame file` | Injects blame information for a file. |
| `/git blame file range` | Injects blame information for a line range. |

The command surface is deliberately read-only. The plugin collects repository context; it does not modify the repository.

---

## 5. Central workflow: collect, edit, send

The central workflow is:

```
/git diff
```

Expected effect: the prompt input field is pre-filled with a fenced block containing the Git diff.

The user can then add the actual question:

```
Could you review this diff and identify likely edge cases, regressions, or memory issues?
```

The final prompt sent to the LLM contains both:

1. the collected repository context;
2. the user's explicit request.

This is an important product decision.

`/git diff` does not ask the LLM anything by itself. It does not auto-submit. It does not hide the collected context. It simply prepares the prompt input field and lets the user decide what to do next.

---

## 6. Command behavior by category

### 6.1. Repository state

```
/git branch
/git status
```

These commands help the user expose the current repository state to the LLM.

Typical use cases:

- confirm the active branch;
- show whether the working tree is clean;
- provide a compact overview before asking a review or debugging question.

---

### 6.2. Review context

```
/git diff
/git staged
```

These are the most important commands for code-review workflows.

Typical use cases:

- ask for a review of unstaged changes;
- ask whether staged changes are coherent before committing;
- compare what is already staged with what remains in the working tree.

Example:

```
/git staged
```

Then add:

```
Is this staged change coherent as a commit? Please identify missing tests or risky assumptions.
```

---

### 6.3. History context

```
/git log
/git log 5
/git show HEAD
/git show HEAD~1
```

These commands help the user provide historical context to the LLM.

Typical use cases:

- summarize recent commits;
- explain a particular commit;
- review the latest commit;
- compare a change with nearby history.

---

### 6.4. Investigation context

```
/git blame a.txt
/git blame a.txt 1,1
```

These commands help the user investigate where a line came from.

Typical use cases:

- understand the origin of a line;
- ask the LLM to explain a local change in historical context;
- narrow the context to a specific range instead of pasting an entire file.

---

## 7. Formatting of injected context

The plugin injects output into the prompt input field as fenced Markdown.

Example shape:

`````markdown
````diff
diff --git a/a.txt b/a.txt
...
````
`````

The sample uses a four-backtick fence.

This matters because Git diffs may contain source files, Markdown content, or examples that already contain three-backtick blocks. A four-backtick fence reduces the risk that the injected context accidentally breaks the prompt structure.

The info string depends on the command:

| Output kind | Info string |
|---|---|
| diff-like output | `diff` |
| plain textual output | `text` |

The goal is to keep the context readable both by the user and by the LLM.

---

## 8. Preparing a small demo repository

The `/git` sample is easier to test with a small repository whose state is known in advance.

Open a Windows `cmd.exe` prompt and run:

```cmd
cd C:\tmp
mkdir demo-git && cd demo-git
git init
git config user.email "test@example.com"
git config user.name "Demo"

echo "# Demo" > README.md
git add README.md
git commit -m "initial"

echo "Hello" > a.txt
git add a.txt
git commit -m "add a.txt"

echo "World" >> a.txt
git add a.txt
git commit -m "extend a.txt"

echo "Unstaged change" >> a.txt
echo "Staged change" > b.txt
git add b.txt
```

Then configure the host application with this repository root as the Git working directory:

```pascal
FGitService := TGitService.Create(FRunner, 'C:\tmp\demo-git');
```

At this point, the repository contains:

| Item | State |
|---|---|
| `README.md` | committed in the initial commit |
| `a.txt` | committed, then modified again but not staged |
| `b.txt` | newly created and staged |
| history | three commits |
| branch | `main` or `master`, depending on the local Git configuration |

This gives predictable results for the walkthrough:

| Command | Expected result |
|---|---|
| `/git branch` | current branch, usually `main` or `master` |
| `/git status` | `M a.txt` and `A b.txt` |
| `/git diff` | unstaged diff for `a.txt` |
| `/git staged` | staged diff for `b.txt` |
| `/git log 3` | the three commits |
| `/git show HEAD` | the `extend a.txt` commit |
| `/git blame a.txt` | blame output for the committed lines |

---

## 9. Progressive discovery

### 9.1. First run

```
/git branch
```

Expected result: the current branch is injected into the prompt input field.

Example:

```
main
```

or:

```
master
```

This confirms that:

- the plugin is active;
- `git` is available;
- the configured working directory is a Git repository.

---

### 9.2. Inspect repository status

```
/git status
```

Expected result with the demo repository:

```
M a.txt
A  b.txt
```

The exact spacing is Git's own `--short` format.

---

### 9.3. Inject an unstaged diff

```
/git diff
```

Expected result: a fenced `diff` block containing the unstaged modification of `a.txt`.

The user can then add:

```
Please review this change and identify possible edge cases.
```

---

### 9.4. Inject a staged diff

```
/git staged
```

Expected result: a fenced `diff` block containing the staged creation of `b.txt`.

This command exists instead of exposing `/git diff --cached`. The plugin keeps command actions explicit and avoids passing arbitrary Git options from the prompt input field.

---

### 9.5. Inspect recent history

```
/git log 3
```

Expected result: three one-line commits.

Example shape:

```
<hash> extend a.txt
<hash> add a.txt
<hash> initial
```

---

### 9.6. Show a commit

```
/git show HEAD
```

Expected result: the latest commit, including its message and diff.

Another useful example:

```
/git show HEAD~2
```

Expected result: the initial commit.

---

### 9.7. Blame a file

```
/git blame a.txt
```

Expected result: blame information for committed lines in `a.txt`.

To restrict blame to one line:

```
/git blame a.txt 1,1
```

Expected result: blame information for line 1 only.

---

## 10. Suggested walkthrough

This scenario is enough to show the command's value in a few minutes.

### Preparation

1. create the small demo repository from section 8;
2. configure the host with `C:\tmp\demo-git` as the Git working directory;
3. run the application in debug mode;
4. keep a terminal open on the repository if you want to compare with raw Git output.

### Walkthrough

| # | Command | Expected result |
|:---:|---|---|
| 1 | `/git branch` | current branch, usually `main` or `master` |
| 2 | `/git status` | short status with `a.txt` modified and `b.txt` staged |
| 3 | `/git diff` | unstaged diff for `a.txt` |
| 4 | add a review question manually | the final prompt contains diff + user question |
| 5 | `/git staged` | staged diff for `b.txt` |
| 6 | `/git log 3` | three commits |
| 7 | `/git show HEAD` | latest commit with diff |
| 8 | `/git blame a.txt 1,1` | blame for one line |

### Golden path

Run:

```
/git diff
```

Then add:

```
Could you review this diff and identify likely edge cases, regressions, or memory issues?
```

Expected result: the LLM receives a single prompt containing both the collected diff and the user's review request.

This is the main user-facing value of the plugin.

---

## 11. Safety model

The `/git` plugin is designed as a context collector, not as a general-purpose Git shell.

### 11.1. No raw Git command

There is no command like:

```
/git raw ...
```

Each exposed action maps to a fixed Git subcommand.

This keeps the plugin predictable, testable, and easier to explain.

---

### 11.2. Fixed action mapping

Examples:

| Plugin action | Git command shape |
|---|---|
| `/git status` | `git status --short` |
| `/git diff` | `git diff` |
| `/git staged` | `git diff --cached` |
| `/git log n` | `git log --oneline -n n` |
| `/git branch` | `git branch --show-current` |
| `/git show ref` | `git show ref` |
| `/git blame file range` | `git blame -L range file` |

The user can provide refs, file paths, and ranges only in the positions that the service accepts.

---

### 11.3. Option-injection protection

User-provided refs, file paths, and ranges are rejected when they start with `-`.

Rejected examples:

```
/git diff --upload-pack=evil
/git show --version
/git show -h
/git blame --output=evil.txt
/git blame a.txt -L 10
```

This policy is intentionally restrictive. A rare file name such as `-foo` is rejected. For this sample, that trade-off is acceptable because the plugin is meant to demonstrate a bounded and safe context-collection pattern.

---

### 11.4. No repository modification

The exposed actions are read-only. They inspect repository state and history, but they do not commit, reset, checkout, merge, rebase, or write files.

This keeps the demo focused on LLM context collection rather than Git automation.

---

## 12. External process execution

The plugin uses a generic shell runner abstraction instead of putting process-management code directly into the Git service.

### 12.1. `IShellRunner`

`IShellRunner` is a reusable primitive for command plugins that need to run an external process and capture its output.

It is not Git-specific. Future plugins can reuse the same idea for commands such as:

```
/npm
/docker logs
/curl
/pytest
/maven
```

### 12.2. Why stdout and stderr are read concurrently

The Windows runner captures `stdout` and `stderr` using two reader threads.

This avoids a common deadlock pattern:

1. the child process writes a lot to `stdout`;
2. the `stdout` pipe buffer fills;
3. the child blocks while writing;
4. the parent waits for the process to exit;
5. the process cannot exit because the parent is not draining the pipe.

Reading both streams concurrently makes the runner robust enough for tools that produce large outputs or error messages.

### 12.3. Timeout

The runner applies a hard timeout.

If the process takes too long, it is terminated and the partial output already captured from `stdout` and `stderr` can still be surfaced.

In the sample Git service, the default timeout is short enough for a demo-oriented interaction and can be adjusted by the host when constructing the service.

---

## 13. Encoding and Git configuration

Every Git invocation prepends configuration arguments that make output more predictable:

```
-c core.quotepath=false
-c i18n.logoutputencoding=utf-8
```

The goal is to:

- keep file names readable;
- force log output to UTF-8;
- reduce dependence on the user's global Git configuration;
- improve the quality of the text injected into the prompt input field.

The runner decodes captured output as UTF-8 using a lossy strategy so that unexpected non-UTF-8 bytes in diffs do not crash the whole command.

---

## 14. Output size and truncation

Git output can be very large, especially for diffs and history.

The sample applies a maximum injected output size:

```
200000 characters
```

When the output exceeds that limit, it is truncated and a footer is appended:

```
[output truncated to 200000 characters]
```

This protects the prompt input field and keeps the demo usable on larger repositories.

---

## 15. Empty output

An empty Git output is often meaningful.

Examples:

| Command | Possible meaning of empty output |
|---|---|
| `/git status` | clean working tree |
| `/git diff` | no unstaged diff |
| `/git staged` | nothing staged |
| `/git branch` | detached `HEAD` |

The sample should surface this case explicitly instead of injecting an invisible empty block.

Depending on host policy, this can be displayed as a warning or as command feedback such as:

```
git status --short: empty output
```

For a product-oriented demo, a friendlier message may be preferable:

```
Working tree clean
```

or:

```
No staged diff
```

The important point is to document the behavior: empty output is not the same thing as a process failure.

---

## 16. Error handling

### 16.1. Git missing from PATH

If `git` is not available from the process `PATH`, process creation fails and the system error is surfaced.

Possible messages:

```
The system cannot find the file specified
```

or on a French Windows:

```
Le fichier spécifié est introuvable
```

No separate `where git` probe is required. The actual process-launch error is already meaningful.

---

### 16.2. Invalid working directory

If the host configures a non-existing working directory:

```pascal
TGitService.Create(FRunner, 'C:\does\not\exist')
```

Expected result:

```
Git working directory does not exist: C:\does\not\exist
```

---

### 16.3. Existing folder, not a Git repository

If the working directory exists but is not a Git repository, Git itself reports the problem.

Example configuration:

```pascal
TGitService.Create(FRunner, 'C:\Windows')
```

Command:

```
/git status
```

Expected result shape:

```
fatal: not a git repository (or any of the parent directories): .git
```

---

### 16.4. Valid syntax, invalid Git object

Some values are syntactically allowed by the plugin but invalid for the current repository.

Examples:

```
/git show no_such_ref_xyz
/git diff no_such_ref
/git blame no_such_file.txt
```

The plugin lets Git decide and surfaces the resulting `stderr` message.

---

## 17. Command registry validation

Some errors are not handled by the Git service itself, but by command validation in the command registry.

| Command | Expected status |
|---|---|
| `/git status extra` | `csWrongArgCount`: one argument received, zero expected |
| `/git diff a b` | `csWrongArgCount`: two arguments received, zero or one expected |
| `/git show` | `csWrongArgCount`: zero arguments received, one expected |
| `/git blame` | `csWrongArgCount`: zero arguments received, one or two expected |
| `/git bogus` | `csUnknownAction` |

This separation matters to the developer:

- the registry validates action existence and arity;
- the plugin parses only command-level values such as `/git log n`;
- the service validates refs, file paths, ranges, working directory, process results, and Git errors.

---

## 18. Degraded scenarios

### 18.1. Invalid `/git log` argument

| Command | Expected result |
|---|---|
| `/git log abc` | error: argument must be a positive integer |
| `/git log 0` | error: argument must be a positive integer |
| `/git log -5` | error: argument must be a positive integer |
| `/git log 2.5` | error: argument must be a positive integer |
| `/git log 1` | OK, one commit |

---

### 18.2. Injection attempts

| Command | Expected result |
|---|---|
| `/git diff --upload-pack=evil` | invalid Git reference because it starts with `-` |
| `/git show --version` | invalid Git reference because it starts with `-` |
| `/git show -h` | invalid Git reference because it starts with `-` |
| `/git blame --output=evil.txt` | invalid file path because it starts with `-` |
| `/git blame a.txt -L 10` | invalid range because it starts with `-` or contains spaces |

---

### 18.3. Missing or extra arguments

| Command | Expected result |
|---|---|
| `/git status extra` | wrong argument count |
| `/git diff a b` | wrong argument count |
| `/git show` | wrong argument count |
| `/git blame` | wrong argument count |
| `/git bogus` | unknown action |

---

### 18.4. Large output

A large repository can be used to test truncation.

Example:

```cmd
cd C:\tmp
git clone --depth 5000 https://github.com/torvalds/linux.git
```

Then configure the working directory to that clone and run:

```
/git log 100000
```

Expected result: the output is injected up to the limit and ends with:

```
[output truncated to 200000 characters]
```

---

### 18.5. Timeout

For testing only, construct the service with a very small timeout:

```pascal
FGitService := TGitService.Create(FRunner, 'C:\tmp\demo-git', 1);
```

Then run:

```
/git log
```

Expected result shape:

```
Process timed out after 1 ms
```

After the test, restore a normal timeout value.

---

## 19. Host wiring note

The host application creates the service and registers the plugin.

Example shape:

```pascal
Pythia.OnRegisterCommandPlugins :=
  procedure
  begin
    FRunner := TShellRunner.Create;
    FGitService := TGitService.Create(FRunner, 'C:\tmp\demo-git');
    FGitService.Browser := Pythia;
    Pythia.CommandLine.RegisterPlugin(TGitPlugin.Create(FGitService));
  end;
```

The important design point is that the host owns the working-directory choice.

There is no implicit fallback to:

```
GetCurrentDir
ExtractFilePath(ParamStr(0))
```

The repository root is explicit. That keeps the plugin predictable and makes the demo easier to reason about.

---

## 20. Code organization

The sample is split into four units.

| Unit | Role |
|---|---|
| `Demo.Shell.Runner.pas` | generic process runner with stdout/stderr capture and timeout |
| `Demo.Git.Plugin.Intf.pas` | Git service interface and operation result type |
| `Demo.Git.Plugin.Service.pas` | Git validation, execution, formatting, truncation, and injection |
| `Demo.Git.Plugin.pas` | command adapter between Pythia command-line actions and `IGitService` |

### 20.1. `Demo.Shell.Runner.pas`

This unit provides the reusable process execution primitive.

It is responsible for:

- `CreateProcess`-based execution;
- command-line construction;
- working-directory propagation;
- stdout capture;
- stderr capture;
- concurrent pipe draining;
- timeout enforcement;
- UTF-8 decoding;
- returning a structured `TShellRunResult`.

This unit is intentionally independent from Git.

---

### 20.2. `Demo.Git.Plugin.Intf.pas`

This unit defines the business contract.

It contains:

- `TGitOperationResult`;
- `IGitService`.

The interface makes the command adapter independent from the concrete Git implementation. A future implementation could use another backend, such as a library-based Git implementation or a sandboxed runner.

---

### 20.3. `Demo.Git.Plugin.Service.pas`

This unit contains the Git-specific business logic.

It is responsible for:

- validating the working directory;
- validating refs, file paths, and ranges;
- building fixed Git command shapes;
- executing Git through `IShellRunner`;
- handling process failures and Git exit codes;
- truncating large outputs;
- formatting fenced Markdown;
- deferring prompt input injection so it lands after the runtime input reset.

---

### 20.4. `Demo.Git.Plugin.pas`

This unit is the command adapter.

It is responsible for:

- declaring the `/git` actions;
- validating action arity through `AddAction`;
- parsing `/git log n`;
- delegating execution to `IGitService`;
- translating `TGitOperationResult` into the command framework result.

It deliberately does not contain Git process code.

---

## 21. What the developer should observe

### 21.1. The developer writes business logic, not UI plumbing

The plugin developer does not need to write:

- a prompt textarea;
- button handling;
- chat rendering;
- vendor-specific LLM code;
- prompt submission logic;
- error rendering UI;
- browser message plumbing.

The developer writes a focused extension:

```
command → validation → external context collection → formatting → prompt input injection
```

That is the main technical value of the plugin model.

---

### 21.2. The component remains closed to Git-specific code

The core component does not become a Git client.

The Git-specific behavior lives in the plugin and service. The host loads that plugin when it wants Git context collection.

This keeps the main component generic while still allowing business-oriented extensions.

---

### 21.3. The process runner is reusable

The Git sample introduces a reusable external-process primitive.

The same pattern can support other plugins later:

```
/npm test
/docker logs
/curl
/pytest
/maven
/custom-tool
```

The Git plugin is therefore also an example of a reusable infrastructure piece for future command plugins.

---

### 21.4. The sample is testable

The design can be tested at several levels.

`IShellRunner` can be tested with a real Windows command:

```cmd
cmd /c echo hello
```

`TGitService` can be tested with a mock `IShellRunner` returning prebuilt `TShellRunResult` values.

`TGitPlugin` can be tested with a mock `IGitService` to verify:

- action mapping;
- `/git log n` parsing;
- wrong-arity behavior;
- unknown-action behavior.

---

### 21.5. The limits are explicit

This sample does not pretend to be a full Git client.

It documents its limits:

- no arbitrary Git command;
- no shell access;
- no repository modification;
- Git must be available from `PATH`;
- the working directory is provided by the host;
- some rare argument forms are rejected for safety;
- large output is truncated;
- empty output is surfaced explicitly.

Explicit limits are useful for an integration sample because they make the intended scope clear.

---

## 22. What the user should observe

### 22.1. Less friction

The user does not need to leave the LLM interface to collect common Git context.

Before:

```
terminal → git command → copy → prompt field → paste → question
```

After:

```
/git diff → question
```

---

### 22.2. Better prompt quality

The injected context is:

- collected from the actual repository;
- formatted as a fenced block;
- clearly separated from the user question;
- easier for the LLM to interpret.

---

### 22.3. User control is preserved

The plugin does not auto-submit.

This matters because the user may want to:

- shorten the context;
- add extra instructions;
- ask a specific review question;
- remove sensitive parts;
- cancel the request.

The command prepares the prompt; it does not replace the user's judgment.

---

### 22.4. The vocabulary is natural for developers

The command names map to familiar Git concepts:

```
branch
status
diff
staged
log
show
blame
```

The user does not need to learn a new abstract model. The command simply brings Git context into the LLM workflow.

---

## 23. Limits and possible extensions

The sample should remain read-only, but several extensions are possible.

### 23.1. Additional context collectors

Possible examples:

```
/git grep <pattern>
/git file <path>
/git changed
/git recent
/git conflicts
/git patch <ref>
```

Each new action should remain explicit and bounded.

---

### 23.2. Append mode

The current model injects one collected block into the prompt input field.

A future command could append context instead of replacing the current input, but that requires a reliable primitive to read or extend the current input field content.

Possible shape:

```
/git append diff
```

or:

```
/git diff --append
```

The second form would require revisiting the safety model because it introduces option-like syntax.

---

### 23.3. Friendlier empty-output messages

The sample can improve user experience by translating empty Git outputs into domain-specific messages:

| Command | Friendlier message |
|---|---|
| `/git status` | `Working tree clean` |
| `/git diff` | `No unstaged diff` |
| `/git staged` | `No staged diff` |
| `/git branch` | `Detached HEAD or no current branch` |

---

### 23.4. More advanced working-directory selection

The host currently provides the working directory explicitly.

A real application could provide:

- a project picker;
- a recent repositories list;
- per-conversation repository binding;
- workspace-aware configuration.

This should remain host-owned rather than hidden inside the plugin.

---

## 24. Summary

`/git` is a context-collection command for Pythia-webview2.

It is the second plugin example after `/snippet`:

- `/snippet` demonstrates local prompt reuse and persistent user-defined content;
- `/git` demonstrates external context collection from a developer tool.

The command does not turn Pythia-webview2 into a Git client. It shows how a plugin can collect useful business context, format it safely, and inject it into the prompt input field while leaving the final request under user control.

For users, this reduces friction when asking an LLM to review, explain, or summarize repository state.

For developers, it demonstrates how to extend the LLM interface with a focused, testable, business-oriented plugin without modifying the core component.

The important architectural point is simple:

```
Pythia-webview2 provides the interface.
The plugin provides the business context.
The user remains in control of the final prompt.
```
