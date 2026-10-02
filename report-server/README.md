# Carbon Compass ESG Report Server

Local Express server that renders a standalone HTML emission report (charts + tables)
from the SAP BTP ABAP RAP OData V4 service.

## Setup

```bash
npm install
cp .env.example .env   # then edit .env with your SAP credentials
```

`.env`:

| Var        | Example                                                        |
|------------|----------------------------------------------------------------|
| `SAP_HOST` | `https://<host>.abap.<region>.hana.ondemand.com`               |
| `SAP_USER` | communication user (Basic auth)                                |
| `SAP_PASS` | its password                                                   |

> Use a **communication user**, not a dialog/developer user. A dialog user is
> redirected to the browser IDP login and Basic auth is ignored.

## Run

```bash
node server.js
```

Open: <http://localhost:3000/report?id=1>

`/` redirects to `/report?id=1`.

## OData service

```
{SAP_HOST}/sap/opu/odata4/sap/zsb_emission_record/srvd_a2x/sap/zui_emissionrecord/0001
```

- `EmissionRecord(EmissionRecordId='{id}')` — header
- `EmissionRecord(EmissionRecordId='{id}')/_Items` — line items

## Errors

- Fetch fails → error page with HTTP status + message.
- Record missing → "Record {id} not found".
- CORS is open (`*`) so an ABAP HTTP call can reach the server.
