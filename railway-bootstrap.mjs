// First-boot helper for railway-start.sh.
//   check  - exit 0 when the instance has no account yet (needs the admin), 1 otherwise
//   create - waits for the loopback instance and registers ADMIN_EMAIL as the first
//            account (Flowplan makes the first account the administrator)
import { existsSync } from "node:fs";
import { resolve } from "node:path";

const mode = process.argv[2];
const dir = process.env.FLOWPLAN_DATA_DIR || "/app/data";

if (mode === "check") {
  const file = resolve(dir, "flowplan.sqlite");
  if (process.env.DATABASE_URL?.startsWith("postgres")) {
    console.error("railway-bootstrap: PostgreSQL is set; create the first account with the setup link instead.");
    process.exit(1);
  }
  if (!existsSync(file)) process.exit(0);
  const { DatabaseSync } = await import("node:sqlite");
  let n = 0;
  try {
    const db = new DatabaseSync(file, { readOnly: true });
    n = Number(db.prepare("SELECT COUNT(*) AS n FROM users WHERE subject<>'local-development'").get().n);
    db.close();
  } catch (e) {
    // No users table yet: a database from an interrupted first start.
    if (!/no such table/i.test(String(e?.message))) {
      console.error("railway-bootstrap: cannot read the database:", e?.message);
      process.exit(2);
    }
  }
  process.exit(n > 0 ? 1 : 0);
}

if (mode === "create") {
  const port = process.env.BOOT_PORT || "39123";
  const base = `http://127.0.0.1:${port}`;
  const origin = new URL(process.env.APP_URL).origin;
  const deadline = Date.now() + 240_000;
  let up = false;
  while (Date.now() < deadline) {
    try {
      const r = await fetch(`${base}/api/health`, { signal: AbortSignal.timeout(5000) });
      if (r.ok) { up = true; break; }
    } catch {}
    await new Promise((r) => setTimeout(r, 1000));
  }
  if (!up) {
    console.error("railway-bootstrap: Flowplan did not answer on the loopback port within 4 minutes.");
    process.exit(1);
  }
  const r = await fetch(`${base}/api/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json", origin, "x-forwarded-for": "127.0.0.1" },
    body: JSON.stringify({
      name: process.env.ADMIN_NAME || "Admin",
      email: process.env.ADMIN_EMAIL,
      password: process.env.ADMIN_PASSWORD,
      setup: process.env.FLOWPLAN_SETUP_TOKEN,
    }),
  });
  const text = await r.text();
  if (!r.ok) {
    console.error(`railway-bootstrap: sign-up answered ${r.status}: ${text.slice(0, 300)}`);
    process.exit(1);
  }
  console.log(`railway-bootstrap: administrator ${process.env.ADMIN_EMAIL} created.`);
  process.exit(0);
}

console.error("usage: railway-bootstrap.mjs check|create");
process.exit(64);
