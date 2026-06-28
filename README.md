# The Reading Room

A quiet, private home for your reading life — a single-page web app for tracking
books and audiobooks, saving quotes, building reading habits, setting a yearly
goal, and running a book club.

It's a **static site**: no build step, no backend required. Everything you log is
saved in your own browser, with a one-tap backup/restore file you can carry
between devices.

🔗 **Landing page:** `index.html`  ·  **The app:** `app.html` (also served at `/app`)

---

## What's in this repo

```
.
├── index.html              ← Landing page
├── app.html                ← The Reading Room app (the whole thing)
├── demo.html               ← Live demo, pre-filled with sample data (incl. a book club)
├── manifest.webmanifest    ← PWA manifest (installable to home screen)
├── sw.js                   ← Service worker (offline support)
├── netlify.toml            ← Netlify config (headers, pretty URLs)
├── robots.txt
├── icons/
│   ├── icon.svg
│   ├── icon-192.svg
│   └── icon-512.svg
├── supabase/
│   └── schema.sql          ← Book-club database schema (for later — see below)
├── config.example.js       ← Placeholder for Supabase keys (not yet wired in)
├── .gitignore
├── LICENSE
└── README.md
```

---

## Run it locally

Because the service worker and the web manifest use absolute paths (`/app.html`,
`/manifest.webmanifest`), open it through a tiny local server rather than
double-clicking the file:

```bash
# Python (already on most machines)
python3 -m http.server 8080
# then visit http://localhost:8080
```

The app itself works offline once loaded. The only feature that needs the
internet is the ISBN lookup, which calls Google Books and Open Library.

---

## Deploy

### Option A — Netlify by dragging the folder (fastest)

1. Go to [app.netlify.com](https://app.netlify.com) → **Add new site** → **Deploy manually**.
2. Drag this entire folder onto the page.
3. Netlify reads `netlify.toml` and your site is live in seconds.

### Option B — GitHub + Netlify (recommended for ongoing changes)

**1. Put it on GitHub**

```bash
git init
git add .
git commit -m "The Reading Room — initial site"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/reading-room.git
git push -u origin main
```

**2. Connect Netlify to the repo**

1. In Netlify: **Add new site** → **Import an existing project** → **GitHub**.
2. Pick your `reading-room` repo.
3. Leave the build command **empty** and set the publish directory to `.`
   (the `netlify.toml` already says this).
4. Click **Deploy**. Every push to `main` now redeploys automatically.

That's it — no environment variables needed for the current app.

### Other hosts

Any static host works the same way (GitHub Pages, Vercel, Cloudflare Pages).
Just publish the repo root. On GitHub Pages, note that the site is served from a
subpath unless you use a custom domain — if so, the absolute `/` paths in
`sw.js` and the manifest would need to become relative.

---

## Install it as an app

Once the site is live over HTTPS, visitors can install it:

- **iPhone/iPad (Safari):** Share → *Add to Home Screen*
- **Android/Desktop (Chrome/Edge):** the install icon in the address bar

It then opens full-screen and works offline.

---

## The book club (shared, optional — not yet turned on)

Right now the book club, like everything else, saves in each person's own
browser, so it's a personal organizer rather than a shared space.

To make people actually connect, this repo includes everything needed to move
**just the club** into [Supabase](https://supabase.com) while your personal
library stays local and private:

- `supabase/schema.sql` — the database tables and access rules, ready to run.
- `config.example.js` — where your Supabase keys will go.

**When you're ready:**

1. Create a Supabase project and run `supabase/schema.sql` in its SQL editor.
2. Enable an email sign-in provider (Authentication → Providers).
3. Copy `config.example.js` to `config.local.js` and paste in your project URL
   and public anon key.
4. Wire the club section of `app.html` up to Supabase (sign-in panel, create/join
   flows, live updates). The schema and config are already shaped for this.

Until step 4, nothing about your private data changes.

---

## Privacy

The Reading Room stores your library in your browser's local storage. There's no
account and no server involved in the core app. Use **Save backup** on the
dashboard to export a `.json` file, and **Load backup** to restore it anywhere.

---

## License

MIT — see [LICENSE](LICENSE).
