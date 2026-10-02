sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"esganalytics/test/integration/pages/EmissionAnalyticsList.gen",
	"esganalytics/test/integration/pages/EmissionAnalyticsObjectPage.gen"
], function (JourneyRunner, EmissionAnalyticsListGenerated, EmissionAnalyticsObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('esganalytics') + '/test/flpSandbox.html#esganalytics-tile',
        pages: {
			onTheEmissionAnalyticsListGenerated: EmissionAnalyticsListGenerated,
			onTheEmissionAnalyticsObjectPageGenerated: EmissionAnalyticsObjectPageGenerated
        },
        async: true
    });

    return runner;
});

