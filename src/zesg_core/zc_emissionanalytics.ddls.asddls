@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Emission Analytics'
@Metadata.ignorePropagatedAnnotations: true

@UI.chart: [
  { qualifier: 'ByScope', title: 'CO2e by Scope', chartType: #DONUT,
    dimensions: ['Scope'], measures: ['TotalCO2e'],
    dimensionAttributes: [{ dimension: 'Scope', role: #CATEGORY }],
    measureAttributes:   [{ measure: 'TotalCO2e', role: #AXIS_1 }] },
  { qualifier: 'ByFacility', title: 'CO2e by Facility', chartType: #BAR,
    dimensions: ['FacilityId'], measures: ['TotalCO2e'],
    dimensionAttributes: [{ dimension: 'FacilityId', role: #CATEGORY }],
    measureAttributes:   [{ measure: 'TotalCO2e', role: #AXIS_1 }] }
]
@UI.presentationVariant: [{
  qualifier: 'default',
  maxItems: 200,
  sortOrder: [{ by: 'ReportingPeriod', direction: #DESC }],
  visualizations: [
    { type: #AS_CHART, qualifier: 'ByFacility' },
    { type: #AS_LINEITEM }
  ]
}]
@UI.selectionVariant: [{ qualifier: 'allRecords', text: 'All records' }]

define view entity ZC_EmissionAnalytics
  as select from ZI_EmissionAnalyticsCube
{
      @UI.selectionField: [{ position: 10 }]
      @UI.lineItem:       [{ position: 10 }]
  key EmissionRecordId,

      @UI.selectionField: [{ position: 20 }]
      @UI.lineItem:       [{ position: 20 }]
      FacilityId,

      @UI.selectionField: [{ position: 30 }]
      @UI.lineItem:       [{ position: 30 }]
      ReportingPeriod,

      @UI.selectionField: [{ position: 40 }]
      @UI.lineItem:       [{ position: 40 }]
      Scope,

      @UI.selectionField: [{ position: 50 }]
      @UI.lineItem:       [{ position: 50 }]
      Status,

      @UI.lineItem:  [{ position: 60 }]
      @UI.dataPoint: { qualifier: 'TotalCO2eDP', title: 'Total CO2e (t)',
                       valueFormat: { numberOfFractionalDigits: 1 } }
      @Aggregation.default: #SUM
      TotalCO2e,

      @UI.dataPoint: { qualifier: 'RecordCountDP', title: 'Records' }
      @Aggregation.default: #SUM
      RecordCount
}
