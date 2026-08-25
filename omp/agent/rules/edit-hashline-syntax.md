---
description: 'Edit payloads mixing legacy sparse markers (§ » ⟪⟫ ＋) with the hashline envelope (*** Begin Patch / [PATH#TAG]) are malformed under either contract and must be rejected. Pure-legacy payloads are NOT flagged: the replace contract (active for some models) uses them legitimately, and hashline sessions reject them via parser error.'
condition:
  - '(?:§|»|⟪|⟫|＋)[\s\S]{0,3000}\*\*\* Begin Patch'
  - '\*\*\* Begin Patch[\s\S]{0,3000}(?:§|»|⟪|⟫|＋)'
scope: "tool:edit(*)"
interruptMode: tool-only
---
The `edit` tool has two wire contracts. Which one is live depends on the session (hashline is the default; a model exclusion list keeps `replace` for some models). Do not assume either — match the format the session's tool actually accepts, and never mix them:

- **Hashline sessions** emit `[PATH#TAG]` sections with `PUT` / `CUT` / `REM` / `MV` operations and `+TEXT` body rows; tags come from the latest read/grep/edit output. Pure-legacy sparse payloads are rejected by the hashline parser itself — do not emit them there.
- **Replace (sparse) sessions** emit `§path` headers with `⟪old│new⟫` selections and `＋` add-lines. Pure-hashline payloads fail as literal paths (`File not found: PATH#TAG`) — do not emit them there.

This rule fires only when a payload mixes legacy markers with the hashline envelope — malformed in every session:

```text
*** Begin Patch
[src/example.ts#1A2B]
PUT 4.=4:
+const value = 2;
*** End Patch
```

Operations (hashline, line numbers refer to the original tagged snapshot):

- `PUT N.=M:` + `+TEXT` rows — replace inclusive lines N..M; body rows are final content, `+` alone inserts a blank line, literal `+`/`-` prefixes write as `++`/`+-`
- `PUT N*:` — replace the syntactic block opening at line N (anchor the opener, never a closing delimiter or blank line)
- `PUT <N:` / `PUT >N:` — insert before / after line N (`<1:` = file head, `>$:` = file tail)
- `PUT >N*:` — insert after the block opening at line N
- `CUT N.=M` / `CUT N*` — delete and capture; append `@name` to write a named register
- `PUT <N @name` / `PUT >N @name` — paste a named register into a gap
- `REM` — delete the file; `MV DEST` — move/rename after edits

Rules: sections are `[PATH#TAG]`, one per file, applied atomically top-to-bottom; untagged anchors are rejected; re-read before editing ranges not shown by the latest read; a byte-identical edit is an error. The strict envelope `*** Begin Patch` / `*** End Patch` is accepted. Use `write` to create or wholly overwrite a file.
