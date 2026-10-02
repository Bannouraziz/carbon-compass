sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zesg/emissionrecord/test/integration/pages/EmissionRecordList.gen",
	"zesg/emissionrecord/test/integration/pages/EmissionRecordObjectPage.gen",
	"zesg/emissionrecord/test/integration/pages/EmissionRecordItemObjectPage.gen"
], function (JourneyRunner, EmissionRecordListGenerated, EmissionRecordObjectPageGenerated, EmissionRecordItemObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zesg/emissionrecord') + '/test/flpSandbox.html#zesgemissionrecord-tile',
        pages: {
			onTheEmissionRecordListGenerated: EmissionRecordListGenerated,
			onTheEmissionRecordObjectPageGenerated: EmissionRecordObjectPageGenerated,
			onTheEmissionRecordItemObjectPageGenerated: EmissionRecordItemObjectPageGenerated
        },
        async: true
    });

    return runner;
});

