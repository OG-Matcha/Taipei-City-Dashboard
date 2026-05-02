<!-- Food Factory District Count Bar Chart -->
<script setup>
import { computed, ref } from "vue";
import districtData from "../../assets/data/food-factory-districts.json";

const CITY_COLOR = { 臺北市: "#5b9fe8", 新北市: "#f59e0b" };

const selectedCity = ref("全部");

const CITIES = ["全部", "臺北市", "新北市"];

const bars = computed(() => {
	if (selectedCity.value === "全部") {
		const merged = {};
		for (const [city, rows] of Object.entries(districtData)) {
			for (const { district, count } of rows) {
				merged[district] = (merged[district] || 0) + count;
			}
		}
		return Object.entries(merged)
			.map(([district, count]) => ({ district, count, city: "全部" }))
			.sort((a, b) => b.count - a.count);
	}
	return (districtData[selectedCity.value] || []).map((r) => ({
		...r,
		city: selectedCity.value,
	}));
});

const maxCount = computed(() => Math.max(...bars.value.map((b) => b.count), 1));

function barColor(city) {
	return CITY_COLOR[city] || "#6b8fa3";
}
</script>

<template>
  <div class="factory-chart">
    <div class="city-tabs">
      <button
        v-for="c in CITIES"
        :key="c"
        :class="['tab-btn', { 'tab-btn-active': selectedCity === c }]"
        @click="selectedCity = c"
      >{{ c }}</button>
    </div>
    <div class="bars-wrap">
      <div
        v-for="b in bars"
        :key="b.district"
        class="bar-row"
      >
        <span class="bar-label">{{ b.district }}</span>
        <div class="bar-track">
          <div
            class="bar-fill"
            :style="{
              width: `${(b.count / maxCount) * 100}%`,
              background: selectedCity === '全部' ? '#6b8fa3' : barColor(b.city),
            }"
          />
        </div>
        <span class="bar-count">{{ b.count }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.factory-chart {
  display: flex;
  flex-direction: column;
  height: 100%;
  width: 100%;
  gap: 6px;
  overflow: hidden;
}

.city-tabs {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}

.tab-btn {
  font-size: 0.72rem;
  padding: 2px 10px;
  border-radius: 4px;
  border: 1px solid var(--color-border, #555);
  background: var(--color-component-background, #1e1e1e);
  color: var(--color-complement-text, #aaa);
  cursor: pointer;
  transition: background 0.15s, color 0.15s;

  &-active {
    background-color: var(--color-complement-text, #5b8db8);
    color: #fff;
    border-color: transparent;
  }
}

.bars-wrap {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding-right: 4px;

  &::-webkit-scrollbar { width: 3px; }
  &::-webkit-scrollbar-thumb {
    background: rgba(136, 135, 135, 0.4);
    border-radius: 2px;
  }
}

.bar-row {
  display: flex;
  align-items: center;
  gap: 6px;
}

.bar-label {
  flex-shrink: 0;
  width: 52px;
  font-size: 0.68rem;
  color: var(--color-complement-text, #aaa);
  text-align: right;
}

.bar-track {
  flex: 1;
  height: 14px;
  background: rgba(255, 255, 255, 0.06);
  border-radius: 3px;
  overflow: hidden;
}

.bar-fill {
  height: 100%;
  border-radius: 3px;
  transition: width 0.3s ease;
}

.bar-count {
  flex-shrink: 0;
  width: 28px;
  font-size: 0.68rem;
  color: var(--color-complement-text, #aaa);
  text-align: left;
}
</style>
