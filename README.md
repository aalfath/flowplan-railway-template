[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/flowplan?utm_medium=integration&utm_source=button&utm_campaign=flowplan)

# Deploy and Host Flowplan on Railway

Flowplan is an open-source alternative to Notion and Confluence, licensed under AGPL-3.0. One workspace holds documents with live co-editing, databases with table, board, calendar and timeline views, whiteboards, forms, flashcards and a daily journal. It has passkeys, two-factor sign-in, SSO, and an optional AI assistant.

## About Hosting Flowplan

Flowplan runs as a single Node.js container. Pages, databases, settings and uploads all live in a SQLite database and an upload folder under `/app/data`, so that folder needs a persistent volume. This template builds the official image, pinned to Flowplan 0.11.4 by digest, from a public GitHub repo. It attaches a volume and a public HTTPS domain, and it checks `/api/health`. On first boot, the start script creates your administrator from `ADMIN_EMAIL` and a generated password while the app listens only on localhost. Public sign-up stays closed, so no visitor can claim the instance. The script also sizes Node's memory to the service, so Flowplan runs on Railway's 0.5 GB plans.

## Common Use Cases

* A team wiki and handbook with pages, comments, mentions and permissions per space
* Project and task tracking in databases with board, calendar and timeline views
* Meeting notes, whiteboards and a personal journal, with an optional AI writing assistant that uses your own key

## Dependencies for Flowplan Hosting

* A Railway volume at `/app/data` for the SQLite database, uploads and keys (included)
* Optional: an API key for OpenAI or any OpenAI-compatible provider, for the AI features

### Deployment Dependencies

* Flowplan source and releases: https://github.com/yannicschuller/flowplan (v0.11.4)
* Flowplan documentation: https://docs.flowplan.org/en
* Template repository: https://github.com/aalfath/flowplan-railway-template

### Implementation Details

**What you get:** one service, `Flowplan`, built from `aalfath/flowplan-railway-template`, with a 0.5 GB-friendly start script and a volume at `/app/data`. There is no separate database: Flowplan uses SQLite, so keep one replica.

**After deploy:**

1. Open the service's **Variables** tab and copy `ADMIN_PASSWORD`.
2. Open the public URL and sign in with `ADMIN_EMAIL` and that password. Then change the password, or add a passkey, under Settings.
3. Invite people under Settings → Members, or create accounts under Administration → Users. Public sign-up is off, and you can switch it on under Administration if you want it.

**Variables:**

* `ADMIN_EMAIL`: the administrator's sign-in address. Fill this in when you deploy.
* `ADMIN_PASSWORD`: generated, 24 characters. It is used only on the first boot.
* `APP_URL`: `https://` plus the Railway domain. If you add a custom domain, change it to that domain first, because passkeys and links are bound to the address.
* `FLOWPLAN_AI_API_KEY`, `FLOWPLAN_AI_BASE_URL` and `FLOWPLAN_AI_MODEL`: optional. Leave the key empty and AI stays off. With a key, AI is switched on for the OpenAI-compatible endpoint (default `https://api.openai.com/v1` and `gpt-4.1-mini`). You can also choose Anthropic, Gemini or Ollama later under Administration → AI.

**Memory:** below 1 GB the start script caps Node's heap at 40% of the service's memory, runs exports on the request thread, and turns off text recognition (OCR) for scanned PDFs. On 0.5 GB, the app with a few hundred pages plus PDF and EPUB exports stayed around 320 MB. For OCR, large imports or more than about 10 people working at once, give the service 1 GB or more. The caps then lift automatically, and `FLOWPLAN_OCR=1` forces OCR on.

**Optional extras** (see the Flowplan docs): SMTP for e-mail, OIDC or LDAP sign-in, and S3 backups through Litestream. Set the variables the docs name on the service.

**Updates:** when a new Flowplan release comes out, the template repo pins it and Railway shows you an "update available" notice. Read `CHANGELOG.md` in the repo before you apply it. Your data stays on the volume, and Flowplan migrates its database on start.

## Why Deploy Flowplan on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Flowplan on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

---

## About this repository

* `Dockerfile`: `FROM ghcr.io/yannicschuller/flowplan:0.11.4@sha256:2c46d5a7442928039ad5af52f47976273cc7081d1a33a5825ee7bad7bf882565` plus the start script.
* `railway-start.sh`: derives `APP_URL`, sizes memory, workers and OCR from the cgroup, creates the administrator on first boot (loopback only), then runs the upstream entrypoint. A failed bootstrap or a crash exits non-zero, so Railway's ON_FAILURE policy restarts the service.
* `railway-bootstrap.mjs`: checks whether an account exists and registers the first one.
* `OVERVIEW.md`: the Railway marketplace overview. `CHANGELOG.md`: one entry per version, with breaking changes first.

Flowplan is © its authors under the GNU AGPL-3.0. This repository only packages the unmodified upstream image for Railway.
