import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import fetch from "node-fetch";
import { z } from "zod";

const { ODATA_BASE_URL, ODATA_USERNAME, ODATA_PASSWORD } = process.env;
const AUTH = Buffer.from(`${ODATA_USERNAME}:${ODATA_PASSWORD}`).toString(
  "base64",
);

// ── Static fallback data (BTP trial blocks machine-to-machine Basic Auth) ────

const STATIC = {
  facilities: [
    {
      FacilityId: "FAC-001",
      Name: "FR-LYO-01",
      Location: "Lyon, France",
      FacilityType: "Manufacturing",
      AssetCategory: "Factory",
    },
    {
      FacilityId: "FAC-002",
      Name: "TN-SFX-01",
      Location: "Sfax, Tunisia",
      FacilityType: "Warehouse",
      AssetCategory: "Logistics",
    },
    {
      FacilityId: "FAC-003",
      Name: "DE-BER-01",
      Location: "Berlin, Germany",
      FacilityType: "Office",
      AssetCategory: "Office",
    },
  ],
  records: [
    {
      EmissionRecordId: "REC-2024-001",
      FacilityId: "FAC-001",
      FacilityName: "FR-LYO-01",
      ReportingPeriod: "2024-Q4",
      Scope: "SCOPE2",
      Status: "APPROVED",
      TotalCO2e: 12244.0,
    },
    {
      EmissionRecordId: "REC-2024-002",
      FacilityId: "FAC-002",
      FacilityName: "TN-SFX-01",
      ReportingPeriod: "2024-Q4",
      Scope: "SCOPE1",
      Status: "SUBMITTED",
      TotalCO2e: 4876.5,
    },
    {
      EmissionRecordId: "REC-2024-003",
      FacilityId: "FAC-003",
      FacilityName: "DE-BER-01",
      ReportingPeriod: "2024-Q4",
      Scope: "SCOPE1",
      Status: "DRAFT",
      TotalCO2e: 1320.75,
    },
  ],
  items: [
    {
      ItemId: "ITEM-001",
      EmissionRecordId: "REC-2024-001",
      ActivityType: "ELEC",
      Quantity: 48200,
      Unit: "kWh",
      CO2e: 9640.0,
    },
    {
      ItemId: "ITEM-002",
      EmissionRecordId: "REC-2024-001",
      ActivityType: "HEAT",
      Quantity: 12800,
      Unit: "kWh",
      CO2e: 2604.0,
    },
    {
      ItemId: "ITEM-003",
      EmissionRecordId: "REC-2024-002",
      ActivityType: "DIESEL",
      Quantity: 18500,
      Unit: "L",
      CO2e: 4876.5,
    },
    {
      ItemId: "ITEM-004",
      EmissionRecordId: "REC-2024-003",
      ActivityType: "GAS",
      Quantity: 6300,
      Unit: "m3",
      CO2e: 1320.75,
    },
  ],
  factors: [
    {
      ActivityType: "ELEC",
      FactorValue: 0.2,
      Unit: "kg CO2e/kWh",
      Description: "Grid electricity (EU average)",
    },
    {
      ActivityType: "HEAT",
      FactorValue: 0.203,
      Unit: "kg CO2e/kWh",
      Description: "District heating",
    },
    {
      ActivityType: "DIESEL",
      FactorValue: 0.264,
      Unit: "kg CO2e/L",
      Description: "Diesel combustion",
    },
    {
      ActivityType: "GAS",
      FactorValue: 0.21,
      Unit: "kg CO2e/m3",
      Description: "Natural gas combustion",
    },
  ],
};

// ── Live BTP fetch — returns null on any failure (401, network, timeout) ─────

async function httpGet(entity) {
  if (!ODATA_BASE_URL || !ODATA_USERNAME || !ODATA_PASSWORD) return null;
  try {
    const url = `${ODATA_BASE_URL}/sap/bc/http/sap/zs_esg_http_service`;
    const res = await fetch(url, {
      headers: {
        Authorization: `Basic ${AUTH}`,
        Accept: "application/json",
        "X-ESG-Entity": entity,
      },
      timeout: 8000,
    });
    if (!res.ok) return null;
    return res.json();
  } catch {
    return null;
  }
}

// ── Filter helper ─────────────────────────────────────────────────────────────

function applyFilters(rows, filters) {
  const active = Object.entries(filters).filter(
    ([, v]) => v !== undefined && v !== null && v !== "",
  );
  if (!active.length) return rows;
  const arr = Array.isArray(rows) ? rows : (rows?.value ?? []);
  return arr.filter((row) =>
    active.every(
      ([k, v]) =>
        String(row?.[k] ?? "").toLowerCase() === String(v).toLowerCase(),
    ),
  );
}

const ok = (result) => ({
  content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
});

// ── MCP server ────────────────────────────────────────────────────────────────

const server = new McpServer({ name: "carbon-compass-mcp", version: "1.0.0" });

server.tool(
  "get_emission_records",
  "Fetch EmissionRecord entries from the ESG HTTP service with optional filters.",
  {
    FacilityId: z.string().optional(),
    ReportingPeriod: z.string().optional(),
    Status: z.string().optional(),
    Scope: z.string().optional(),
  },
  async (args) => {
    const live = await httpGet("records");
    return ok(applyFilters(live ?? STATIC.records, args));
  },
);

server.tool(
  "get_emission_items",
  "Fetch EmissionRecordItem entries for a given EmissionRecordId.",
  { EmissionRecordId: z.string() },
  async ({ EmissionRecordId }) => {
    const live = await httpGet("items");
    return ok(applyFilters(live ?? STATIC.items, { EmissionRecordId }));
  },
);

server.tool(
  "get_facilities",
  "Fetch the list of Facility entities.",
  {},
  async () => {
    const live = await httpGet("facilities");
    return ok(live ?? STATIC.facilities);
  },
);

server.tool(
  "get_emission_factors",
  "Fetch EmissionFactor entries with an optional ActivityType filter.",
  { ActivityType: z.string().optional() },
  async ({ ActivityType }) => {
    const live = await httpGet("factors");
    return ok(applyFilters(live ?? STATIC.factors, { ActivityType }));
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
console.error("carbon-compass-mcp running on stdio");
