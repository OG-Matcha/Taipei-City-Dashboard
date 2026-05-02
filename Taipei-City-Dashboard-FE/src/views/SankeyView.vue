<!-- Supply Chain Sankey - Prototype View -->
<script setup>
import DashboardComponent from "../dashboardComponent/DashboardComponent.vue";

// Minimal fake config to satisfy DashboardComponent
const fakeConfig = {
	index: "sankey-school-food",
	name: "雙北學校供餐供應鏈",
	source: "雙北市教育局",
	chart_config: {
		types: ["SankeyChart"],
		color: [],
		unit: "",
	},
	chart_data: [],
	time_from: null,
	time_to: null,
	map_config: null,
	map_filter: null,
	short_desc: "雙北中小學及高中職供餐食材供應鏈（上游供應商 → 中游供餐業者 → 下游學校）",
	long_desc: "",
	use_case: "",
	history_config: null,
};
</script>

<template>
  <div class="sankey-view">
    <div class="sankey-grid">
      <!-- span 2 columns -->
      <div class="sankey-wide">
        <DashboardComponent
          :config="fakeConfig"
          :footer="false"
          mode="large"
        />
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.sankey-view {
  padding: 1rem;
  height: calc(100vh - 60px);
  overflow-y: auto;
}

.sankey-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;

  @media (min-width: 1296px) {
    grid-template-columns: 1fr 1fr 1fr;
  }
}

.sankey-wide {
  grid-column: span 2;
  height: 640px;
}
</style>
