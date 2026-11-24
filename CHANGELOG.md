# Changelog

Every change to this template's `main` branch reaches people who deployed it as an "update available" notice on Railway. Breaking changes are listed first.

## 0.11.4 (2026-11-24)

- First release of the template: Flowplan 0.11.4 (`ghcr.io/yannicschuller/flowplan:0.11.4@sha256:2c46d5a7442928039ad5af52f47976273cc7081d1a33a5825ee7bad7bf882565`).
- SQLite database, uploads and keys on a Railway volume at `/app/data`.
- The administrator is created on first boot from `ADMIN_EMAIL` / `ADMIN_PASSWORD` while Flowplan listens only on localhost; public sign-up stays closed.
- Below 1 GB of memory: Node heap 40% of the limit, no export worker threads, OCR of scanned PDFs off (`FLOWPLAN_OCR=1` forces it on).
- Optional AI: setting `FLOWPLAN_AI_API_KEY` switches AI on for the OpenAI-compatible endpoint in `FLOWPLAN_AI_BASE_URL` / `FLOWPLAN_AI_MODEL`.
