<!-- School Food Supply Chain Sankey Chart -->
<script setup>
import { computed, ref, watch } from "vue";
import sankeyData from "../../assets/data/sankey-school-food.json";

// ── Dates extracted once at module load ──────────────────────────────────────
const allDates = [
	...new Set(sankeyData.links.flatMap((l) => Object.keys(l.dates || {}))),
].sort();

// ── Constants ──────────────────────────────────────────────────────────────
const NODE_W = 18;
const GAP = 4;
const PAD_TOP = 38;
const PAD_BOTTOM = 6;
const SVG_W = 1280;
const SVG_H = 420;
const AVAILABLE_H = SVG_H - PAD_TOP - PAD_BOTTOM;
const X = [155, 560, 1105];
const TOP_N_GLOBAL = 14;
const TOP_N_DISTRICT = 30;

const CITY_COLOR = { 臺北市: "#5b9fe8", 新北市: "#f59e0b" };
const FALLBACK_COLOR = "#888888";

const LAYERS = [
	{ key: "全部", label: "全部" },
	{ key: "上游", label: "上游" },
	{ key: "下游", label: "下游" },
];

// ── Props ──────────────────────────────────────────────────────────────────
const props = defineProps({
	mode: { type: String, default: "default" },
});

// ── State ──────────────────────────────────────────────────────────────────
const selectedCity = ref("全部");
const selectedDistrict = ref("全部");
const selectedLayer = ref("全部");
const hoveredTooltip = ref(null);
const startIdx = ref(0);
const endIdx = ref(allDates.length - 1);
const tableLayer = ref("up-mid");

watch(startIdx, (v) => { if (v > endIdx.value) endIdx.value = v; });
watch(endIdx, (v) => { if (v < startIdx.value) startIdx.value = v; });

const isFullRange = computed(
	() => startIdx.value === 0 && endIdx.value === allDates.length - 1
);

const sliderFillStyle = computed(() => {
	const n = Math.max(allDates.length - 1, 1);
	const left = (startIdx.value / n) * 100;
	const right = 100 - (endIdx.value / n) * 100;
	return { left: `${left}%`, right: `${right}%` };
});

function dateLabel(d) {
	return d.slice(5); // "03/02"
}

// ── Effective value for a link given selected date range ───────────────────
function effectiveValue(link) {
	if (isFullRange.value) return link.value;
	let sum = 0;
	for (let i = startIdx.value; i <= endIdx.value; i++) {
		sum += link.dates?.[allDates[i]] || 0;
	}
	return sum;
}

// ── Derived filter options ──────────────────────────────────────────────────
const districtOptions = computed(() => {
	const base = selectedCity.value === "全部"
		? sankeyData.links
		: sankeyData.links.filter((l) => l.city === selectedCity.value);
	const dists = new Set(
		base.filter((l) => l.layer === "mid-down" && l.district).map((l) => l.district)
	);
	return ["全部", ...[...dists].sort()];
});

function onCityChange() {
	selectedDistrict.value = "全部";
}

// ── Data pipeline ──────────────────────────────────────────────────────────
const filteredLinks = computed(() => {
	let links = sankeyData.links;
	if (selectedCity.value !== "全部") {
		links = links.filter((l) => l.city === selectedCity.value);
	}
	if (selectedDistrict.value !== "全部") {
		const activeCaterers = new Set(
			links
				.filter((l) => l.layer === "mid-down" && l.district === selectedDistrict.value)
				.map((l) => l.source)
		);
		links = links.filter((l) =>
			l.layer === "mid-down"
				? l.district === selectedDistrict.value
				: activeCaterers.has(l.target)
		);
	}
	return links;
});

// Table rows for MoreInfo view
const tableRows = computed(() => {
	const links = filteredLinks.value.filter((l) => l.layer === tableLayer.value);
	return links
		.map((l) => ({ ...l, eff: effectiveValue(l) }))
		.filter((l) => l.eff > 0)
		.sort((a, b) => b.eff - a.eff)
		.slice(0, 200);
});

const layout = computed(() => buildLayout(filteredLinks.value, selectedLayer.value));

function buildLayout(links, layerFilter) {
	const upMid = layerFilter !== "下游" ? links.filter((l) => l.layer === "up-mid") : [];
	const midDown = layerFilter !== "上游" ? links.filter((l) => l.layer === "mid-down") : [];

	const flow0 = new Map();
	const flow1mid = new Map();
	const flow1down = new Map();
	const flow2 = new Map();

	for (const l of upMid) {
		const v = effectiveValue(l);
		if (v <= 0) continue;
		flow0.set(l.source, (flow0.get(l.source) || 0) + v);
		flow1mid.set(l.target, (flow1mid.get(l.target) || 0) + v);
	}
	for (const l of midDown) {
		const v = effectiveValue(l);
		if (v <= 0) continue;
		flow1down.set(l.source, (flow1down.get(l.source) || 0) + v);
		flow2.set(l.target, (flow2.get(l.target) || 0) + v);
	}

	const flow1 = new Map();
	for (const [k, v] of flow1mid) flow1.set(k, v);
	for (const [k, v] of flow1down) flow1.set(k, Math.max(flow1.get(k) || 0, v));

	const topN = selectedDistrict.value !== "全部" ? TOP_N_DISTRICT : TOP_N_GLOBAL;

	function topNodes(flowMap) {
		return [...flowMap.entries()]
			.sort((a, b) => b[1] - a[1])
			.slice(0, topN);
	}

	const top0 = topNodes(flow0);
	const top1 = topNodes(flow1);
	const top2 = topNodes(flow2);
	const set0 = new Set(top0.map(([n]) => n));
	const set1 = new Set(top1.map(([n]) => n));
	const set2 = new Set(top2.map(([n]) => n));

	function positionNodes(topList, xPos) {
		if (topList.length === 0) return [];
		const total = topList.reduce((s, [, v]) => s + v, 0);
		const gaps = GAP * (topList.length - 1);
		const fillH = AVAILABLE_H - gaps;
		let y = PAD_TOP;
		return topList.map(([name, flow]) => {
			const h = Math.max(3, (flow / total) * fillH);
			const node = { name, flow, x: xPos, y, h };
			y += h + GAP;
			return node;
		});
	}

	const nodes0 = positionNodes(top0, X[0]);
	const nodes1 = positionNodes(top1, X[1]);
	const nodes2 = positionNodes(top2, X[2]);
	const map0 = new Map(nodes0.map((n) => [n.name, n]));
	const map1 = new Map(nodes1.map((n) => [n.name, n]));
	const map2 = new Map(nodes2.map((n) => [n.name, n]));

	function aggLinks(rawLinks, srcSet, tgtSet) {
		const agg = new Map();
		for (const l of rawLinks) {
			if (!srcSet.has(l.source) || !tgtSet.has(l.target)) continue;
			const v = effectiveValue(l);
			if (v <= 0) continue;
			const key = `${l.source}|${l.target}`;
			const entry = agg.get(key) || { source: l.source, target: l.target, value: 0, city: l.city };
			entry.value += v;
			agg.set(key, entry);
		}
		return [...agg.values()].sort((a, b) => b.value - a.value);
	}

	const linksUM = aggLinks(upMid, set0, set1);
	const linksMD = aggLinks(midDown, set1, set2);

	const usedR0 = new Map(nodes0.map((n) => [n.name, 0]));
	const usedL1 = new Map(nodes1.map((n) => [n.name, 0]));
	const usedR1 = new Map(nodes1.map((n) => [n.name, 0]));
	const usedL2 = new Map(nodes2.map((n) => [n.name, 0]));

	function linkPx(val, nodeFlow, nodeH) {
		return Math.max(1, (val / nodeFlow) * nodeH);
	}

	function bezierPath(srcNode, srcOff, tgtNode, tgtOff, lh, color, tip) {
		const x1 = srcNode.x + NODE_W;
		const y1 = srcNode.y + srcOff;
		const x2 = tgtNode.x;
		const y2 = tgtNode.y + tgtOff;
		const mx = (x1 + x2) / 2;
		return {
			d: [
				`M ${x1} ${y1}`, `C ${mx} ${y1} ${mx} ${y2} ${x2} ${y2}`,
				`L ${x2} ${y2 + lh}`, `C ${mx} ${y2 + lh} ${mx} ${y1 + lh} ${x1} ${y1 + lh}`,
				"Z",
			].join(" "),
			fill: color, tip,
		};
	}

	const paths = [];
	for (const l of linksUM) {
		const src = map0.get(l.source), tgt = map1.get(l.target);
		if (!src || !tgt) continue;
		const lh = Math.min(
			linkPx(l.value, flow0.get(l.source) || l.value, src.h),
			linkPx(l.value, flow1mid.get(l.target) || l.value, tgt.h)
		);
		const color = selectedCity.value !== "全部" ? CITY_COLOR[selectedCity.value] : CITY_COLOR[l.city] || FALLBACK_COLOR;
		paths.push(bezierPath(src, usedR0.get(l.source), tgt, usedL1.get(l.target), lh, color, `${l.source} → ${l.target}：${l.value.toLocaleString()} 次`));
		usedR0.set(l.source, usedR0.get(l.source) + lh);
		usedL1.set(l.target, usedL1.get(l.target) + lh);
	}
	for (const l of linksMD) {
		const src = map1.get(l.source), tgt = map2.get(l.target);
		if (!src || !tgt) continue;
		const lh = Math.min(
			linkPx(l.value, flow1down.get(l.source) || l.value, src.h),
			linkPx(l.value, flow2.get(l.target) || l.value, tgt.h)
		);
		const color = selectedCity.value !== "全部" ? CITY_COLOR[selectedCity.value] : CITY_COLOR[l.city] || FALLBACK_COLOR;
		paths.push(bezierPath(src, usedR1.get(l.source), tgt, usedL2.get(l.target), lh, color, `${l.source} → ${l.target}：${l.value.toLocaleString()} 次`));
		usedR1.set(l.source, usedR1.get(l.source) + lh);
		usedL2.set(l.target, usedL2.get(l.target) + lh);
	}

	return { nodes0, nodes1, nodes2, paths };
}

function truncate(str, max = 13) {
	return str.length > max ? str.slice(0, max) + "…" : str;
}

function nodeColor() {
	if (selectedCity.value !== "全部") return CITY_COLOR[selectedCity.value] || FALLBACK_COLOR;
	return "#6b8fa3";
}
</script>

<template>
  <div class="sankey-wrapper">
    <!-- ── Table view (MoreInfo dialog) ── -->
    <template v-if="mode === 'large'">
      <div class="table-controls">
        <button
          :class="['layer-btn', { 'layer-btn-active': tableLayer === 'up-mid' }]"
          @click="tableLayer = 'up-mid'"
        >上游（原料供應商 → 供餐業者）</button>
        <button
          :class="['layer-btn', { 'layer-btn-active': tableLayer === 'mid-down' }]"
          @click="tableLayer = 'mid-down'"
        >下游（供餐業者 → 學校）</button>
        <select v-model="selectedCity" class="sankey-select" @change="onCityChange">
          <option value="全部">全部縣市</option>
          <option value="臺北市">臺北市</option>
          <option value="新北市">新北市</option>
        </select>
        <select v-model="selectedDistrict" class="sankey-select">
          <option v-for="d in districtOptions" :key="d" :value="d">{{ d === "全部" ? "全部區域" : d }}</option>
        </select>
      </div>
      <div class="supply-table-wrap">
        <table class="supply-table">
          <thead>
            <tr>
              <th>{{ tableLayer === 'up-mid' ? '原料供應商' : '供餐業者' }}</th>
              <th>{{ tableLayer === 'up-mid' ? '供餐業者' : '學校' }}</th>
              <th>城市</th>
              <th>供餐次數</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in tableRows" :key="i">
              <td>{{ row.source }}</td>
              <td>{{ row.target }}</td>
              <td>{{ row.city }}</td>
              <td class="count-cell">{{ row.eff.toLocaleString() }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <!-- ── Chart view (normal) ── -->
    <template v-else>
      <!-- Controls row -->
      <div class="sankey-controls">
        <div class="layer-btn-group">
          <button
            v-for="l in LAYERS"
            :key="l.key"
            :class="['layer-btn', { 'layer-btn-active': selectedLayer === l.key }]"
            @click="selectedLayer = l.key"
          >{{ l.label }}</button>
        </div>
        <div class="sankey-selects">
          <select v-model="selectedCity" class="sankey-select" @change="onCityChange">
            <option value="全部">全部縣市</option>
            <option value="臺北市">臺北市</option>
            <option value="新北市">新北市</option>
          </select>
          <select v-model="selectedDistrict" class="sankey-select">
            <option v-for="d in districtOptions" :key="d" :value="d">{{ d === "全部" ? "全部區域" : d }}</option>
          </select>
        </div>
      </div>

      <!-- Date range slider -->
      <div class="date-slider">
        <span class="date-label">{{ dateLabel(allDates[startIdx]) }}</span>
        <div class="slider-track">
          <div class="slider-fill" :style="sliderFillStyle" />
          <input
            v-model.number="startIdx"
            type="range"
            :min="0"
            :max="allDates.length - 1"
            class="range-thumb"
          >
          <input
            v-model.number="endIdx"
            type="range"
            :min="0"
            :max="allDates.length - 1"
            class="range-thumb"
          >
        </div>
        <span class="date-label">{{ dateLabel(allDates[endIdx]) }}</span>
        <span class="date-days">{{ isFullRange ? '全部' : `${endIdx - startIdx + 1} 天` }}</span>
      </div>

      <!-- Tooltip -->
      <div v-if="hoveredTooltip" class="sankey-tooltip">{{ hoveredTooltip }}</div>

      <!-- SVG -->
      <svg :viewBox="`0 0 ${SVG_W} ${SVG_H}`" class="sankey-svg" preserveAspectRatio="xMidYMid meet">
        <text v-if="selectedLayer !== '下游'" :x="X[0] + NODE_W / 2" :y="PAD_TOP - 14" class="layer-label">原料供應商</text>
        <text :x="X[1] + NODE_W / 2" :y="PAD_TOP - 14" class="layer-label">供餐業者</text>
        <text v-if="selectedLayer !== '上游'" :x="X[2] + NODE_W / 2" :y="PAD_TOP - 14" class="layer-label">學校</text>

        <path
          v-for="(p, i) in layout.paths"
          :key="`p-${i}`"
          :d="p.d"
          :fill="p.fill"
          class="sankey-link"
          @mouseenter="hoveredTooltip = p.tip"
          @mouseleave="hoveredTooltip = null"
        />

        <g v-for="n in layout.nodes0" :key="`n0-${n.name}`">
          <rect :x="n.x" :y="n.y" :width="NODE_W" :height="n.h" :fill="nodeColor()" class="sankey-node" />
          <text :x="n.x - 5" :y="n.y + n.h / 2" text-anchor="end" dominant-baseline="middle" class="node-label">{{ truncate(n.name) }}</text>
        </g>
        <g v-for="n in layout.nodes1" :key="`n1-${n.name}`">
          <rect :x="n.x" :y="n.y" :width="NODE_W" :height="n.h" :fill="nodeColor()" class="sankey-node" />
          <text :x="n.x + NODE_W + 5" :y="n.y + n.h / 2" text-anchor="start" dominant-baseline="middle" class="node-label">{{ truncate(n.name) }}</text>
        </g>
        <g v-for="n in layout.nodes2" :key="`n2-${n.name}`">
          <rect :x="n.x" :y="n.y" :width="NODE_W" :height="n.h" :fill="nodeColor()" class="sankey-node" />
          <text :x="n.x + NODE_W + 5" :y="n.y + n.h / 2" text-anchor="start" dominant-baseline="middle" class="node-label">{{ truncate(n.name, 16) }}</text>
        </g>
      </svg>

      <!-- Legend -->
      <div class="sankey-legend">
        <span><i style="background:#5b9fe8" />臺北市</span>
        <span><i style="background:#f59e0b" />新北市</span>
      </div>
    </template>
  </div>
</template>

<style scoped lang="scss">
.sankey-wrapper {
  position: relative;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 2px;
  background: transparent;
}

// ── Controls ────────────────────────────────────────────────────────────────
.sankey-controls,
.table-controls {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0 0.5rem;
  flex-shrink: 0;
}

.layer-btn-group { display: flex; gap: 2px; }

.layer-btn {
  font-size: 0.72rem;
  padding: 2px 10px;
  border-radius: 4px;
  border: 1px solid var(--color-border, #555);
  background: var(--color-component-background, #1e1e1e);
  color: var(--color-text-secondary, #aaa);
  cursor: pointer;
  font-weight: 500;
  transition: background 0.15s, color 0.15s;
  white-space: nowrap;

  &-active {
    background-color: var(--color-complement-text, #5b8db8);
    color: white;
    border-color: transparent;
  }
}

.sankey-selects { margin-left: auto; display: flex; gap: 6px; }

.sankey-select {
  background-color: var(--color-component-background, #1e1e1e);
  color: var(--color-text, #eee);
  border: 1px solid var(--color-border, #555);
  border-radius: 4px;
  padding: 2px 6px;
  font-size: 0.72rem;
  cursor: pointer;
  &:focus { outline: none; }
}

// ── Date slider ─────────────────────────────────────────────────────────────
.date-slider {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 0.5rem;
  flex-shrink: 0;
}

.date-label {
  font-size: 0.68rem;
  color: var(--color-text-secondary, #aaa);
  white-space: nowrap;
  min-width: 38px;
}

.date-days {
  font-size: 0.68rem;
  color: var(--color-complement-text, #5b8db8);
  white-space: nowrap;
}

.slider-track {
  flex: 1;
  position: relative;
  height: 20px;
  display: flex;
  align-items: center;
}

.slider-fill {
  position: absolute;
  height: 3px;
  background: var(--color-complement-text, #5b8db8);
  opacity: 0.6;
  border-radius: 2px;
  pointer-events: none;
}

.range-thumb {
  position: absolute;
  width: 100%;
  height: 3px;
  background: transparent;
  pointer-events: none;
  -webkit-appearance: none;
  appearance: none;
  outline: none;

  &::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 13px;
    height: 13px;
    border-radius: 50%;
    background: var(--color-complement-text, #5b8db8);
    border: 2px solid #fff;
    cursor: pointer;
    pointer-events: all;
  }

  &::-moz-range-thumb {
    width: 13px;
    height: 13px;
    border-radius: 50%;
    background: var(--color-complement-text, #5b8db8);
    border: 2px solid #fff;
    cursor: pointer;
    pointer-events: all;
  }
}

// ── SVG chart ───────────────────────────────────────────────────────────────
.sankey-svg {
  flex: 1;
  width: 100%;
  min-height: 0;
  display: block;
}

.sankey-link {
  opacity: 0.45;
  transition: opacity 0.15s;
  cursor: pointer;
  &:hover { opacity: 0.8; }
}

.sankey-node { rx: 2; }

.layer-label {
  fill: var(--color-text-secondary, #aaa);
  font-size: 13px;
  text-anchor: middle;
  font-weight: 600;
  letter-spacing: 0.5px;
}

.node-label {
  fill: var(--color-text, #ddd);
  font-size: 11px;
  pointer-events: none;
}

.sankey-tooltip {
  position: absolute;
  top: 3.2rem;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(0, 0, 0, 0.85);
  color: #fff;
  padding: 4px 12px;
  border-radius: 4px;
  font-size: 0.78rem;
  pointer-events: none;
  white-space: nowrap;
  z-index: 10;
}

.sankey-legend {
  display: flex;
  gap: 1rem;
  justify-content: center;
  font-size: 0.72rem;
  color: var(--color-text-secondary, #aaa);
  flex-shrink: 0;

  span { display: flex; align-items: center; gap: 4px; }
  i { display: inline-block; width: 10px; height: 10px; border-radius: 2px; }
}

// ── Table view ───────────────────────────────────────────────────────────────
.supply-table-wrap {
  flex: 1;
  overflow-y: auto;
  padding: 0 0.5rem;
  min-height: 0;
}

.supply-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.78rem;

  th {
    position: sticky;
    top: 0;
    background: var(--color-component-background, #1e1e1e);
    color: var(--color-text-secondary, #aaa);
    font-weight: 600;
    padding: 6px 10px;
    text-align: left;
    border-bottom: 1px solid var(--color-border, #444);
  }

  td {
    padding: 5px 10px;
    border-bottom: 1px solid rgba(255,255,255,0.05);
    color: var(--color-text, #ddd);
    vertical-align: middle;
  }

  tr:hover td { background: rgba(255,255,255,0.04); }

  .count-cell {
    text-align: right;
    font-variant-numeric: tabular-nums;
    color: var(--color-complement-text, #5b8db8);
  }
}
</style>
