<!-- School Food Supply Chain Sankey Chart -->
<script setup>
import { computed, ref, watch } from "vue";
import { useAuthStore } from "../../store/authStore";
import sankeyData from "../../assets/data/sankey-school-food.json";

const authStore = useAuthStore();

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

// ── AI Analysis Panel ──────────────────────────────────────────────────────
const showAIPanel = ref(false);
const aiAnalyzing = ref(false);
const aiText = ref("");

function buildSankeyContext() {
	const l = layout.value;
	const cityLabel = selectedCity.value === "全部" ? "雙北市" : selectedCity.value;
	const distLabel = selectedDistrict.value === "全部" ? "全部區域" : selectedDistrict.value;
	const dateRange = `${allDates[startIdx.value]} 至 ${allDates[endIdx.value]}`;
	const lines = [
		`篩選條件：城市=${cityLabel}，區域=${distLabel}，層級=${selectedLayer.value}，日期範圍=${dateRange}`,
	];
	if (l.nodes0.length) {
		lines.push("\n【上游原料供應商 Top 節點（依供餐次數）】");
		l.nodes0.slice(0, 10).forEach((n) => lines.push(`  ${n.name}：${n.flow.toLocaleString()} 次`));
	}
	if (l.nodes1.length) {
		lines.push("\n【中游供餐業者 Top 節點（依供餐次數）】");
		l.nodes1.slice(0, 10).forEach((n) => lines.push(`  ${n.name}：${n.flow.toLocaleString()} 次`));
	}
	if (l.nodes2.length) {
		lines.push("\n【下游學校 Top 節點（依供餐次數）】");
		l.nodes2.slice(0, 10).forEach((n) => lines.push(`  ${n.name}：${n.flow.toLocaleString()} 次`));
	}
	return lines.join("\n");
}

async function runSankeyAnalysis() {
	aiAnalyzing.value = true;
	aiText.value = "";
	const baseUrl = import.meta.env.VITE_API_URL || "/api/v1";
	const context = buildSankeyContext();
	try {
		const response = await fetch(`${baseUrl}/ai/chat/twai`, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				Authorization: `Bearer ${authStore.token || ""}`,
			},
			body: JSON.stringify({
				stream: true,
				messages: [
					{
						role: "system",
						content:
							"你是雙北學校供餐供應鏈分析助手。根據使用者提供的桑基圖當前顯示數據，以繁體中文輸出分析報告。報告格式固定如下，不可省略任何段落：\n\n【供應鏈概況】\n說明整體供應鏈規模，包含上中下游主要節點與供餐次數。\n\n【關鍵上游供應商】\n列出最重要的原料供應商，說明其在供應鏈中的影響範圍與重要性。\n\n【核心供餐業者】\n列出主要供餐業者，說明其服務規模及連結的下游學校數量。\n\n【集中度風險分析】\n分析供應鏈集中度，指出若某節點失效可能波及的學校範圍及潛在食安風險。\n\n【管理建議】\n針對供應鏈透明度與食安管理給出具體改善建議。\n\n最後一句綜合結論。",
					},
					{
						role: "user",
						content: `以下是目前桑基圖顯示的供應鏈數據，請分析並輸出報告：\n\n${context}`,
					},
				],
				max_new_tokens: 1500,
			}),
		});
		if (!response.ok) {
			aiText.value = `分析失敗：${await response.text() || response.statusText}`;
			return;
		}
		const reader = response.body.getReader();
		const decoder = new TextDecoder();
		while (true) {
			const { done, value } = await reader.read();
			if (done) break;
			aiText.value += decoder.decode(value, { stream: true });
		}
	} catch (e) {
		aiText.value = `錯誤：${e.message}`;
	} finally {
		aiAnalyzing.value = false;
	}
}

function openAIPanel() {
	showAIPanel.value = true;
	if (!aiText.value && !aiAnalyzing.value) runSankeyAnalysis();
}

function refreshAIAnalysis() {
	aiText.value = "";
	runSankeyAnalysis();
}

function renderAIText(text) {
	return text
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/【(.+?)】/g, '<span class="skai-heading">【$1】</span>')
		.replace(/\n\n+/g, "</p><p>")
		.replace(/\n/g, "<br>")
		.replace(/^/, "<p>")
		.replace(/$/, "</p>")
		.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
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
          <button class="skai-trigger-btn" title="AI 解讀此供應鏈圖" @click="openAIPanel">
            <span class="material-icons-outlined" style="font-size:0.9rem;vertical-align:middle;">auto_awesome</span>
            AI 解讀
          </button>
        </div>
      </div>

      <!-- AI Analysis Panel -->
      <Teleport to="body">
        <div v-if="showAIPanel" class="skai-overlay" @click.self="showAIPanel = false">
          <div class="skai-panel">
            <div class="skai-header">
              <span class="material-icons-outlined">auto_awesome</span>
              <h3>供應鏈 AI 分析報告</h3>
              <div class="skai-header-actions">
                <button :disabled="aiAnalyzing" title="重新分析" @click="refreshAIAnalysis">
                  <span class="material-icons-outlined">refresh</span>
                </button>
                <button @click="showAIPanel = false">
                  <span class="material-icons-outlined">close</span>
                </button>
              </div>
            </div>
            <div class="skai-body">
              <div v-if="aiAnalyzing && !aiText" class="skai-loading">
                <div class="skai-spinner" />
                <p>AI 正在分析供應鏈數據，請稍候…</p>
              </div>
              <div
                v-else
                class="skai-content"
                v-html="renderAIText(aiText || '（無回應）')"
              />
            </div>
          </div>
        </div>
      </Teleport>

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
  overflow: visible; // override DashboardComponent's * { overflow: hidden }
}

// ── Controls ────────────────────────────────────────────────────────────────
.sankey-controls,
.table-controls {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0 0.5rem;
  flex-shrink: 0;
  flex-wrap: wrap;
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

// ── AI Panel ─────────────────────────────────────────────────────────────────
.skai-trigger-btn {
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 2px 10px;
  border-radius: 4px;
  border: 1px solid var(--color-highlight, #5b9fe8);
  background: transparent;
  color: var(--color-highlight, #5b9fe8);
  cursor: pointer;
  font-size: 0.72rem;
  font-weight: 600;
  transition: background 0.15s;
  &:hover { background: rgba(91,159,232,0.12); }
}

.skai-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.skai-panel {
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: 0.75rem;
  width: min(720px, 90vw);
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.skai-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem 1.2rem;
  border-bottom: 1px solid var(--color-border);
  .material-icons-outlined:first-child { color: var(--color-highlight); }
  h3 { flex: 1; margin: 0; font-size: var(--font-m); color: var(--color-text); }
  &-actions {
    display: flex;
    gap: 0.25rem;
    button {
      background: none;
      border: none;
      cursor: pointer;
      color: var(--color-complement-text);
      padding: 0.25rem;
      border-radius: 0.25rem;
      display: flex;
      align-items: center;
      &:hover { background: var(--color-border); }
      &:disabled { opacity: 0.4; cursor: default; }
    }
  }
}

.skai-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.2rem;
}

.skai-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 2rem;
  p { color: var(--color-complement-text); font-size: var(--font-s); }
}

.skai-spinner {
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  border: 3px solid var(--color-border);
  border-top-color: var(--color-highlight);
  animation: skai-spin 0.7s linear infinite;
}

@keyframes skai-spin { to { transform: rotate(360deg); } }

.skai-content {
  word-break: break-word;
  font-size: 1.1rem;
  color: var(--color-text);
  line-height: 1.9;
  :deep(p) { margin: 0 0 1rem; font-size: 1.1rem; &:last-child { margin-bottom: 0; } }
  :deep(strong) { color: var(--color-highlight); }
  :deep(.skai-heading) { color: var(--color-highlight); font-weight: 700; }
}

// ── Table view ───────────────────────────────────────────────────────────────
.supply-table-wrap {
  flex: 1;
  overflow-x: auto;
  overflow-y: auto;
  padding: 0 0.5rem;
  min-height: 0;
}

.supply-table {
  min-width: 100%;
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
    white-space: nowrap;
  }

  td {
    padding: 5px 10px;
    border-bottom: 1px solid rgba(255,255,255,0.05);
    color: var(--color-text, #ddd);
    vertical-align: middle;
    white-space: nowrap;
  }

  tr:hover td { background: rgba(255,255,255,0.04); }

  .count-cell {
    text-align: right;
    font-variant-numeric: tabular-nums;
    color: var(--color-complement-text, #5b8db8);
  }
}
</style>
