// Copies the website (one index.html plus icons) into native/www, which Capacitor packs into the apps.
// The website stays the single source of truth: edit ../index.html, then run `npm run sync`.
import { cpSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const site = join(here, "..", "..");
const www = join(here, "..", "www");

rmSync(www, { recursive: true, force: true });
mkdirSync(www, { recursive: true });

// sw.js and the manifest are left out on purpose: the apps don't use a service worker or web install
for (const f of ["index.html", "icons"]) {
  const src = join(site, f);
  if (!existsSync(src)) throw new Error(`Missing ${src}`);
  cpSync(src, join(www, f), { recursive: true });
}
console.log("Copied the website into native/www");
