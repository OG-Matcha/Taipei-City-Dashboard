// Aggregate school food supply chain CSV into sankey-ready JSON
// Usage: node scripts/aggregate-sankey.js
import { createReadStream, writeFileSync } from "fs";
import { createInterface } from "readline";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const CSV_PATH = join(__dirname, "..", "雙北中小學及高中職供餐完整合併.csv");
const OUT_PATH = join(
  __dirname,
  "..",
  "Taipei-City-Dashboard-FE",
  "src",
  "assets",
  "data",
  "sankey-school-food.json"
);

// link key → Map<date, count>
const upMidLinks = new Map();
const midDownLinks = new Map();

let firstLine = true;

const rl = createInterface({
  input: createReadStream(CSV_PATH),
  crlfDelay: Infinity,
});

function clean(val) {
  if (!val) return "";
  return val.replace(/^="(.*)"$/, "$1").trim();
}

function addToLink(store, key, date) {
  if (!store.has(key)) store.set(key, new Map());
  const m = store.get(key);
  m.set(date, (m.get(date) || 0) + 1);
}

rl.on("line", (line) => {
  if (firstLine) { firstLine = false; return; }

  const cols = line.split(",");
  if (cols.length < 9) return;

  const city = clean(cols[0]);
  const district = clean(cols[1]);
  const school = clean(cols[2]);
  const date = clean(cols[3]); // "2026/03/02"
  const caterer = clean(cols[4]);
  const supplier = clean(cols[6]);
  const seasoningSupplier = clean(cols[9]);

  if (!city || !caterer || !school || !date) return;

  if (supplier) addToLink(upMidLinks, `${city}|${supplier}|${caterer}`, date);
  if (seasoningSupplier) addToLink(upMidLinks, `${city}|${seasoningSupplier}|${caterer}`, date);

  addToLink(midDownLinks, `${city}|${caterer}|${district}|${school}`, date);
});

rl.on("close", () => {
  const links = [];

  for (const [k, dateMap] of upMidLinks) {
    const [city, source, target] = k.split("|");
    const dates = Object.fromEntries(dateMap);
    const value = [...dateMap.values()].reduce((s, v) => s + v, 0);
    links.push({ layer: "up-mid", city, source, target, value, dates });
  }

  for (const [k, dateMap] of midDownLinks) {
    const [city, source, district, school] = k.split("|");
    const dates = Object.fromEntries(dateMap);
    const value = [...dateMap.values()].reduce((s, v) => s + v, 0);
    links.push({ layer: "mid-down", city, source, target: school, district, value, dates });
  }

  writeFileSync(OUT_PATH, JSON.stringify({ links }, null, 2), "utf-8");
  console.log(`Done. ${links.length} links written.`);
  console.log(`  up-mid: ${upMidLinks.size}, mid-down: ${midDownLinks.size}`);
});
