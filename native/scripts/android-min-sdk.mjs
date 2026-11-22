// Health Connect's library (ride import, plugins/health-rides) needs Android 8.0 (API 26) or newer.
// Capacitor's Android template sets 24, so this raises minSdkVersion in the generated android/variables.gradle.
// Runs after `npx cap add android` (npm run add:android, npm run android) and in both Android workflows.
import { readFileSync, writeFileSync } from "node:fs";

const MIN = 26;
const file = new URL("../android/variables.gradle", import.meta.url);
const text = readFileSync(file, "utf8");
const m = text.match(/minSdkVersion = (\d+)/);
if (!m) {
  console.error("android/variables.gradle has no minSdkVersion line");
  process.exit(1);
}
if (+m[1] < MIN) writeFileSync(file, text.replace(m[0], `minSdkVersion = ${MIN}`));
console.log(`android/variables.gradle: minSdkVersion = ${Math.max(+m[1], MIN)}`);
