# Report Server — URL Parameter Integration

The report server does **not** connect to BTP. The Fiori app already has the
emission record loaded in its binding context, so it passes that data in the
URL and the server renders it. No OData call, no communication user, no
Communication Arrangement.

## The route

```
GET /report?d=<payload>
```

| Param | Required | Meaning |
|-------|----------|---------|
| `d`   | yes | base64url-encoded JSON of the record + items (see below) |

(`?id=<EmissionRecordId>` still works in `MOCK=1` demo mode, but the real
integration uses `d`.)

## Payload shape

```json
{
  "record": {
    "EmissionRecordId": "4500000123",
    "FacilityId": "PLANT-BER-01",
    "ReportingPeriod": "2025",
    "Scope": "Scope 1",
    "Status": "APPROVED",
    "TotalCO2e": 842.5,
    "Notes": "optional free text"
  },
  "items": [
    { "ActivityType": "Diesel",      "Quantity": 18500,  "Unit": "L",   "CO2e": 49.62 },
    { "ActivityType": "Natural Gas", "Quantity": 420000, "Unit": "kWh", "CO2e": 76.44 }
  ]
}
```

`d` = `base64url( JSON.stringify(payload) )`. Any field may be omitted — the
report degrades gracefully (e.g. no `Notes` → the Notes card is skipped).

## Building the URL in the Fiori object page

The controller has the header context and can read the items from the `_Items`
binding. Encode and open:

```js
onOpenReport: function () {
  const ctx = this.getView().getBindingContext();
  const rec = ctx.getObject();                 // header fields

  // items already loaded in the object-page table binding
  const items = this.byId("itemsTable").getBinding("items")
                    .getContexts().map(c => c.getObject());

  const payload = {
    record: {
      EmissionRecordId: rec.EmissionRecordId,
      FacilityId:       rec.FacilityId,
      ReportingPeriod:  rec.ReportingPeriod,
      Scope:            rec.Scope,
      Status:           rec.Status,
      TotalCO2e:        rec.TotalCO2e
    },
    items: items.map(it => ({
      ActivityType: it.ActivityType,
      Quantity:     it.Quantity,
      Unit:         it.Unit,
      CO2e:         it.CO2e
    }))
  };

  // base64url encode (UTF-8 safe)
  const json = JSON.stringify(payload);
  const d = btoa(unescape(encodeURIComponent(json)))
              .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  window.open("https://<report-host>:3000/report?d=" + d, "_blank");
}
```

Wire `onOpenReport` to a custom "Print Report / PDF" header action
(manifest extension + controller extension on the object page). The user then
clicks **Download PDF** on the opened report.

## Generating a test payload (Node)

```bash
node -e 'const p={record:{EmissionRecordId:"1",FacilityId:"PLANT-01",ReportingPeriod:"2025",Scope:"Scope 1",Status:"APPROVED",TotalCO2e:842.5},items:[{ActivityType:"Diesel",Quantity:18500,Unit:"L",CO2e:49.62}]};console.log("http://localhost:3000/report?d="+Buffer.from(JSON.stringify(p)).toString("base64url"))'
```

Open the printed URL.

## Notes / limits

- **URL length.** A base64url payload of a few dozen items is well within
  browser limits (~64k in modern browsers). Hundreds of items could exceed a
  proxy/gateway cap — if you ever hit that, switch back to the server-side
  OData fetch (that code path is still in `server.js`).
- **CORS.** The server sends `Access-Control-Allow-Origin: *`. For a shared
  deployment put it behind HTTPS and set the launchpad origin explicitly.
- **No secrets anywhere.** Because the app supplies the data, the report host
  holds no SAP credentials.
