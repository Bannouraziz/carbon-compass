import express from 'express';
import fetch from 'node-fetch';
import dotenv from 'dotenv';

dotenv.config();

const { SAP_HOST, SAP_USER, SAP_PASS } = process.env;
// UI OData V4 binding (draft-enabled). For the A2X API binding use:
//   /sap/opu/odata4/sap/zapi_esg_emissionrecord_o4/srvd_a2x/sap/zui_esg_emissionrecord/0001
const SERVICE =
  process.env.SAP_SERVICE ||
  '/sap/opu/odata4/sap/zui_esg_emissionrecord_o4/srvd/sap/zui_esg_emissionrecord/0001';
const AUTH = 'Basic ' + Buffer.from(`${SAP_USER}:${SAP_PASS}`).toString('base64');

// Mock mode: set MOCK=1 (or leave SAP_HOST unset) to serve sample data, no SAP needed.
const MOCK = process.env.MOCK === '1' || !SAP_HOST;
const MOCK_RECORD = {
  EmissionRecordId: '1',
  FacilityId: 'PLANT-BER-01',
  ReportingPeriod: '2025',
  ReportingDate: '2025-12-31',
  Scope: 'Scope 1',
  Status: 'APPROVED',
  TotalCO2e: 1284.512,
  Notes: 'Annual Scope 1 inventory. Diesel figures adjusted after Q3 meter recalibration.',
};
const MOCK_ITEMS = [
  { EmissionRecordItemId: '10', ActivityType: 'Natural Gas', Quantity: 420000, Unit: 'kWh', CO2e: 76.44 },
  { EmissionRecordItemId: '20', ActivityType: 'Diesel', Quantity: 18500, Unit: 'L', CO2e: 49.62 },
  { EmissionRecordItemId: '30', ActivityType: 'Company Fleet', Quantity: 112000, Unit: 'km', CO2e: 21.3 },
  { EmissionRecordItemId: '40', ActivityType: 'Refrigerants', Quantity: 12, Unit: 'kg', CO2e: 1137.15 },
];

const app = express();

// CORS so the ABAP HTTP call (or a browser) can reach this server.
app.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  next();
});

app.use(express.urlencoded({ extended: true, limit: '5mb' }));

async function odata(path) {
  const res = await fetch(`${SAP_HOST}${SERVICE}${path}`, {
    headers: { Authorization: AUTH, Accept: 'application/json' },
  });
  if (!res.ok) {
    const body = await res.text();
    const err = new Error(`${res.status} ${res.statusText}: ${body.slice(0, 500)}`);
    err.status = res.status;
    throw err;
  }
  return res.json();
}

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
  );

const STATUS_COLORS = {
  DRAFT: '#64748b',
  SUBMITTED: '#3b82f6',
  APPROVED: '#22c55e',
  REJECTED: '#ef4444',
};

// Shared page CSS (screen dark dashboard + professional print layout).
const STYLE = `
:root{--bg:#0f172a;--card:#1e293b;--accent:#38bdf8;--text:#e2e8f0;--muted:#94a3b8;--line:#334155}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,Segoe UI,sans-serif;line-height:1.5}
.wrap{max-width:1100px;margin:0 auto;padding:24px 16px}
header{display:flex;flex-wrap:wrap;justify-content:space-between;align-items:flex-start;gap:16px;
border-bottom:1px solid var(--line);padding-bottom:20px}
.logo{font-size:20px;font-weight:700}.logo span{color:var(--accent)}
h1{font-size:15px;font-weight:500;color:var(--muted);margin:4px 0 0}
.badges{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
.badge{background:var(--card);border:1px solid var(--line);border-radius:6px;padding:4px 10px;font-size:13px}
.badge b{color:var(--accent);font-weight:600}
.chip{display:inline-block;padding:4px 12px;border-radius:999px;font-size:12px;font-weight:700;color:#fff}
.ts{color:var(--muted);font-size:12px;margin-top:8px;text-align:right}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin:24px 0}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:20px}
.kpi .v{font-size:28px;font-weight:700;color:var(--accent)}
.kpi .l{color:var(--muted);font-size:13px;margin-top:4px}
.charts{display:grid;grid-template-columns:1fr 1fr;gap:16px}
@media(max-width:760px){.charts{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:20px;margin-bottom:16px}
.card h2{font-size:14px;margin:0 0 16px;color:var(--muted);text-transform:uppercase;letter-spacing:.05em}
table{width:100%;border-collapse:collapse;font-size:14px}
th,td{text-align:left;padding:10px 12px;border-bottom:1px solid var(--line)}
th{color:var(--muted);font-weight:600;font-size:12px;text-transform:uppercase}
td.num,th.num{text-align:right;font-variant-numeric:tabular-nums}
tbody tr:nth-child(even){background:rgba(255,255,255,.02)}
tfoot td{font-weight:700;color:var(--accent);border-top:2px solid var(--line)}
.notes{white-space:pre-wrap;color:var(--muted)}
footer{text-align:center;color:var(--muted);font-size:12px;margin-top:32px;padding-top:16px;border-top:1px solid var(--line)}
.pdfbtn{background:var(--accent);color:#0f172a;border:0;border-radius:8px;padding:8px 16px;
font-size:13px;font-weight:700;cursor:pointer;margin-top:8px}

/* ---- Professional document layout for print / Save-as-PDF ---- */
@page{size:A4;margin:18mm 16mm}
@media print{
  :root{--accent:#0b5e7a}
  *{-webkit-print-color-adjust:exact;print-color-adjust:exact}
  body{background:#fff;color:#1a2330;font-family:Georgia,'Times New Roman',serif}
  .wrap{max-width:none;padding:0}
  .no-print{display:none !important}
  header{border-bottom:2px solid var(--accent);padding-bottom:12px;margin-bottom:18px}
  .logo{font-size:22px;color:#1a2330}.logo span{color:var(--accent)}
  h1{color:#55606e;font-size:13px;letter-spacing:.03em}
  .badge{background:none;border:0;border-right:1px solid #d0d5dd;border-radius:0;
    padding:0 12px 0 0;margin:0;color:#55606e;font-size:11px}
  .badge:last-child{border-right:0}
  .badge b{color:#1a2330}
  .chip{color:#fff !important;border-radius:3px;padding:3px 10px;font-size:11px}
  .ts{color:#8a93a0;font-size:10px}
  .kpis{gap:0;border:1px solid #d0d5dd;border-radius:4px;margin:0 0 20px;
    grid-template-columns:repeat(4,1fr);overflow:hidden}
  .kpi{border:0;border-right:1px solid #d0d5dd;border-radius:0;padding:14px 16px;background:#f7f9fb}
  .kpi:last-child{border-right:0}
  .kpi .v{color:var(--accent);font-size:20px;font-family:Georgia,serif}
  .kpi .l{color:#55606e;font-size:11px;text-transform:uppercase;letter-spacing:.04em}
  .card{border:0;border-radius:0;padding:0;margin:0 0 20px;background:none;break-inside:avoid}
  .card h2{color:#1a2330;font-size:12px;border-bottom:1px solid #d0d5dd;padding-bottom:6px;
    letter-spacing:.06em}
  .charts{gap:24px}
  canvas{max-height:220px}
  table{font-size:11px}
  th,td{border-bottom:1px solid #e2e6ea;padding:6px 8px}
  th{color:#1a2330;border-bottom:1.5px solid #1a2330}
  thead{display:table-header-group}
  tbody tr:nth-child(even){background:#f7f9fb}
  tfoot td{color:var(--accent);border-top:1.5px solid #1a2330}
  tr{break-inside:avoid}
  .notes{color:#1a2330;font-size:12px}
  footer{color:#8a93a0;font-size:10px;border-top:1px solid #d0d5dd;margin-top:24px}
}
`;

function errorPage(title, detail) {
  return `<!doctype html><html><head><meta charset="utf-8"><title>Error</title>
<style>body{background:#0f172a;color:#e2e8f0;font-family:system-ui,sans-serif;display:flex;
align-items:center;justify-content:center;height:100vh;margin:0}
.box{background:#1e293b;padding:40px 48px;border-radius:12px;border-left:4px solid #ef4444;max-width:640px}
h1{color:#ef4444;margin:0 0 12px;font-size:20px}pre{white-space:pre-wrap;color:#94a3b8;font-size:13px}</style>
</head><body><div class="box"><h1>${esc(title)}</h1><pre>${esc(detail)}</pre></div></body></html>`;
}

function reportPage(rec, items) {
  const status = (rec.Status || 'DRAFT').toUpperCase();
  const statusColor = STATUS_COLORS[status] || '#64748b';
  const total = Number(rec.TotalCO2e ?? 0);

  // Aggregate CO2e by ActivityType for the donut.
  const byType = {};
  for (const it of items) {
    const k = it.ActivityType || 'Unknown';
    byType[k] = (byType[k] || 0) + Number(it.CO2e ?? 0);
  }

  const chartData = {
    donutLabels: Object.keys(byType),
    donutValues: Object.values(byType),
    barLabels: items.map((it) => it.ActivityType || it.EmissionRecordItemId || ''),
    barValues: items.map((it) => Number(it.Quantity ?? 0)),
  };

  const itemsRows = items
    .map(
      (it, i) => `<tr>
      <td>${i + 1}</td>
      <td>${esc(it.ActivityType)}</td>
      <td class="num">${esc(it.Quantity)}</td>
      <td>${esc(it.Unit)}</td>
      <td class="num">${Number(it.CO2e ?? 0).toFixed(3)}</td></tr>`
    )
    .join('');

  const itemsTotal = items.reduce((s, it) => s + Number(it.CO2e ?? 0), 0);

  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ESG Emission Report · ${esc(rec.EmissionRecordId)}</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>${STYLE}</style></head>
<body><div class="wrap">
<header>
  <div>
    <div class="logo">Carbon <span>Compass</span></div>
    <h1>ESG Emission Report</h1>
    <div class="badges">
      <div class="badge">Record <b>${esc(rec.EmissionRecordId)}</b></div>
      <div class="badge">Facility <b>${esc(rec.FacilityId)}</b></div>
      <div class="badge">Period <b>${esc(rec.ReportingPeriod)}</b></div>
      <div class="badge">Scope <b>${esc(rec.Scope)}</b></div>
    </div>
  </div>
  <div style="text-align:right">
    <span class="chip" style="background:${statusColor}">${esc(status)}</span>
    <div class="ts">Generated ${new Date().toISOString().replace('T', ' ').slice(0, 19)} UTC</div>
    <button class="pdfbtn no-print" onclick="window.print()">Download PDF</button>
  </div>
</header>

<div class="kpis">
  <div class="kpi"><div class="v">${total.toFixed(3)}</div><div class="l">Total CO2e (tCO2e)</div></div>
  <div class="kpi"><div class="v">${items.length}</div><div class="l">Emission items</div></div>
  <div class="kpi"><div class="v">${esc(rec.ReportingPeriod)}</div><div class="l">Reporting period</div></div>
  <div class="kpi"><div class="v">${esc(rec.Scope)}</div><div class="l">Scope</div></div>
</div>

<div class="charts">
  <div class="card"><h2>CO2e by Activity Type</h2><canvas id="donut"></canvas></div>
  <div class="card"><h2>Quantity per Item</h2><canvas id="bar"></canvas></div>
</div>

<div class="card">
  <h2>Emission Items</h2>
  <table>
    <thead><tr><th>#</th><th>Activity Type</th><th class="num">Quantity</th><th>Unit</th><th class="num">CO2e (tCO2e)</th></tr></thead>
    <tbody>${itemsRows || '<tr><td colspan="5" style="color:var(--muted)">No items</td></tr>'}</tbody>
    <tfoot><tr><td colspan="4">Total</td><td class="num">${itemsTotal.toFixed(3)}</td></tr></tfoot>
  </table>
</div>

${
  rec.Notes
    ? `<div class="card"><h2>Notes</h2><div class="notes">${esc(rec.Notes)}</div></div>`
    : ''
}

<footer>Generated by Carbon Compass · SAP BTP ABAP RAP</footer>
</div>

<script>
const D = ${JSON.stringify(chartData).replace(/</g, '\\u003c')};
const palette = ['#38bdf8','#22c55e','#f59e0b','#ef4444','#a855f7','#14b8a6','#eab308','#f472b6'];
const tick = '#94a3b8', grid = 'rgba(148,163,184,.15)';

const donut = new Chart(document.getElementById('donut'), {
  type: 'doughnut',
  data: { labels: D.donutLabels, datasets: [{ data: D.donutValues, backgroundColor: palette }] },
  options: { plugins: { legend: { labels: { color: tick } } } }
});

const bar = new Chart(document.getElementById('bar'), {
  type: 'bar',
  data: { labels: D.barLabels, datasets: [{ label: 'Quantity', data: D.barValues, backgroundColor: '#0b5e7a' }] },
  options: {
    indexAxis: 'y',
    plugins: { legend: { display: false } },
    scales: {
      x: { ticks: { color: tick }, grid: { color: grid } },
      y: { ticks: { color: tick }, grid: { color: grid } }
    }
  }
});

// Recolor charts for dark screen vs light print.
function theme(printing) {
  const t = printing ? '#1a2330' : tick;
  const g = printing ? 'rgba(26,35,48,.12)' : grid;
  donut.options.plugins.legend.labels.color = t;
  bar.options.scales.x.ticks.color = t;
  bar.options.scales.y.ticks.color = t;
  bar.options.scales.x.grid.color = g;
  bar.options.scales.y.grid.color = g;
  donut.update('none'); bar.update('none');
}
window.addEventListener('beforeprint', () => theme(true));
window.addEventListener('afterprint', () => theme(false));
</script>
</body></html>`;
}

app.get('/report', async (req, res) => {
  // Primary mode: caller passes the full payload in the URL, no SAP call.
  // ?d = base64url( JSON.stringify({ record:{...}, items:[...] }) )
  if (req.query.d) {
    try {
      const payload = JSON.parse(Buffer.from(req.query.d, 'base64url').toString('utf8'));
      return res.send(reportPage(payload.record || {}, payload.items || []));
    } catch (e) {
      return res.status(400).send(errorPage('Invalid data parameter', e.message));
    }
  }

  const id = req.query.id;
  if (!id) return res.status(400).send(errorPage('Missing parameter', 'Provide ?d=<payload> or ?id=<EmissionRecordId>'));
  if (MOCK) return res.send(reportPage({ ...MOCK_RECORD, EmissionRecordId: id }, MOCK_ITEMS));
  try {
    // Draft-enabled BO: active instances use the composite key with IsActiveEntity=true.
    const key = `EmissionRecordId='${encodeURIComponent(id)}',IsActiveEntity=true`;
    const rec = await odata(`/EmissionRecord(${key})`);
    const itemsResp = await odata(`/EmissionRecord(${key})/_Items`);
    const items = itemsResp.value ?? [];
    res.send(reportPage(rec, items));
  } catch (e) {
    if (e.status === 404) {
      return res.status(404).send(errorPage('Not found', `Record ${id} not found`));
    }
    res.status(e.status || 500).send(errorPage('OData request failed', e.message));
  }
});

// ---- Multi-record summary report ----
function summaryPage(records) {
  const n = records.length;
  const totals = records.map((r) => Number(r.TotalCO2e ?? 0));
  const totalCO2e = totals.reduce((s, v) => s + v, 0);
  const avgCO2e = n ? totalCO2e / n : 0;
  const approved = records.filter((r) => String(r.Status).toUpperCase() === 'APPROVED').length;

  const sumBy = (keyFn) => {
    const m = {};
    for (const r of records) {
      const k = keyFn(r) || 'Unknown';
      m[k] = (m[k] || 0) + Number(r.TotalCO2e ?? 0);
    }
    return m;
  };
  const byScope = sumBy((r) => r.Scope);
  const byFacility = sumBy((r) => r.FacilityId);

  // CO2e by reporting period, period sorted ascending.
  const byPeriodMap = sumBy((r) => r.ReportingPeriod);
  const periods = Object.keys(byPeriodMap).sort();

  // Record count by status.
  const statusOrder = ['DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED'];
  const byStatus = {};
  for (const r of records) {
    const k = String(r.Status || 'DRAFT').toUpperCase();
    byStatus[k] = (byStatus[k] || 0) + 1;
  }
  const statusLabels = statusOrder.filter((s) => byStatus[s]);

  const chartData = {
    scopeLabels: Object.keys(byScope),
    scopeValues: Object.values(byScope),
    facLabels: Object.keys(byFacility),
    facValues: Object.values(byFacility),
    periodLabels: periods,
    periodValues: periods.map((p) => byPeriodMap[p]),
    statusLabels,
    statusValues: statusLabels.map((s) => byStatus[s]),
    statusColors: statusLabels.map((s) => STATUS_COLORS[s] || '#64748b'),
  };

  const rows = records
    .map(
      (r, i) => `<tr>
      <td>${i + 1}</td>
      <td>${esc(r.EmissionRecordId)}</td>
      <td>${esc(r.FacilityId)}</td>
      <td>${esc(r.ReportingPeriod)}</td>
      <td>${esc(r.Scope)}</td>
      <td><span class="chip" style="background:${STATUS_COLORS[String(r.Status).toUpperCase()] || '#64748b'}">${esc(r.Status)}</span></td>
      <td class="num">${Number(r.TotalCO2e ?? 0).toFixed(3)}</td></tr>`
    )
    .join('');

  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ESG Emissions Summary</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>${STYLE}</style></head>
<body><div class="wrap">
<header>
  <div>
    <div class="logo">Carbon <span>Compass</span></div>
    <h1>ESG Emissions Summary</h1>
    <div class="badges"><div class="badge">Records <b>${n}</b></div></div>
  </div>
  <div style="text-align:right">
    <div class="ts">Generated ${new Date().toISOString().replace('T', ' ').slice(0, 19)} UTC</div>
    <button class="pdfbtn no-print" onclick="window.print()">Download PDF</button>
  </div>
</header>

<div class="kpis">
  <div class="kpi"><div class="v">${totalCO2e.toFixed(3)}</div><div class="l">Total CO2e (tCO2e)</div></div>
  <div class="kpi"><div class="v">${n}</div><div class="l">Records</div></div>
  <div class="kpi"><div class="v">${avgCO2e.toFixed(3)}</div><div class="l">Avg CO2e / record</div></div>
  <div class="kpi"><div class="v">${approved}</div><div class="l">Approved</div></div>
</div>

<div class="charts">
  <div class="card"><h2>CO2e by Scope</h2><canvas id="scope"></canvas></div>
  <div class="card"><h2>CO2e by Facility</h2><canvas id="facility"></canvas></div>
  <div class="card"><h2>CO2e by Reporting Period</h2><canvas id="period"></canvas></div>
  <div class="card"><h2>Record Count by Status</h2><canvas id="status"></canvas></div>
</div>

<div class="card">
  <h2>Records</h2>
  <table>
    <thead><tr><th>#</th><th>Record ID</th><th>Facility</th><th>Period</th><th>Scope</th><th>Status</th><th class="num">CO2e (tCO2e)</th></tr></thead>
    <tbody>${rows || '<tr><td colspan="7" style="color:var(--muted)">No records</td></tr>'}</tbody>
    <tfoot><tr><td colspan="6">Total</td><td class="num">${totalCO2e.toFixed(3)}</td></tr></tfoot>
  </table>
</div>

<footer>Generated by Carbon Compass · SAP BTP ABAP RAP</footer>
</div>

<script>
const D = ${JSON.stringify(chartData).replace(/</g, '\\u003c')};
const palette = ['#38bdf8','#22c55e','#f59e0b','#ef4444','#a855f7','#14b8a6','#eab308','#f472b6'];
const tick = '#94a3b8', grid = 'rgba(148,163,184,.15)';
const axis = { x:{ticks:{color:tick},grid:{color:grid}}, y:{ticks:{color:tick},grid:{color:grid}} };
const charts = [];

charts.push(new Chart(document.getElementById('scope'), {
  type: 'doughnut',
  data: { labels: D.scopeLabels, datasets: [{ data: D.scopeValues, backgroundColor: palette }] },
  options: { plugins: { legend: { labels: { color: tick } } } }
}));

charts.push(new Chart(document.getElementById('facility'), {
  type: 'bar',
  data: { labels: D.facLabels, datasets: [{ label: 'CO2e', data: D.facValues, backgroundColor: '#38bdf8' }] },
  options: { indexAxis: 'y', plugins: { legend: { display: false } }, scales: axis }
}));

charts.push(new Chart(document.getElementById('period'), {
  type: 'line',
  data: { labels: D.periodLabels, datasets: [{ label: 'CO2e', data: D.periodValues, borderColor: '#38bdf8', backgroundColor: 'rgba(56,189,248,.2)', fill: true, tension: .3 }] },
  options: { plugins: { legend: { display: false } }, scales: axis }
}));

charts.push(new Chart(document.getElementById('status'), {
  type: 'bar',
  data: { labels: D.statusLabels, datasets: [{ label: 'Records', data: D.statusValues, backgroundColor: D.statusColors }] },
  options: { plugins: { legend: { display: false } }, scales: { x: axis.x, y: { ...axis.y, stacked: true, ticks: { ...axis.y.ticks, precision: 0 } }, } }
}));

function theme(p){const t=p?'#1a2330':tick,g=p?'rgba(26,35,48,.12)':grid;charts.forEach(c=>{
  if(c.options.plugins.legend.labels)c.options.plugins.legend.labels.color=t;
  for(const ax of Object.values(c.options.scales||{})){if(ax.ticks)ax.ticks.color=t;if(ax.grid)ax.grid.color=g;}
  c.update('none');});}
window.addEventListener('beforeprint',()=>theme(true));
window.addEventListener('afterprint',()=>theme(false));
</script>
</body></html>`;
}

app.post('/report-batch', (req, res) => {
  const raw = req.body?.payload;
  if (!raw) return res.status(400).send(errorPage('Missing payload', 'POST field "payload" (JSON) is required.'));
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    return res.status(400).send(errorPage('Invalid payload JSON', e.message));
  }
  const records = parsed.records;
  if (!Array.isArray(records) || !records.length) {
    return res.status(400).send(errorPage('No records', 'payload.records must be a non-empty array.'));
  }
  res.send(summaryPage(records));
});

app.get('/', (req, res) => res.redirect('/report?id=1'));

app.listen(3000, () => console.log('Carbon Compass report server on http://localhost:3000'));
