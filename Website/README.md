# PocketPad launch site

Pixel-art landing page for PocketPad with a Cloudflare Pages Function that saves launch-list emails into Cloudflare D1.

## Files

- `index.html` / `styles.css` / `script.js` — static landing page, screenshot gallery, and launch-list form.
- `docs.html` — comprehensive PocketPad documentation for setup, pairing, editor workflows, outputs, CLI, troubleshooting, and safety behavior.
- `functions/api/subscribe.js` — Cloudflare Pages Function for `POST /api/subscribe`.
- `schema.sql` — D1 table and indexes.
- `wrangler.toml` — Pages + D1 binding config. Replace the placeholder `database_id` before deploy.
- `config.js` — optional public Turnstile site key.

## Cloudflare setup

From the repo root:

```bash
cd Website
wrangler d1 create pocketpad-waitlist
```

Copy the returned database ID into `wrangler.toml`, replacing `REPLACE_WITH_D1_DATABASE_ID`, then create the table:

```bash
wrangler d1 execute pocketpad-waitlist --file=./schema.sql --remote
```

Create the Pages project, then add a salt used for hashing IPs in consent/abuse records:

```bash
wrangler pages project create pocketpad-site --production-branch main
openssl rand -hex 32 | wrangler pages secret put IP_HASH_SALT --project-name pocketpad-site
```

Deploy to Cloudflare Pages:

```bash
wrangler pages deploy . --project-name pocketpad-site
```

For a Git-connected Pages project, set:

- Root directory: `Website`
- Build command: empty
- Build output directory: `.`
- D1 binding: `DB` → `pocketpad-waitlist`

## Optional Cloudflare Turnstile

1. Create a Turnstile widget in Cloudflare.
2. Put the public site key in `Website/config.js`.
3. Store the secret key:

```bash
wrangler pages secret put TURNSTILE_SECRET_KEY --project-name pocketpad-site
```

If `TURNSTILE_SECRET_KEY` is set, the API requires a valid Turnstile token.

## Local development

```bash
cd Website
wrangler d1 execute pocketpad-waitlist --file=./schema.sql --local
wrangler pages dev .
```

Then open the local URL shown by Wrangler. The form endpoint is `/api/subscribe`.

## Export signups

```bash
wrangler d1 execute pocketpad-waitlist \
  --remote \
  --command "SELECT email, source, consented_at, country FROM waitlist_subscribers ORDER BY created_at DESC;"
```
