---
name: ts-no-secrets-in-stream
description: "Never read .env or ~/.aws/* into the stream and never print credential values — probe presence with status-only checks"
condition: ["(^|[;&| ])cat \\.env($|[^a-zA-Z.])", "AWS_ACCESS_KEY_ID\\s*=|AWS_SECRET_ACCESS_KEY\\s*=", "get_credentials\\s*\\(", "\\.aws/(credentials|config)"]
scope: ["tool:bash", "tool:read(*.env)", "tool:read(*.aws/credentials)", "tool:read(*.aws/config)"]
---

Secret material must never enter the stream. `.env`, `~/.aws/credentials`, and `~/.aws/config` are secret files: never `cat`/`read`/`grep` their contents into tool output (a `cat .env` leaks every key in it, and `boto3.Session(...).get_credentials().access_key` prints a live key). If you need to know whether a credential slot is filled, run a probe that prints only status, never the value, e.g. `awk -F= '/^AWS_ACCESS_KEY_ID=/{print ($2 != "") ? "set" : "empty"}' .env` or `test -f .env && echo present`. Never print `access_key`/`secret_access_key`/token values from sessions or env vars — print `None`/`set`/`empty` at most. If real credentials are needed to proceed, ask the user to configure them and verify with a status-only probe.