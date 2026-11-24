// Adds the Wear OS watch app (native/wear) to the generated Android project as the :wear module.
// Runs after `npx cap add android` / `npx cap sync android`, in both Android workflows. Safe to run again.
import { cpSync, existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";

const src = new URL("../wear/", import.meta.url);
const dest = new URL("../android/wear/", import.meta.url);
const settings = new URL("../android/settings.gradle", import.meta.url);

if (!existsSync(settings)) {
  console.error("android/settings.gradle not found: run `npx cap add android` first");
  process.exit(1);
}
rmSync(dest, { recursive: true, force: true });
cpSync(src, dest, { recursive: true });
const text = readFileSync(settings, "utf8");
if (!/include ':wear'/.test(text)) writeFileSync(settings, text.trimEnd() + "\ninclude ':wear'\n");
console.log("android/wear: Wear OS app added (include ':wear')");
