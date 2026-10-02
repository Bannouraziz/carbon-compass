# 🌿 Carbon Compass — ESG Emissions Tracker on SAP BTP

Full-stack ESG (greenhouse-gas) emissions tracking built on a **SAP BTP ABAP Environment trial**: an ABAP Cloud **RAP** backend, two **SAP Fiori elements** apps (transactional + analytical), facility-based authorization, a **Node.js MCP server** that lets Claude Desktop query the data in natural language, and a standalone **report server** that renders print-ready PDF reports with charts.

---

## Contents

- [What it does](#what-it-does)
- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Data model](#data-model)
- [ABAP backend](#abap-backend)
- [Authorization](#authorization)
- [OData services](#odata-services)
- [Fiori apps](#fiori-apps)
- [Report server](#report-server)
- [MCP server](#mcp-server)
- [Sample data](#sample-data)
- [Getting started](#getting-started)
- [BTP trial constraints](#btp-trial-constraints)
- [Known gaps and roadmap](#known-gaps-and-roadmap)

---

## What it does

- Record emissions per **facility**, **reporting period** and **scope** (`SCOPE1`, `SCOPE2`, `SCOPE3`), with line items per **activity type**.
- Calculate CO₂e automatically: `CO2e = Quantity × emission factor`, summed into the record's `TotalCO2e`.
- Move records through a status flow: `DRAFT` → `SUBMITTED` → `APPROVED` / `REJECTED`.
- Restrict who can edit, submit and approve by **user ↔ facility ↔ role** assignments.
- Analyse emissions by facility, scope, period and status in an analytical Fiori app with KPI tags.
- Open a **print-ready PDF report** for one record, or a summary for several, from the browser.
- Ask Claude questions about the live data through the **Model Context Protocol (MCP)**.

---

## Architecture

```
                 ┌───────────────────────── SAP BTP ABAP Environment (trial) ─────────────────────────┐
                 │                                                                                    │
                 │  Tables ──▶ ZI_ interface views ──▶ ZC_ projection views ──▶ Service definitions   │
                 │               + RAP behavior (managed, draft, strict(2))      + OData V4 bindings  │
                 │                                                                                    │
                 │  DCL (ZI_EmissionRecord) + instance authorization (ZBP_I_EMISSIONRECORD)           │
                 │  HTTP service ZS_ESG_HTTP_SERVICE  (JSON bridge for the MCP server)                │
                 └──────────┬───────────────────────────────┬──────────────────────────────┬──────────┘
                            │ OData V4                      │ OData V4                     │ HTTP + Basic auth
                            ▼                               ▼                              ▼
              ┌───────────────────────────┐   ┌───────────────────────────┐   ┌────────────────────────┐
              │ emissionrecord/           │   │ esganalytics/             │   │ mcp-server/            │
              │ Fiori elements            │   │ Fiori elements            │   │ Node.js, stdio         │
              │ List Report + Object Page │   │ analytical app + KPIs     │   │ 4 tools for Claude     │
              └─────────────┬─────────────┘   └───────────────────────────┘   │ Desktop (static data   │
                            │ "Generate Report" button                        │ fallback)              │
                            │ record + items as base64url in the URL          └────────────────────────┘
                            ▼
              ┌───────────────────────────┐
              │ report-server/            │
              │ Node.js / Express         │
              │ GET /report?d=…           │
              │ POST /report-batch        │
              │ Chart.js, print to PDF    │
              └───────────────────────────┘
```

The report server never talks to SAP in its main mode. The Fiori app already has the record in its binding context, so it passes the data to the report server, which therefore holds no credentials.

---

## Repository layout

```
carbon-compass/
├── src/zesg_core/        ABAP objects serialized by abapGit (package ZESG_CORE)
├── emissionrecord/       Fiori elements app: List Report + Object Page (zesg.emissionrecord)
├── esganalytics/         Fiori elements app: analytical app with KPI tags (esganalytics)
├── mcp-server/           MCP server for Claude Desktop
├── report-server/        Express report server (single + batch reports)
└── .abapgit.xml          abapGit settings (starting folder /src/, full folder logic)
```

Main objects in `src/zesg_core/`:

| Area | Objects |
|---|---|
| Tables | `ZESG_EMREC`, `ZESG_EMRECITM`, `ZESG_FACILITY`, `ZESG_ASSET`, `ZESG_EMFACTOR`, `ZESG_USR_ASSIGN`, plus draft tables `ZESG_EMREC_D`, `ZESG_EMRECITM_D`, `ZESG_FACILITY_D`, `ZESG_ASSET_D`, `ZESG_EMFACTOR_D`, `ZESG_USR_ASGN_D` |
| Interface views | `ZI_EmissionRecord`, `ZI_EmissionRecordItem`, `ZI_Facility`, `ZI_Asset`, `ZI_EmissionFactor`, `ZI_UserAssignment`, `ZI_EmissionAnalyticsCube` |
| Projection views | `ZC_EmissionRecord`, `ZC_EmissionRecordItem` (+ metadata extension), `ZC_Facility`, `ZC_Asset`, `ZC_EmissionFactor`, `ZC_UserAssignment`, `ZC_EmissionAnalytics` |
| Behavior | Interface and projection BDEFs for each BO, handler classes `ZBP_I_*` |
| Access control | `ZI_EmissionRecord` (role), `ZI_UserAssignment` (aspect) |
| Services | `ZUI_ESG_EMISSIONRECORD`, `ZUI_ESG_ANALYTICS`, `ZUI_ESG_MASTERDATA`, `ZUI_ESG_USERADMIN` (definitions and OData V4 bindings) |
| HTTP | `ZCL_ESG_HTTP_SERVICE`, `ZS_ESG_HTTP_SERVICE`, communication scenario `ZESG_ESG_MCP` |
| Utilities | `ZCL_ESG_SEED_DATA` (demo data generator) |

---

## Data model

```
ZI_Facility ──< ZI_Asset
     │
     └──< ZI_EmissionRecord (root)  ──composition──<  ZI_EmissionRecordItem ──> ZI_EmissionFactor
              │                                              │
              └── FacilityId, ReportingPeriod, Scope,        └── AssetId, ActivityType,
                  Status, TotalCO2e, Notes, admin fields         Quantity, Unit, CO2e
```

| Table | Key | Main fields |
|---|---|---|
| `ZESG_EMREC` | `EMISSIONRECORD_ID` (UUID) | `FACILITY_ID`, `REPORTING_PERIOD` (CHAR 7, e.g. `2025-Q1`), `REPORTING_DATE`, `SCOPE` (CHAR 6), `STATUS` (CHAR 10), `TOTAL_CO2E`, `NOTES` (CHAR 500), created/changed admin fields |
| `ZESG_EMRECITM` | `EMISSIONRECORDITEM_ID` (UUID) | `EMISSIONRECORD_ID`, `ASSET_ID`, `ACTIVITY_TYPE`, `QUANTITY`, `UNIT`, `CO2E` |
| `ZESG_FACILITY` | `FACILITY_ID` | `FACILITY_NAME`, `COUNTRY`, `BUSINESS_UNIT` |
| `ZESG_ASSET` | `ASSET_ID` | `FACILITY_ID`, `ASSET_NAME`, `ASSET_TYPE` |
| `ZESG_EMFACTOR` | `ACTIVITY_TYPE` | `DESCRIPTION`, `SCOPE`, `FACTOR_VALUE`, `UNIT` |
| `ZESG_USR_ASSIGN` | `USER_ID`, `FACILITY_ID` | `ROLE_TYPE` (`AUDITOR`, `OFFICER`, `MANAGER`) |

---

## ABAP backend

### Emission record BO (`ZI_EmissionRecord`)

Managed, draft-enabled, `strict(2)`, with `lock master total etag LastChangedAt` and `authorization master ( instance )`. Implementation class: `ZBP_I_EMISSIONRECORD`.

| Element | Behavior |
|---|---|
| `EmissionRecordId` | Read-only, managed UUID numbering |
| `Status`, `TotalCO2e`, admin fields | Read-only for the UI |
| Draft actions | `Edit`, `Activate`, `Discard`, `Resume`, `Prepare` |
| `setInitialRecordValues` (determination on modify, create) | Sets `Status = 'DRAFT'` and `ReportingDate` to today |
| `calculateItemCO2e` (determination on save, on items) | Looks up `FACTOR_VALUE` in `ZESG_EMFACTOR`, sets `CO2e = Quantity × factor`, then sums all items into the parent's `TotalCO2e` |
| `submitRecord`, `approveRecord`, `rejectRecord` | Set `Status` to `SUBMITTED`, `APPROVED`, `REJECTED` |
| `generateReport` | Writes a plain-text summary of the record into `Notes` (the visual report is produced by the report server, see below) |
| `validateBeforeSubmit` (on save) | Rejects a `SUBMITTED` record whose `TotalCO2e` is not greater than zero |

The items entity (`ZI_EmissionRecordItem`) is a composition child: lock and authorization dependent on the parent, `CO2e` and `EmissionRecordId` read-only.

### Master data and user administration

Facility, Asset, Emission Factor and User Assignment are separate managed, draft-enabled BOs with their own projections. `ZUI_ESG_MASTERDATA` exposes the first three, `ZUI_ESG_USERADMIN` exposes `ZC_UserAssignment` (global authorization).

---

## Authorization

Two layers work together.

**1. Row-level read access (DCL).** `ZI_EmissionRecord` has an access control role that filters by facility through the `ZI_UserAssignment` aspect (`with user element UserId`), so a user only reads records of facilities assigned to them in `ZESG_USR_ASSIGN`.

**2. Instance authorization (`get_instance_authorizations`).** For each record the handler decides what the current user may do:

| Situation | Update / delete / Edit | Submit | Approve / reject |
|---|---|---|---|
| User has **no assignments at all** (treated as owner/admin) | yes | yes | yes |
| User has assignments, **none for this facility** | no | no | no |
| `AUDITOR` | no | no | no |
| `OFFICER` | yes | only when `DRAFT` | no |
| `MANAGER` | yes | only when `DRAFT` | only when `SUBMITTED` |

The fallback for users without assignments keeps the system usable on a fresh trial account, where nobody is assigned yet.

---

## OData services

| Service definition | Exposes | OData V4 binding |
|---|---|---|
| `ZUI_ESG_EMISSIONRECORD` | `EmissionRecord`, `EmissionRecordItem` | `ZUI_ESG_EMISSIONRECORD_O4` (UI), `ZAPI_ESG_EMISSIONRECORD_O4` (A2X) |
| `ZUI_ESG_ANALYTICS` | `EmissionAnalytics` | `ZUI_ESG_ANALYTICS_O4` |
| `ZUI_ESG_MASTERDATA` | `Facility`, `Asset`, `EmissionFactor` | `ZUI_ESG_MASTERDATA_O4` |
| `ZUI_ESG_USERADMIN` | `UserAssignment` | `ZUI_ESG_USERADMIN_O4` |

Path pattern: `/sap/opu/odata4/sap/<binding>/srvd/sap/<service>/0001/`

---

## Fiori apps

### `emissionrecord/` — transactional app

- **List Report** with the columns Facility, Reporting Period, Scope, Status and Total CO₂e, plus Submit / Approve / Reject actions from the CDS annotations.
- **Object Page** with the general information section and an items table (items have their own object page).
- Draft handling (create, save as draft, resume).
- **Generate Report** header button: a custom action configured in `manifest.json` and implemented in `webapp/ext/ReportAction.js`. It reads the header and the items from the binding context, encodes them as base64url JSON and opens `http://localhost:3000/report?d=…` in a new tab.

### `esganalytics/` — analytical app

- Based on `ZC_EmissionAnalytics`, which sits on the analytical cube `ZI_EmissionAnalyticsCube` (`@Analytics.dataCategory: #CUBE`, `TotalCO2e` and `RecordCount` as summed measures).
- Chart annotations for CO₂e by scope (donut) and by facility (bar), combined with the table (Chart, Table and hybrid views), with filter fields for facility, period, scope and status.
- **KPI tags** for Total CO₂e and Record Count, defined in the app's local `annotation.xml`.
- The local annotation file also declares `Aggregation.ApplySupported` (aggregate, groupby, filter) on the entity type, because the service does not advertise group-by support and the chart would otherwise collapse into a single total.
- Table configured as a responsive table with multi-selection.

Both apps start with `npm start` inside their folder (Fiori tools proxy to the ABAP system; see [Getting started](#getting-started)).

---

## Report server

`report-server/` is a small Express app that renders HTML reports with a dedicated print stylesheet, so *Download PDF* (browser print) produces a clean A4 document.

| Route | Purpose |
|---|---|
| `GET /report?d=<payload>` | One record. `d` is `base64url(JSON)` of `{ "record": {…}, "items": [ … ] }` |
| `POST /report-batch` | Summary of several records. Form field `payload` holds `{ "records": [ … ] }` |
| `GET /report?id=<id>` | Fallback: reads the record from OData with the credentials in `.env` (or sample data when `MOCK=1` / `SAP_HOST` is unset) |

- Single report: KPI tiles, donut of CO₂e by activity type, bar of quantity per item, items table, optional notes.
- Batch report: KPI tiles (total CO₂e, record count, average, approved count), charts by scope, facility, reporting period and status, and a records table.
- Charts are Chart.js and are recolored automatically for printing.
- Values are HTML-escaped; invalid or missing payloads return an error page.

Run it:

```bash
cd report-server
npm install
npm start          # http://localhost:3000
```

The payload shape and the controller snippet used by the Fiori app are described in [`report-server/INTEGRATION.md`](report-server/INTEGRATION.md).

---

## MCP server

`mcp-server/` is a Node.js MCP server (stdio transport) built with `@modelcontextprotocol/sdk`, so Claude Desktop can answer questions about the emissions data.

| Tool | Parameters | Returns |
|---|---|---|
| `get_emission_records` | optional `FacilityId`, `ReportingPeriod`, `Status`, `Scope` | Emission records |
| `get_emission_items` | `EmissionRecordId` | Items of one record |
| `get_facilities` | none | Facilities |
| `get_emission_factors` | optional `ActivityType` | Emission factors |

Each tool calls the ABAP HTTP service `ZS_ESG_HTTP_SERVICE` (`/sap/bc/http/sap/zs_esg_http_service`) with Basic auth and the request header `X-ESG-Entity: records | items | facilities | factors`. If the call fails (no credentials, 401, timeout), the server returns **built-in sample data**, so the tools still work for demos. Note that this sample data is independent of what is in your system.

Claude Desktop configuration (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "carbon-compass-esg": {
      "command": "node",
      "args": ["<path-to-repo>/mcp-server/index.js"],
      "env": {
        "ODATA_BASE_URL": "https://<your-system>.abap-web.<region>.hana.ondemand.com",
        "ODATA_USERNAME": "<user>",
        "ODATA_PASSWORD": "<password>"
      }
    }
  }
}
```

---

## Sample data

`ZCL_ESG_SEED_DATA` fills the tables with demo data. Run it from ADT with **F9** (Run as ABAP Application).

- Creates 60 records (change `lc_records`) with 2 to 5 items each, random scope, status, period and date.
- Uses emission factors from `ZESG_EMFACTOR` (it stops if the table is empty) and facility IDs already used by other records, falling back to `FAC001` to `FAC004`.
- Marks everything with `created_by = 'SEEDER'`; every run first deletes the previous seeded rows.
- Writes straight to the tables, so seeded records are already active (no draft).

Facilities, assets and emission factors are maintained through `ZUI_ESG_MASTERDATA`.

---

## Getting started

### Prerequisites

- A SAP BTP ABAP Environment (trial works) and **ABAP Development Tools** in Eclipse, with abapGit
- Node.js 20 or newer
- For the AI part: Claude Desktop

### 1. Import the ABAP objects

1. In ADT, connect to your ABAP system and create the package `ZESG_CORE`.
2. Link this repository with abapGit (starting folder `/src/`), pull and activate.
3. Publish the service bindings (`ZUI_ESG_EMISSIONRECORD_O4`, `ZUI_ESG_ANALYTICS_O4`, `ZUI_ESG_MASTERDATA_O4`, `ZUI_ESG_USERADMIN_O4`).
4. Maintain emission factors through the master data service, then run `ZCL_ESG_SEED_DATA`.

### 2. Run the Fiori apps

The `ui5.yaml` files proxy `/sap` to the ABAP system through a BTP destination. Adjust the system URL and destination to your own account first.

```bash
cd emissionrecord      # or esganalytics
npm install
npm start
```

### 3. Run the report server

```bash
cd report-server
npm install
npm start
```

Keep it running while you use *Generate Report* in the transactional app. Copy `.env.example` to `.env` only if you want the `?id=` fallback that reads from OData.

### 4. Connect Claude Desktop (optional)

```bash
cd mcp-server
npm install
```

Then add the server to `claude_desktop_config.json` as shown above and restart Claude Desktop.

---

## BTP trial constraints

- Communication arrangements for machine-to-machine access are limited on the trial. The MCP server therefore uses a custom HTTP service and falls back to sample data if it cannot authenticate.
- There is no AI Core / generative AI hub on the trial, so the AI integration lives outside ABAP, in the MCP server and Claude Desktop.

---

## Known gaps and roadmap

- The `/report-batch` route exists, but the analytical app does not yet have a *Generate Report* button for the selected rows; only the transactional app triggers a report.
- The report URL is hardcoded to `http://localhost:3000`. For a shared deployment, host the report server over HTTPS and make the base URL configurable.
- `ZCL_ESG_HTTP_SERVICE` returns whole tables without filtering or paging; access control relies on the communication scenario.
- `FacilityId` is not mandatory in the BO yet, so a record can be saved without a facility.
- `report-server/README.md` still describes the older OData-only mode; `INTEGRATION.md` and this file describe the current URL-payload mode.
- The project folders include generated Fiori test scaffolding (`webapp/test`), which is not customized.
