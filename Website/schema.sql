-- Cloudflare D1 schema for the PocketPad launch waitlist.
-- Apply with:
--   wrangler d1 execute pocketpad-waitlist --file=Website/schema.sql --remote

CREATE TABLE IF NOT EXISTS waitlist_subscribers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'subscribed',
  source TEXT NOT NULL DEFAULT 'landing',
  consent_text TEXT NOT NULL,
  consented_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  user_agent TEXT,
  country TEXT,
  ip_hash TEXT
);

CREATE INDEX IF NOT EXISTS idx_waitlist_subscribers_status
  ON waitlist_subscribers(status);

CREATE INDEX IF NOT EXISTS idx_waitlist_subscribers_created_at
  ON waitlist_subscribers(created_at);
