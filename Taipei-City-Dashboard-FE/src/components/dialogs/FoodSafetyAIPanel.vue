<script setup>
import { ref, computed } from "vue";
import { useContentStore } from "../../store/contentStore";
import { useAuthStore } from "../../store/authStore";

const contentStore = useContentStore();
const authStore = useAuthStore();

const isFoodSafetyDashboard = computed(() =>
	contentStore.currentDashboard.components?.some(
		(c) => c.index === "rfsrai_index"
	)
);

const showPanel = ref(false);
const analyzing = ref(false);
const analysisText = ref("");

const TOOL_DEFINITIONS = [
	{
		type: "function",
		function: {
			name: "get_rfsrai_ranking",
			description:
				"取得各行政區的 RFSRAI 食品安全風險評估指標排行。指數越高代表該區食品安全管理優先程度越高。",
			parameters: {
				type: "object",
				properties: {
					city: {
						type: "string",
						enum: ["taipei", "metrotaipei"],
						description:
							'"taipei" = 臺北市 12 區, "metrotaipei" = 雙北 41 區',
					},
				},
				required: ["city"],
			},
		},
	},
	{
		type: "function",
		function: {
			name: "get_inspection_failures",
			description:
				"取得各行政區的食品抽驗不合格筆數，可看出哪些區域食安問題較多。",
			parameters: {
				type: "object",
				properties: {
					city: {
						type: "string",
						enum: ["taipei", "metrotaipei"],
						description:
							'"taipei" = 臺北市 12 區, "metrotaipei" = 雙北 41 區',
					},
				},
				required: ["city"],
			},
		},
	},
];

async function runAnalysis() {
	analyzing.value = true;
	analysisText.value = "";

	const baseUrl = import.meta.env.VITE_API_URL || "/api/v1";

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
							"你是雙北食品安全分析助手。善用工具取得資料後，以繁體中文給出清楚的分析報告。報告須包含：1) 高風險區域點名，2) 抽驗不合格熱點，3) 風險因子解讀，4) 稽查資源配置建議。",
					},
					{
						role: "user",
						content:
							"請分析雙北食品安全現況，查詢 RFSRAI 風險排行與抽驗不合格熱點（使用 metrotaipei），綜合比對後給出行政區風險報告與稽查資源配置建議。",
					},
				],
				tools: TOOL_DEFINITIONS,
				tool_choice: "auto",
				max_new_tokens: 1500,
			}),
		});

		if (!response.ok) {
			const err = await response.text();
			analysisText.value = `分析失敗：${err || response.statusText}`;
			return;
		}

		const reader = response.body.getReader();
		const decoder = new TextDecoder();

		while (true) {
			const { done, value } = await reader.read();
			if (done) break;
			analysisText.value += decoder.decode(value, { stream: true });
		}
	} catch (e) {
		analysisText.value = `錯誤：${e.message}`;
	} finally {
		analyzing.value = false;
	}
}

function openPanel() {
	showPanel.value = true;
	if (!analysisText.value && !analyzing.value) {
		runAnalysis();
	}
}

function closePanel() {
	showPanel.value = false;
}

function refresh() {
	analysisText.value = "";
	runAnalysis();
}
</script>

<template>
  <template v-if="isFoodSafetyDashboard">
    <!-- Floating trigger button -->
    <button
      class="fsai-fab"
      title="AI 食安分析"
      @click="openPanel"
    >
      <span class="material-icons-outlined">auto_awesome</span>
      <span class="fsai-fab-label">AI 食安分析</span>
    </button>

    <!-- Analysis dialog overlay -->
    <Teleport to="body">
      <div
        v-if="showPanel"
        class="fsai-overlay"
        @click.self="closePanel"
      >
        <div class="fsai-panel">
          <div class="fsai-header">
            <span class="material-icons-outlined">auto_awesome</span>
            <h3>食安風險 AI 分析報告</h3>
            <div class="fsai-header-actions">
              <button
                :disabled="analyzing"
                title="重新分析"
                @click="refresh"
              >
                <span class="material-icons-outlined">refresh</span>
              </button>
              <button @click="closePanel">
                <span class="material-icons-outlined">close</span>
              </button>
            </div>
          </div>

          <div class="fsai-body">
            <div
              v-if="analyzing && !analysisText"
              class="fsai-loading"
            >
              <div class="fsai-spinner" />
              <p>AI 正在呼叫工具並分析資料，請稍候…</p>
            </div>
            <pre
              v-else
              class="fsai-content"
            >{{ analysisText || "（無回應）" }}</pre>
          </div>
        </div>
      </div>
    </Teleport>
  </template>
</template>

<style scoped lang="scss">
.fsai-fab {
  position: fixed;
  bottom: 2rem;
  right: 2rem;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.6rem 1rem;
  background: var(--color-highlight);
  color: #fff;
  border: none;
  border-radius: 2rem;
  cursor: pointer;
  font-size: var(--font-s);
  font-weight: 600;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  z-index: 100;
  transition: transform 0.15s ease;

  &:hover {
    transform: translateY(-2px);
  }

  .material-icons-outlined {
    font-size: 1.1rem;
  }

  @media (max-width: 600px) {
    .fsai-fab-label {
      display: none;
    }
    padding: 0.7rem;
    border-radius: 50%;
  }
}

.fsai-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.fsai-panel {
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: 0.75rem;
  width: min(720px, 90vw);
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.fsai-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem 1.2rem;
  border-bottom: 1px solid var(--color-border);

  .material-icons-outlined:first-child {
    color: var(--color-highlight);
  }

  h3 {
    flex: 1;
    margin: 0;
    font-size: var(--font-m);
    color: var(--color-text);
  }

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

      &:hover {
        background: var(--color-border);
      }

      &:disabled {
        opacity: 0.4;
        cursor: default;
      }
    }
  }
}

.fsai-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.2rem;
}

.fsai-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 2rem;

  p {
    color: var(--color-complement-text);
    font-size: var(--font-s);
  }
}

.fsai-spinner {
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  border: 3px solid var(--color-border);
  border-top-color: var(--color-highlight);
  animation: spin 0.7s linear infinite;
}

.fsai-content {
  white-space: pre-wrap;
  word-break: break-word;
  font-family: var(--font-family);
  font-size: var(--font-s);
  color: var(--color-text);
  line-height: 1.7;
  margin: 0;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
