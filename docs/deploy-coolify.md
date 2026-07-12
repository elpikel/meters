# Deploying to Coolify (Phoenix / Elixir)

Step-by-step notes for deploying this app (`meters`, domain `martwemetry.pl`) to a
self-hosted **Coolify** instance. Written to be reusable for the next Phoenix app —
just swap the app name, module, and domain.

Deployment model: **Dockerfile build pack** → Elixir release → Coolify's Traefik
proxy terminates TLS (Let's Encrypt) and forwards to the container on port `4000`.

---

## 0. One-time repo prep (already done here)

These files were generated with `mix phx.gen.release --docker` and are committed:

- `Dockerfile` — multi-stage build, pinned to Elixir 1.18.1 / OTP 27.3 (from `.tool-versions`). Ends with `EXPOSE 4000` + `CMD ["/app/bin/server"]`.
- `.dockerignore`
- `rel/overlays/bin/server`, `rel/overlays/bin/migrate` — start + migration scripts.
- `lib/meters/release.ex` — `Meters.Release.migrate/0` for running migrations without Mix.

The relevant prod config is already in the repo:

- `config/prod.exs` — `force_ssl`, `cache_static_manifest`, `config :swoosh, local: false`, `Swoosh.ApiClient.Req`.
- `config/runtime.exs` — reads `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`, `POOL_SIZE`, `ECTO_IPV6` from env; binds HTTP on all interfaces.

> For a brand-new app: run `mix phx.gen.release --docker`, commit, then follow from step 1.

---

## 1. Generate a secret key base

```bash
mix phx.gen.secret
```

Copy the output — it becomes the `SECRET_KEY_BASE` env var (step 5). Never commit it.

---

## 2. Push the repo somewhere Coolify can reach

Coolify deploys from a Git source: GitHub/GitLab (App or Deploy Key) or a plain Git URL.
Make sure the branch you want to deploy (e.g. `main`) is pushed and includes the
`Dockerfile`.

---

## 3. Create the Postgres database in Coolify

1. Coolify → your **Project** → **+ New** → **Database** → **PostgreSQL** (v16).
2. Give it a name (e.g. `meters-db`), pick the same **server/network** you'll deploy the app to.
3. Deploy it. Open the DB → **note the connection details**:
   - Coolify shows an **internal** connection string like
     `postgres://<user>:<pass>@<service-name>:5432/<db>`.
   - Use the **internal** host (service name) so the app talks to the DB over Coolify's
     private network — do **not** expose the DB publicly.
4. Ecto expects the `ecto://` scheme. It accepts `postgres://` too, but to be safe use:
   `ecto://<user>:<pass>@<internal-host>:5432/<db>` for `DATABASE_URL`.

> Managed external DB (Neon/Supabase/RDS) instead? Same idea, but you'll likely need
> SSL — see the SSL note in step 5.

---

## 4. Create the application resource

1. Coolify → **Project** → **+ New** → **Application** → **Public/Private Git repository**.
2. Select the repo + branch (`main`).
3. **Build Pack: `Dockerfile`** (Coolify auto-detects the `Dockerfile`).
4. **Ports Exposes:** `4000` (matches `EXPOSE`/`PORT`).
5. Put the app on the **same network/server** as the Postgres from step 3.

---

## 5. Environment variables

App → **Environment Variables**. Add:

| Variable          | Value / example                                             | Required |
|-------------------|-------------------------------------------------------------|----------|
| `SECRET_KEY_BASE` | output of `mix phx.gen.secret`                              | ✅ yes   |
| `DATABASE_URL`    | `ecto://user:pass@meters-db:5432/meters`                   | ✅ yes   |
| `PHX_HOST`        | `martwemetry.pl`                                            | ✅ yes   |
| `PORT`            | `4000` (only if you change the exposed port)               | no       |
| `POOL_SIZE`       | `10` (raise for more DB concurrency)                       | no       |
| `ECTO_IPV6`       | `true` — only if the DB is reached over IPv6              | no       |
| `DNS_CLUSTER_QUERY` | leave unset (single node)                                | no       |
| *(mailer)*        | see step 8                                                  | ⚠️ see 8 |

Notes:
- **Do not** set `PHX_SERVER` — `bin/server` (the container `CMD`) sets it for you.
- **SSL to the DB:** if your DB requires TLS (most managed providers), uncomment
  `ssl: true` in `config/runtime.exs` under `config :meters, Meters.Repo` (or append
  `?ssl=true`). Coolify's internal Postgres does **not** need it.

---

## 6. Run migrations on every deploy

Set **Pre-deployment Command** (App → General/Advanced):

```
/app/bin/migrate
```

Coolify runs this in a container of the freshly-built image **before** it swaps in the
new version, so the schema is always migrated before the app serves traffic. It calls
`Meters.Release.migrate/0`.

> First deploy only: the DB is empty; `bin/migrate` creates the schema. `ecto.create`
> is **not** needed — the database itself already exists from step 3.

---

## 7. Domain + HTTPS

1. Point DNS: an **A record** for `martwemetry.pl` (and `www` if wanted) → your Coolify
   server's public IP.
2. App → **Domains**: set `https://martwemetry.pl`. Coolify (Traefik) provisions a
   Let's Encrypt cert automatically once DNS resolves.
3. TLS is terminated at the proxy; `force_ssl: [rewrite_on: [:x_forwarded_proto]]`
   (already in `config/prod.exs`) makes Phoenix trust the `x-forwarded-proto` header.

### DNS at the registrar (home.pl)

The domain lives at **home.pl**, so the DNS records are set there — this is what makes
`martwemetry.pl` resolve to the Coolify server. Panel klienta → domain → **Strefa DNS /
Edycja DNS**:

- **A record, host `@`** (apex) → **Coolify server's public IP**. It probably points at
  home.pl parking/hosting by default — change it. This is the essential one.
- **`www`** → either an `A` record to the same IP, or a `CNAME` to `martwemetry.pl`.
- **Remove any domain parking / redirect ("przekierowanie")** and don't enable home.pl web
  hosting for the domain — you only want DNS pointing at the VPS.
- **Leave existing `MX` records** if you receive email at the domain via home.pl; changing
  the A record doesn't affect mail.
- **Mailer records (step 8):** the email provider (Resend/SMTP) gives you **SPF, DKIM, and
  DMARC** `TXT` records — add them in this same home.pl DNS zone, or lead emails from
  `noreply@martwemetry.pl` get marked as spam or rejected.
- **Lower the TTL** (e.g. 300s) before switching, then verify: `dig +short martwemetry.pl`
  must return the Coolify IP **before** Coolify can issue the SSL cert.
- No nameserver change is needed as long as the domain uses home.pl's default DNS. Find the
  server IP in Coolify (**Servers → your server**) or your VPS dashboard.

### Issuance & renewal (you do this **once**, not yearly)

- You **issue the cert once** — automatically, just by adding the domain above. There is
  no manual "issue" step and **no yearly regeneration**.
- Let's Encrypt certs last **90 days**. Coolify's proxy (Traefik/Caddy) **auto-renews**
  them ~30 days before expiry, indefinitely. You never touch this by hand.
- For auto-renewal to keep working, two things must stay true: **port 80 stays open**
  (the ACME challenge uses it) and **DNS keeps pointing at the server**. If either breaks,
  renewal fails silently and the cert expires ~90 days later.
- Only regenerate manually (Coolify → Domains → regenerate certificate) if issuance/renewal
  actually failed — see 7a.

---

## 7a. SSL / HTTPS troubleshooting (this bit us before — read it)

Coolify's proxy (Traefik/Caddy) terminates TLS and forwards **plain HTTP** to the
container on `4000`. Phoenix's `force_ssl` then redirects any request it thinks is HTTP
back to HTTPS. Most SSL problems are one of these four:

### A. Redirect loop — `ERR_TOO_MANY_REDIRECTS`
The page bounces http↔https forever. Cause: the proxy forwards HTTP internally, Phoenix
redirects to HTTPS, the proxy forwards HTTP again.
- **Fix (already in place):** `force_ssl: [rewrite_on: [:x_forwarded_proto]]` in
  `config/prod.exs` tells Phoenix to trust `X-Forwarded-Proto: https` from the proxy.
- If it still loops: confirm the Coolify **domain is set with `https://`** (not `http://`),
  and that Coolify's proxy is actually handling TLS for it (Domains tab shows a lock /
  “SSL” enabled). Traefik/Caddy send `X-Forwarded-Proto` by default — don't strip it.
- **Isolate app vs proxy:** temporarily comment out the `force_ssl` line in
  `config/prod.exs`, redeploy. If the loop stops, it's the forwarded-proto header (proxy
  side); if not, it's a Coolify redirect setting. Re-enable `force_ssl` once fixed.

### B. Cert never issued — “Not secure” / `ERR_CERT_AUTHORITY_INVALID` / Traefik default cert
Let's Encrypt couldn't complete the **HTTP-01 ACME challenge**. Checklist:
- DNS actually points at the server: `dig +short martwemetry.pl` → your Coolify IP.
  Wait for propagation before expecting a cert.
- **Ports 80 and 443 open** on the server firewall/security group. ACME needs **port 80**
  reachable — a common miss when only 443 is opened.
- Domain entered cleanly in Coolify (no trailing path, no typo).
- Only **one app** owns the domain (two resources claiming the same host breaks issuance).
- Then **redeploy** / use Coolify’s “regenerate certificate”, and check the **proxy logs**
  (Coolify → Server → Proxy → Logs) for ACME errors.

### C. Cert works for apex but not `www` (or vice-versa)
Issue a cert for **both** hostnames, or redirect one to the other.
- In Coolify **Domains**, add both `https://martwemetry.pl` and `https://www.martwemetry.pl`
  (each needs a DNS record), or add only the apex and set a `www → apex` redirect at DNS/proxy.

### D. Worked in incognito but not your normal browser — cached **HSTS**
`force_ssl` sends an HSTS header (`Strict-Transport-Security`, long `max-age`). If the site
was ever served with a bad/missing cert, the browser remembers “HTTPS only” and refuses to
load until the cert is valid.
- Test in **incognito** or another browser to confirm it's HSTS, not the server.
- Clear it at `chrome://net-internals/#hsts` (Delete domain security policies →
  `martwemetry.pl`).
- **During first setup**, you can soften HSTS until the cert is confirmed:
  `force_ssl: [rewrite_on: [:x_forwarded_proto], hsts: false]` in `config/prod.exs`, then
  re-enable HSTS once HTTPS is solid.

> Quick mental model: **redirect loop = app/header problem**, **“not secure” =
> issuance/DNS/ports problem**, **only-my-browser = HSTS cache**.

---

## 8. ⚠️ Configure a real mailer (required — the app emails on every lead)

Out of the box the mailer uses `Swoosh.Adapters.Local`, which **does not send mail in
production**. Since submitting the lead form triggers `LeadNotifier`, you must pick a
provider before going live. Two zero-hassle options:

**Option A — Resend (no new dependency; uses `Req`, already configured):**

Add to `config/runtime.exs` inside the `if config_env() == :prod do` block:

```elixir
config :meters, Meters.Mailer,
  adapter: Swoosh.Adapters.Resend,
  api_key: System.get_env("RESEND_API_KEY")
```

Then set env var `RESEND_API_KEY` in Coolify, and make sure the `from` domain in
`config/config.exs` (`noreply@martwemetry.pl`) is verified in Resend.

**Option B — SMTP (any provider):** add `{:gen_smtp, "~> 1.2"}` to `mix.exs`, then in
`config/runtime.exs`:

```elixir
config :meters, Meters.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_HOST"),
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
  tls: :always
```

Recipient/sender addresses live in `config/config.exs`
(`config :meters, Meters.Leads.LeadNotifier, to: ..., from: ...`).

---

## 9. Deploy & verify

1. Click **Deploy**. Watch the build logs (first build downloads deps + builds assets;
   later builds are cached).
2. When healthy, visit `https://martwemetry.pl` — the landing page should load.
3. Submit the form → check the lead landed in the DB and the notification email arrived.
4. Sanity-check SEO endpoints: `https://martwemetry.pl/sitemap.xml` and `/robots.txt`.

---

## 10. Redeploying / updates

- Push to `main` → Coolify redeploys (enable **auto-deploy on push** via webhook, or
  click **Redeploy**). Migrations run automatically via the pre-deployment command.
- **Rollback:** Coolify keeps previous images — use **Deployments → Rollback**. To undo a
  bad migration: `App → Terminal/Execute Command` → `/app/bin/meters eval "Meters.Release.rollback(Meters.Repo, <version>)"`.

---

## 10a. Sharing a Coolify instance with other projects

This whole guide works unchanged when the server already hosts other apps — Coolify runs
each app in its own container and the proxy routes by **domain**. Things that matter:

- **No port conflicts.** Every app can `EXPOSE 4000` / bind `PORT=4000`; containers are
  isolated and Traefik/Caddy routes by hostname, not port. Don't try to give each app a
  different port.
- **Unique domain per app.** `martwemetry.pl` here, a different host for the other project.
  Two apps must never claim the same domain (breaks cert issuance + routing).
- **Point at the *right* database.** With several Postgres services around, make sure this
  app's `DATABASE_URL` uses **its own** DB's internal service name — not the other project's.
  Keep each app + its DB in the **same Coolify Project** so it's obvious which is which.
- **Shared RAM is the real constraint.** Elixir image builds (asset build + release compile)
  are memory-hungry; two big builds at once can OOM the server. Deploy one app at a time, or
  make sure there's enough RAM/swap. Runtime memory is modest, but budget for concurrent builds.
- **One shared proxy.** A single Traefik/Caddy terminates TLS for all apps — a proxy-wide
  problem (see 7a) can affect every site, but cert issuance/renewal is still per-domain.

---

## Troubleshooting

- **`DATABASE_URL is missing` / `SECRET_KEY_BASE is missing`** → env var not set (step 5).
- **Health check fails with 301** → that's `force_ssl` redirecting http→https. Set the
  Coolify health check to accept `200-399`, or point it at the domain over https, or
  disable the container health check.
- **DB connection refused** → app and DB not on the same Coolify network, or you used the
  DB's public host instead of the internal service name.
- **`connection refused` / TLS errors to a managed DB** → enable `ssl: true` in
  `config/runtime.exs` (see step 5).
- **Assets missing / unstyled** → the image builds them via `mix assets.deploy`
  (`tailwind --minify`, `esbuild --minify`, `phx.digest`) in the Dockerfile; check the
  build logs for that step.
- **Emails not arriving** → mailer still on `Local` (step 8), or the `from` domain isn't
  verified with the provider.
