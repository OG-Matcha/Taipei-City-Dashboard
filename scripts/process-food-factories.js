// Process 臺北市 + 新北市 food factory CSVs into:
//   1. public/mapData/food_factory_locations.geojson  (map circle layer)
//   2. src/assets/data/food-factory-districts.json    (chart district counts)
// Usage: node scripts/process-food-factories.js
import { createReadStream, writeFileSync, mkdirSync } from "fs";
import { createInterface } from "readline";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");
const FE = join(ROOT, "Taipei-City-Dashboard-FE");

// 臺北市: REGI_ID,FACT_NAME,FACT_ADDR,BNAME,ADDR_X,ADDR_Y,City,District,經度,緯度
// 新北市: name_ins,no,address,tax_id_number,twd97x,twd97y,wgs84ax,wgs84ay,City,District
const FILES = [
  {
    path: join(ROOT, "臺北市食品工廠名單_processed.csv"),
    city: "臺北市",
    cols: { name: 1, address: 2, lng: 8, lat: 9, district: 7 },
  },
  {
    path: join(ROOT, "新北市食品工廠清冊_processed.csv"),
    city: "新北市",
    cols: { name: 0, address: 2, lng: 6, lat: 7, district: 9 },
  },
];

const features = [];
// district → { 臺北市: N, 新北市: N }
const districtCount = { 臺北市: {}, 新北市: {} };

function clean(v) {
  return (v || "").replace(/^="(.*)"$/, "$1").trim();
}

async function readCSV({ path, city, cols }) {
  return new Promise((resolve, reject) => {
    const rl = createInterface({ input: createReadStream(path), crlfDelay: Infinity });
    let first = true;
    rl.on("line", (line) => {
      if (first) { first = false; return; }
      const parts = line.split(",");
      if (parts.length < 10) return;
      const name = clean(parts[cols.name]);
      const address = clean(parts[cols.address]);
      const lng = parseFloat(clean(parts[cols.lng]));
      const lat = parseFloat(clean(parts[cols.lat]));
      const district = clean(parts[cols.district]);
      if (!name || isNaN(lng) || isNaN(lat)) return;

      features.push({
        type: "Feature",
        properties: { name, city, district, address },
        geometry: { type: "Point", coordinates: [lng, lat] },
      });

      if (district) {
        districtCount[city][district] = (districtCount[city][district] || 0) + 1;
      }
    });
    rl.on("close", resolve);
    rl.on("error", reject);
  });
}

for (const f of FILES) {
  await readCSV(f);
}

// ── Write GeoJSON ────────────────────────────────────────────────────────────
const geojson = {
  type: "FeatureCollection",
  crs: { type: "name", properties: { name: "urn:ogc:def:crs:OGC:1.3:CRS84" } },
  features,
};
const geoPath = join(FE, "public", "mapData", "food_factory_locations.geojson");
writeFileSync(geoPath, JSON.stringify(geojson), "utf-8");
console.log(`GeoJSON: ${features.length} features → ${geoPath}`);

// ── Write district counts ────────────────────────────────────────────────────
// Format: { 臺北市: [{district, count}, ...sorted desc], 新北市: [...] }
const chartData = {};
for (const [city, counts] of Object.entries(districtCount)) {
  chartData[city] = Object.entries(counts)
    .map(([district, count]) => ({ district, count }))
    .sort((a, b) => b.count - a.count);
}
const dataPath = join(FE, "src", "assets", "data", "food-factory-districts.json");
mkdirSync(join(FE, "src", "assets", "data"), { recursive: true });
writeFileSync(dataPath, JSON.stringify(chartData), "utf-8");
console.log(`District JSON: 臺北市 ${chartData["臺北市"].length} districts, 新北市 ${chartData["新北市"].length} districts`);
