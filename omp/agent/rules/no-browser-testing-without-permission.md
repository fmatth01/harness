---
name: no-browser-testing-without-permission
description: "Never open or drive a browser/Chromium tab (browser tool open/run) to test or verify anything without explicit user permission first"
condition: "\"action\"\\s*:\\s*\"(open|run)\""
scope: "tool:browser"
---

Do NOT use the browser tool (open/run) to test, verify, or render anything unless the user explicitly asked for browser-based verification or granted permission in this conversation. Default to answering directly from docs/source, CLI tooling, static analysis, or reasoning. The user was frustrated when a headless Chromium was spun up to check mermaid layout after they'd only asked for the answer ('no need to test - just surface commands'). If browser verification would genuinely help, ask permission first and wait for approval. Browser use is allowed only for tasks the user explicitly approved (e.g., driving a UI they asked to be built or verified).