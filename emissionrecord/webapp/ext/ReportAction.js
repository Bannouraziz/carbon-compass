sap.ui.define(["sap/m/MessageBox"], function (MessageBox) {
	"use strict";

	return {
		openReport: async function (oContext) {
			try {
				var oHeader = oContext.getObject();
				var aItemContexts = await oContext
					.getModel()
					.bindList("_Items", oContext)
					.requestContexts(0, 500);

				var oPayload = {
					record: {
						EmissionRecordId: oHeader.EmissionRecordId,
						FacilityId: oHeader.FacilityId,
						ReportingPeriod: oHeader.ReportingPeriod,
						Scope: oHeader.Scope,
						Status: oHeader.Status,
						TotalCO2e: oHeader.TotalCO2e
					},
					items: aItemContexts.map(function (oItemContext) {
						var oItem = oItemContext.getObject();
						return {
							ActivityType: oItem.ActivityType,
							Quantity: oItem.Quantity,
							Unit: oItem.Unit,
							CO2e: oItem.CO2e
						};
					})
				};

				var d = btoa(unescape(encodeURIComponent(JSON.stringify(oPayload))))
					.replace(/\+/g, "-")
					.replace(/\//g, "_")
					.replace(/=+$/, "");

				window.open("http://localhost:3000/report?d=" + d, "_blank");
			} catch (oError) {
				MessageBox.error(oError.message);
			}
		}
	};
});
