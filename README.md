# 🌿 Carbon Compass — SAP BTP ESG Emissions Tracker

> Full-stack capstone project built on **SAP BTP ABAP Trial** — combining ABAP Cloud RAP, SAP Fiori Elements (transactional + analytical), row-level authorization, a Node.js MCP server for LLM integration, and a standalone report server for professional PDF reporting — end-to-end ESG emissions tracking, analytics and reporting.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Data Model](#data-model)
- [ABAP Backend](#abap-backend)
- [Fiori Elements Frontend](#fiori-elements-frontend)
- [ESG Analytics](#esg-analytics)
- [Authorization & Row-Level Security](#authorization--row-level-security)
- [User Management](#user-management)
- [MCP Server](#mcp-server)
- [Report Server](#report-server)
- [Emission Factors](#emission-factors)
- [Workflow & Approval](#workflow--approval)
- [BTP Trial Limitations](#btp-trial-limitations)
- [Local Setup](#local-setup)
- [Sample Data](#sample-data)
- [Roadmap](#roadmap)

---

## Overview

**Carbon Compass** is a production-style ESG (Environmental, Social & Governance) emissions tracking system built entirely on SAP Business Technology Platform (BTP). It allows sustainability managers to:

- Record and categorize greenhouse gas emissions by facility, scope, and activity type
- Automatically calculate CO₂e values using configurable emission factors
- Submit records through a structured approval workflow (Draft → Submitted → Approved/Rejected)
- Query and analyze emissions data via a conversational AI interface through the Model Context Protocol (MCP)

The project was built as a portfolio capstone to demonstrate full-stack SAP Cloud Native development — from ABAP Cloud objects in ADT through to a live AI tool integration via Claude Desktop.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SAP BTP ABAP Trial                       │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌───────────────────┐  │
│  │  CDS Views   │    │  RAP Behavior│    │  HTTP Service     │  │
│  │  ZI_ / ZC_  │───▶│  ZESG_...    │    │  ZS_ESG_HTTP_     │  │
│  │  (Interface/ │    │  (Actions,   │    │  SERVICE          │  │
│  │  Projection) │    │  Validations,│    │  (MCP bridge)     │  │
│  └──────────────┘    │  Determins.) │    └────────┬──────────┘  │
│                      └──────────────┘             │             │
│  ┌──────────────────────────────────┐             │             │
│  │  SAP Fiori Elements UI           │             │             │
│  │  (List Report + Object Page)     │             │             │
│  │  OData V4 / Draft-enabled        │             │             │
│  └──────────────────────────────────┘             │             │
└──────────────────────────────────────────────────┼─────────────┘
                                                   │ HTTP + Basic Auth
                                                   ▼
                                    ┌──────────────────────────┐
                                    │   Node.js MCP Server     │
                                    │   (stdio transport)      │
                                    │                          │
                                    │  Tools:                  │
                                    │  • get_emission_records  │
                                    │  • get_emission_items    │
                                    │  • get_facilities        │
                                    │  • get_emission_factors  │
                                    └──────────────┬───────────┘
                                                   │ MCP protocol
                                                   ▼
                                    ┌──────────────────────────┐
                                    │   Claude Desktop         │
                                    │   (LLM interface)        │
                                    │                          │
                                    │  Natural language ESG    │
                                    │  queries over live data  │
                                    └──────────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| **ABAP Backend** | SAP ABAP Cloud (BTP ABAP Environment Trial) |
| **Data Modeling** | ABAP CDS Views (Interface + Projection pattern) |
| **Business Logic** | RAP — Managed BO, strict(2), draft-enabled |
| **UI** | SAP Fiori Elements — List Report + Object Page (transactional) and Analytical List Page (analytics), OData V4 |
| **Analytics** | ABAP CDS analytical cube (`@Analytics.dataCategory: #CUBE`) + query |
| **Authorization** | DCL access control (row-level) + `ZI_UserAssignment` user↔facility mapping |
| **HTTP Bridge** | Custom ABAP HTTP Service (`ZS_ESG_HTTP_SERVICE`) |
| **MCP Server** | Node.js 20, `@modelcontextprotocol/sdk`, `zod`, `node-fetch` |
| **Report Server** | Node.js 20, Express, Chart.js — HTML + print-to-PDF reports |
| **AI Interface** | Claude Desktop (Anthropic) via MCP protocol |
| **Dev Tools** | ABAP Development Tools (ADT / Eclipse), abapGit, VS Code |

---

## Project Structure

```
carbon-compass/
│
├── src/zesg_core/            # All ABAP Cloud objects (pushed via abapGit)
│   ├── zi_emissionrecord.*            # Interface view + behavior + DCL — header
│   ├── zi_emissionrecorditem.*        # Interface view — line items
│   ├── zc_emissionrecord.*            # Projection view + behavior — header
│   ├── zc_emissionrecorditem.*        # Projection view — items
│   ├── zi_emissionanalyticscube.*     # Analytical cube (@Analytics #CUBE)
│   ├── zc_emissionanalytics.*         # Analytics query projection
│   ├── zi_userassignment.* / zc_*     # User↔Facility assignment + DCL aspect
│   ├── zui_esg_emissionrecord_o4.srvb # OData V4 binding — transactional app
│   ├── zui_esg_analytics_o4.srvb      # OData V4 binding — analytics app
│   └── zui_esg_useradmin_o4.srvb      # OData V4 binding — user admin app
│
├── emissionrecord/           # Fiori Elements app — List Report + Object Page
├── esganalytics/             # Fiori Elements app — Analytical List Page
│
├── mcp-server/               # Node.js MCP server — 4 ESG tools for Claude Desktop
│   ├── index.js
│   └── package.json
│
└── report-server/            # Node.js/Express — professional PDF report server
    ├── server.js             # /report (single) + /report-batch (summary)
    ├── INTEGRATION.md        # How to wire it to the Fiori app via URL params
    └── package.json
```

---

## Data Model

### Entity Relationship

```
ZI_Facility (master data)
    │
    └──< ZI_EmissionRecord (header)
              │  EmissionRecordId (UUID, managed numbering)
              │  FacilityId
              │  ReportingPeriod (e.g. "2024-Q4")
              │  Scope (SCOPE1 / SCOPE2 / SCOPE3)
              │  Status (DRAFT / SUBMITTED / APPROVED / REJECTED)
              │  TotalCO2e (auto-calculated)
              │
              └──< ZI_EmissionRecordItem (line items)
                        ItemId (UUID, managed numbering)
                        ActivityType (ELEC / HEAT / DIESEL / GAS / ...)
                        Quantity
                        Unit
                        CO2e (auto-calculated = Quantity × EmissionFactor)

ZI_EmissionFactor (master data)
    ActivityType → factor_value (kg CO2e per unit)
```

### Database Tables

| Table | Description |
|---|---|
| `ZESG_EMREC` | Emission record headers |
| `ZESG_EMITEM` | Emission record line items |
| `ZESG_FACILITY` | Facility master data |
| `ZESG_EMFACTOR` | Emission factor reference data |

---

## ABAP Backend

### CDS Views

The project follows the **ZI_ / ZC_ naming convention**:

- **`ZI_*` (Interface views)** — close to the database, expose all fields, define associations, used by behavior definition
- **`ZC_*` (Projection/Consumption views)** — add UI annotations (`@UI.lineItem`, `@UI.facet`, `@UI.selectionField`), define value helps, expose via service binding

### RAP Behavior Definition

```abap
managed implementation in class ZBP_I_EMISSIONRECORD unique;
strict ( 2 );
with draft;

define behavior for ZI_EmissionRecord alias EmissionRecord
  persistent table zesg_emrec
  draft table zesg_emrec_d
  lock master
  authorization master ( global )
  etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) EmissionRecordId;

  create; update; delete;
  draft action Edit;
  draft action Activate optimized;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare;

  action submitRecord  result [1] $self;
  action approveRecord result [1] $self;
  action rejectRecord  result [1] $self;

  determination calculateItemCO2e on save { field Quantity, ActivityType; }
  validation validateBeforeSubmit on save { ... }

  association _Items { create; with draft; }
}
```

### Business Logic

**CO₂e Calculation** (`calculateItemCO2e` determination, fires ON SAVE):
1. For each changed item, reads `ActivityType` and `Quantity`
2. Looks up `factor_value` from `ZESG_EMFACTOR` table
3. Sets `CO2e = Quantity × factor_value` on the item
4. Navigates to parent record and sums all sibling items' CO₂e into `TotalCO2e`

**Workflow Actions:**
- `submitRecord` — sets Status = `SUBMITTED`; only enabled when Status = `DRAFT`
- `approveRecord` — sets Status = `APPROVED`; only enabled when Status = `SUBMITTED`
- `rejectRecord` — sets Status = `REJECTED`; only enabled when Status = `SUBMITTED`

**Validation** (`validateBeforeSubmit`):
- Blocks submission if `TotalCO2e ≤ 0` — prevents empty records from entering the approval flow

**Instance Feature Control** (`get_instance_features`):
- Dynamically enables/disables the three workflow action buttons based on current record Status — the Fiori UI shows only the contextually valid action

### HTTP Service (MCP Bridge)

Since BTP trial's Communication Arrangements are not available for external machine-to-machine auth, a custom ABAP HTTP service (`ZS_ESG_HTTP_SERVICE`) was created as a bridge. It reads the `X-ESG-Entity` header and dispatches to the appropriate SELECT query, returning JSON.

The service is secured via a Communication Scenario (`ZESG_ESG_MCP`) published locally in ADT.

---

## Fiori Elements Frontend

- **List Report** — filterable by Status, Scope, Facility, Reporting Period; sortable by TotalCO2e
- **Object Page** — shows header fields + emission items table in a facet
- **Draft-enabled** — users can start a record, save as draft, and return to it later
- **Action buttons** — Submit / Approve / Reject rendered contextually based on Status
- **OData V4** — served by SAP standard gateway from the service binding

---

## ESG Analytics

An analytical model for multidimensional reporting on top of the transactional data:

- **`ZI_EmissionAnalyticsCube`** — CDS analytical cube (`@Analytics.dataCategory: #CUBE`) exposing CO₂e as a measure with facility, scope, activity type, and reporting period as dimensions
- **`ZC_EmissionAnalytics`** — query projection consumed by the UI
- **`ZUI_ESG_ANALYTICS_O4`** — OData V4 service binding
- **`esganalytics/`** — Fiori Elements **Analytical List Page (ALP)** app with interactive charts and drill-down by dimension

This lets users slice emissions by facility/scope/period without leaving Fiori.

---

## Authorization & Row-Level Security

Access to emission records is restricted per user using a **DCL access control** combined with a user↔facility assignment table — a user only sees records for facilities they are assigned to.

```abap
@MappingRole: true
define role ZI_EmissionRecord {
  grant select on ZI_EmissionRecord
    where (FacilityId) = aspect ZI_UserAssignment;
}
```

- **`ZI_UserAssignment`** — maps a BTP user to one or more facilities (persisted in `ZESG_USR_ASSIGN`)
- The DCL filters `ZI_EmissionRecord` so each user's list is scoped to their facilities
- Enforced consistently across the Fiori apps, the OData services, and any consumer

---

## User Management

A dedicated admin app to maintain who can see what:

- **`ZC_UserAssignment`** (behavior-enabled) — create/update/delete user↔facility assignments
- **`ZUI_ESG_USERADMIN`** — OData V4 service (`expose ZC_UserAssignment as UserAssignment`)
- Administrators assign BTP users to facilities, which immediately drives the row-level security above

---

## MCP Server

The Node.js MCP server exposes four tools that Claude Desktop can call to query ESG data conversationally.

### Tools

| Tool | Description |
|---|---|
| `get_emission_records` | Fetch all emission records; optional filters: `FacilityId`, `ReportingPeriod`, `Scope`, `Status` |
| `get_emission_items` | Fetch line items for a given `EmissionRecordId` |
| `get_facilities` | Fetch all facilities |
| `get_emission_factors` | Fetch emission factors; optional filter: `ActivityType` |

### Transport

stdio — registered in Claude Desktop via `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "carbon-compass-esg": {
      "command": "node",
      "args": ["C:\\Users\\<user>\\carbon-compass\\mcp-server\\index.js"],
      "env": {
        "ODATA_BASE_URL": "https://<your-btp-system>.abap-web.ap21.hana.ondemand.com",
        "ODATA_USERNAME": "<btp-user>",
        "ODATA_PASSWORD": "<btp-password>"
      }
    }
  }
}
```

### Fallback Strategy

BTP trial does not support Communication Arrangements for machine-to-machine Basic Auth to the `abap-web` endpoint. The MCP server handles this gracefully:

1. Attempts a live HTTP call to the BTP system first (8-second timeout)
2. If BTP returns 401, times out, or is unreachable → silently falls back to embedded static data
3. Static data mirrors the production BTP records exactly
4. When BTP auth is eventually resolved, live data takes over automatically — no code change needed

---

## Report Server

A standalone **Node.js / Express** server ([`report-server/`](report-server/)) that renders professional ESG reports as web pages that print cleanly to PDF. It needs **no connection to BTP** — the Fiori app passes the record data in the URL, so the server holds no credentials.

### Routes

| Route | Purpose |
|---|---|
| `GET /report?d=<payload>` | Single-record report. `d` = base64url-encoded JSON of `{ record, items }` |
| `POST /report-batch` | Multi-record summary report. Form field `payload` = JSON `{ records: [...] }` |

### Features

- **Dark dashboard on screen, professional A4 document on print** — a dedicated print stylesheet (letterhead, serif headings, ruled tables, page-break control) so the PDF never looks like a screenshot
- **Chart.js visualizations** — single report: CO₂e by activity type + quantity per item; batch: CO₂e by scope / facility / period and record count by status (charts recolor to dark ink for print)
- **KPI tiles, totals, and a Download PDF button** (client-side `window.print()`)
- **`MOCK=1` demo mode** for running without any data source

### Integration

The Fiori object page builds the URL from its binding context and opens the report in a new tab — see [`report-server/INTEGRATION.md`](report-server/INTEGRATION.md) for the controller snippet and payload shape.

---

## Emission Factors

Reference data used for CO₂e calculation:

| Activity Type | Factor | Unit | Source |
|---|---|---|---|
| `ELEC` | 0.200 | kg CO₂e / kWh | EU grid average |
| `HEAT` | 0.203 | kg CO₂e / kWh | District heating |
| `DIESEL` | 0.264 | kg CO₂e / L | Diesel combustion |
| `GAS` | 0.210 | kg CO₂e / m³ | Natural gas combustion |

Factors are stored in the `ZESG_EMFACTOR` table and can be extended with new activity types without code changes.

---

## Workflow & Approval

```
 ┌────────┐   submitRecord    ┌───────────┐   approveRecord   ┌──────────┐
 │ DRAFT  │ ───────────────▶  │ SUBMITTED │ ────────────────▶ │ APPROVED │
 └────────┘                   └───────────┘                   └──────────┘
                                    │
                                    │ rejectRecord
                                    ▼
                               ┌──────────┐
                               │ REJECTED │
                               └──────────┘
```

- Records start as **DRAFT** (created via Fiori Elements with draft support)
- The reporter submits → status moves to **SUBMITTED**
- A sustainability manager approves or rejects
- Only APPROVED records count toward official emissions reporting

---

## BTP Trial Limitations

This project was built on a **free SAP BTP ABAP Trial** account. Two known limitations affect the architecture:

| Limitation | Impact | Workaround |
|---|---|---|
| Communication Arrangements not available | Cannot create machine-to-machine Basic Auth credentials for the ABAP HTTP service | Custom HTTP service secured via Communication Scenario published locally in ADT; MCP server falls back to static data on 401 |
| No AI Core / GenAI Hub on trial | Cannot make outbound LLM calls from ABAP actions | "Generate Report" action planned using direct Anthropic API call from ABAP HTTP client (roadmap) |

These limitations do not affect the core RAP + Fiori application — only the external integrations.

---

## Local Setup

### Prerequisites

- SAP BTP ABAP Trial account ([get one free](https://developers.sap.com/tutorials/abap-environment-trial-onboarding.html))
- ABAP Development Tools (ADT) — Eclipse plugin
- Node.js 20+
- Claude Desktop ([download](https://claude.ai/download))

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/carbon-compass.git
cd carbon-compass
```

### 2. Import ABAP objects via abapGit

1. Open ADT → connect to your BTP ABAP trial system
2. Open abapGit in ADT → New Online Repository
3. Point to this repo, assign to package `ZESG_CAPSTONE`
4. Pull all objects and activate

### 3. Install MCP server dependencies

```bash
cd mcp-server
npm install
```

### 4. Configure Claude Desktop

Edit `%APPDATA%\Claude\claude_desktop_config.json` (Windows) or `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS):

```json
{
  "mcpServers": {
    "carbon-compass-esg": {
      "command": "node",
      "args": ["<absolute-path-to-repo>/mcp-server/index.js"],
      "env": {
        "ODATA_BASE_URL": "https://<your-btp-guid>.abap-web.ap21.hana.ondemand.com",
        "ODATA_USERNAME": "<your-btp-user>",
        "ODATA_PASSWORD": "<your-btp-password>"
      }
    }
  }
}
```

### 5. Restart Claude Desktop

Quit and reopen Claude Desktop. The `carbon-compass-esg` MCP server will appear in the tool list.

### 6. Test

Ask Claude: *"Which facility has the highest CO₂e emissions? Show me all records and their line items."*

---

## Sample Data

Three emission records across three facilities for 2024-Q4:

| Record | Facility | Scope | Status | Total CO₂e |
|---|---|---|---|---|
| REC-2024-001 | FR-LYO-01 (Lyon) | SCOPE2 | APPROVED | **12,244.0 kg** |
| REC-2024-002 | TN-SFX-01 (Sfax) | SCOPE1 | SUBMITTED | 4,876.5 kg |
| REC-2024-003 | DE-BER-01 (Berlin) | SCOPE1 | DRAFT | 1,320.75 kg |

**FR-LYO-01 breakdown:**
- Electricity: 48,200 kWh × 0.200 = 9,640 kg CO₂e
- District heating: 12,800 kWh × 0.203 = 2,604 kg CO₂e

---

## Roadmap

- [x] **DCL row-level security** — access control on `ZI_EmissionRecord` scoped by facility assignment ✅
- [x] **User management** — admin app to assign BTP users to facilities ✅
- [x] **Analytics dashboard** — Fiori Elements Analytical List Page with CO₂e charts ✅
- [x] **Professional PDF reporting** — standalone report server (single + batch) ✅
- [ ] **Generate Report action** — ABAP action that calls Anthropic API / SAP AI Core and returns a narrative ESG summary per record
- [ ] **Authorization by persona** — restrict Submit to reporters, Approve/Reject to sustainability managers using PFCG roles
- [ ] **Live BTP auth** — resolve machine-to-machine auth for the MCP server using OAuth 2.0 client credentials
- [ ] **Scope 3 support** — extend activity types and value chain emission categories

---

## Author

**Aziz Bannou**
SAP Techno-Functional Consultant · SAP ABAP Cloud Certified (C_ABAPD_2601) · SAP Certified Generative AI Developer

Built as a portfolio capstone to demonstrate end-to-end SAP Cloud Native development on BTP.

---

*SAP, SAP BTP, SAP Fiori, ABAP, and related marks are trademarks of SAP SE. This is an independent community project and is not affiliated with or endorsed by SAP SE.*
