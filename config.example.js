// =====================================================================
//  Supabase configuration — EXAMPLE
// =====================================================================
//  This is a placeholder for the upcoming book club sync. It is NOT yet
//  wired into the app — the club currently still saves in your browser.
//
//  WHEN YOU'RE READY TO TURN ON THE SHARED CLUB:
//    1. Copy this file to  config.local.js
//    2. Paste in your project URL and the public "anon" key from
//       Supabase → Project Settings → API
//    3. Tell Claude to wire the club section up to Supabase, and it will
//       load this config and replace the local-storage club code.
//
//  The anon key is SAFE to expose in client-side code — that's its job.
//  Security comes from the Row Level Security rules in supabase/schema.sql,
//  not from hiding this key. (Never paste the *service_role* key here.)
//
//  config.local.js is gitignored so your real values never get committed.
// =====================================================================

window.READING_ROOM_CONFIG = {
  SUPABASE_URL: "https://YOUR-PROJECT-ref.supabase.co",
  SUPABASE_ANON_KEY: "YOUR-PUBLIC-ANON-KEY",

  // "magic_link"  → people sign in with their email (named members, syncs across devices)
  // "join_code"   → simpler, no email; anyone with a club's code can join
  AUTH_MODE: "magic_link",
};
