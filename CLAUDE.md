# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

Monorepo with four sub-projects plus shared Docker infrastructure:

```
Taipei-City-Dashboard/
├── docker/                          # Docker Compose orchestration (working dir)
├── Taipei-City-Dashboard-FE/        # Vue 3 + Vite frontend
├── Taipei-City-Dashboard-BE/        # Go (Gin) backend API
├── Taipei-City-Dashboard-DE/        # Airflow ETL data pipelines
└── db-sample-data/                  # Seed SQL files
```

## Docker Setup (Primary Entry Point)

All services run via Docker Compose from the `docker/` directory. Three compose files:

| File | Purpose |
|---|---|
| `docker-compose-db.yaml` | Databases: postgres-data, postgres-manager, Redis, pgAdmin, Qdrant |
| `docker-compose.yaml` | App services: Nginx, FE (Node), BE (Go), vector-db-upgrade |
| `docker-compose-init.yaml` | One-time init: `npm ci`, DB migrations, seed data |

**Required Docker network** (create once):
```bash
docker network create --driver=bridge --subnet=192.168.128.0/24 --gateway=192.168.128.1 br_dashboard
```

**Startup order:**
```bash
cd docker
docker compose -f docker-compose-db.yaml up -d        # 1. DBs first
docker compose -f docker-compose-init.yaml up         # 2. Init (one-time)
docker compose up -d                                  # 3. App services
```

**Dev proxy (no Docker):** FE `npm run dev` proxies `/api` → `https://citydashboard.taipei/api/v1` directly. Use `DOCKER_COMPOSE=true` env to switch proxy to local BE.

## Frontend (Vue 3 + Vite)

```
src/
├── views/          # Page-level components (DashboardView, MapView, ComponentView…)
├── store/          # Pinia stores (authStore, contentStore, mapStore, dialogStore…)
├── components/     # Shared UI components
├── dashboardComponent/  # Dashboard-specific: charts, map layers, dialogs
└── router/         # Vue Router
```

**Commands (inside `Taipei-City-Dashboard-FE/`):**
```bash
npm run dev          # Dev server (port 80)
npm run build        # Lint + production build
npm run build:test   # Lint + test-mode build
npm run lint         # ESLint fix
```

Key deps: Mapbox GL, Deck.gl, ApexCharts, Pinia, Axios, Three.js.

## Backend (Go + Gin)

```
app/
├── controllers/    # HTTP handlers (auth, dashboard, componentConfig, componentData, ai, user…)
├── models/         # GORM models + DB queries (two DBs: DASHBOARD, MANAGER)
├── routes/         # Router setup
├── middleware/     # Auth, CORS, rate limiting
├── cache/          # Redis client
├── initial/        # Cron jobs init
├── services/       # Business logic
└── util/
global/             # Global vars (LM session, tokenizer)
cmd/                # CLI subcommands
```

Two PostgreSQL databases:
- **postgres-manager**: User mgmt, dashboard configs, component metadata (GORM auto-migrate)
- **postgres-data**: Time-series and geo data loaded by ETL pipelines

**Commands (inside `Taipei-City-Dashboard-BE/`):**
```bash
go run main.go              # Start server
go run main.go migrateDB    # Run DB migrations (manager DB)
go run main.go initDashboard # Seed dashboard DB
go build -o TaipeiCityDashboardBE .
```

AI features use ONNX Runtime for local embedding model + optional TWCC LLM API. Qdrant vector DB stores chart embeddings for semantic search.

## Data Engineering (Airflow)

```
dags/
├── operators/common_pipeline.py  # Base DAG class + auto queue routing
├── settings/global_config.py     # DAG_PATH, DATA_PATH, PROXIES
├── proj_city_dashboard/          # Taipei city ETL DAGs (one folder per dataset)
├── proj_new_taipei_city_dashboard/
├── common_dags/
├── utils/
└── test/ tutorial/              # Excluded from Airflow scanning via .airflowignore
```

Each dataset folder under `proj_city_dashboard/` contains its own ETL script. The `common_pipeline.py` base class auto-routes tasks to queues by schedule frequency:
- `*/5` or `*/10` → `realtime` queue
- daily, split by DAG ID hash → `default` or `heavy`
- monthly+ → `heavy`
- other → `default`

**DE starts via** `Taipei-City-Dashboard-DE/docker/` with its own docker-compose.

## Environment Variables

All configuration via `.env` in `docker/`. Key groups:
- `DB_DASHBOARD_*` / `DB_MANAGER_*` — PostgreSQL credentials
- `VITE_*` — FE build-time vars (API URL, Mapbox token, app title)
- `ISSO_*` / `TAIPEIPASS_*` — SSO/OAuth
- `JWT_SECRET`, `IDNO_SALT` — BE auth
- `QDRANT_*`, `TWCC_*` — AI/vector search

## Official Documentation

Submodule at `docs/official-docs/`. Update with:
```bash
git submodule update --remote docs/official-docs
```

All docs are markdown files under `docs/official-docs/src/assets/articles/`. English versions below. Chinese mirrors exist as `*-ch/` equivalents.

### Frontend (`front-end-en/`)

| Task | Doc file |
|---|---|
| Project setup & prerequisites | `project-setup.md`, `prerequisites.md` |
| File structure overview | `file-system.md` |
| UI layout & rendering | `user-interface.md`, `rendering-strategy.md` |
| Dashboard concepts | `introduction-to-dashboards.md`, `modifying-a-dashboard.md` |
| Component system overview | `introduction-to-components.md` |
| Chart data format & config | `chart-data.md` |
| Supported chart types | `supported-chart-types.md` |
| Map data format & config | `map-data.md` |
| Supported map layer types | `supported-map-types.md` |
| Map filtering logic | `map-filtering.md` |
| History/time-series data | `history-data.md` |
| Auth & login flow | `user-authentication.md` |
| Admin panel | `system-administration.md` |
| Custom styling | `customization-overview.md`, `custom-styling.md` |
| Adding custom dialogs | `custom-dialogs.md` |
| Adding custom chart types | `custom-charts.md` |
| Adding custom map layers | `custom-maps.md` |
| Static deployment | `create-a-static-application.md` |
| Code style & contribution | `code-style.md`, `contribution-overview.md` |

### Backend (`back-end-en/`)

| Task | Doc file |
|---|---|
| Project setup & prerequisites | `project-setup.md`, `prerequisites.md` |
| DB & Go server overview | `database-overview.md`, `go-backend.md` |
| Users / roles / groups schema | `users-roles-groups-db.md` |
| Component metadata schema | `components-db.md` |
| Dashboard schema | `dashboards-db.md` |
| Issues schema | `issues-db.md` |
| Contributors schema | `contributors-db.md` |
| Viewpoints schema | `viewpoints-db.md` |
| Chat log schema | `chatlog-db.md` |
| Auth APIs | `authentication-apis.md` |
| User APIs | `user-apis.md` |
| Component config APIs | `component-config-apis.md` |
| Component data APIs | `component-data-apis.md` |
| Dashboard APIs | `dashboard-apis.md` |
| Issue APIs | `issue-apis.md` |
| Contributor APIs | `contributor-apis.md` |
| Viewpoint APIs | `viewpoint-apis.md` |
| Chat log APIs | `chatlog-apis.md` |
| Vector DB / Qdrant APIs | `vectordb-apis.md` |
| AI / LLM APIs | `ai-apis.md` |
| Code style & contribution | `code-style.md`, `contribution-overview.md` |

### Data Engineering (`data-end-en/`)

| Task | Doc file |
|---|---|
| Project setup & prerequisites | `project-setup.md`, `prerequisites.md` |
| DE architecture overview | `dataend.md` |
| Airflow setup & concepts | `airflow.md` |
| Database schema for ETL | `database.md` |
| Global config (paths, proxies) | `global-config.md` |
| DAG metadata fields | `dag-metadata.md` |
| Writing DAG code | `dag-code.md` |
| DAG config file format | `dag-config.md` |
| DB table conventions | `dag-table.md` |
| Testing a DAG | `dag-test.md` |
| Pipeline base class | `pipeline.md` |
| Utils overview | `utils-overview.md` |
| SQL generation utils | `utils-generate-sql.md` |
| Data extraction utils | `utils-extract.md` |
| Time transform utils | `utils-transform-time.md` |
| Spatial transform utils | `utils-transform-spatial.md` |
| Address transform utils | `utils-transform-address.md` |
| Data load utils | `utils-load.md` |
| TDX (transport data) utils | `utils-tdx.md` |
| Code style & contribution | `code-style.md`, `contribution-overview.md` |
