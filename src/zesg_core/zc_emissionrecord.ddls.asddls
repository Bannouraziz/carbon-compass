@EndUserText.label: 'Emission Record - Projection View'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: 'Emission Record', typeNamePlural: 'Emission Records' }
define root view entity ZC_EmissionRecord
  provider contract transactional_query
  as projection on ZI_EmissionRecord
{
      @UI.facet: [
        { id:       'HeaderInfo',
          purpose:  #STANDARD,
          type:     #IDENTIFICATION_REFERENCE,
          label:    'General Information',
          position: 10 },
        { id:            'ItemsFacet',
          purpose:       #STANDARD,
          type:          #LINEITEM_REFERENCE,
          label:         'Emission Items',
          position:      20,
          targetElement: '_Items' }
      ]

      @UI.lineItem: [
        { type: #FOR_ACTION, dataAction: 'submitRecord',    label: 'Submit',          position: 10 },
        { type: #FOR_ACTION, dataAction: 'approveRecord',   label: 'Approve',         position: 20 },
        { type: #FOR_ACTION, dataAction: 'rejectRecord',    label: 'Reject',          position: 30 },
        { type: #FOR_ACTION, dataAction: 'generateReport',  label: 'Generate Report', position: 40 }
      ]

      @UI.identification: [
        { type: #FOR_ACTION, dataAction: 'submitRecord',    label: 'Submit' },
        { type: #FOR_ACTION, dataAction: 'approveRecord',   label: 'Approve' },
        { type: #FOR_ACTION, dataAction: 'rejectRecord',    label: 'Reject' },
        { type: #FOR_ACTION, dataAction: 'generateReport',  label: 'Generate Report' }
      ]

  key EmissionRecordId,

      @UI.lineItem:       [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
      @EndUserText.label: 'Facility'
      FacilityId,

      @UI.lineItem:       [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      @EndUserText.label: 'Reporting Period'
      ReportingPeriod,

      @UI.lineItem:       [{ position: 30 }]
      @UI.identification: [{ position: 30 }]
      @EndUserText.label: 'Scope'
      Scope,

      @UI.lineItem:       [{ position: 40 }]
      @UI.identification: [{ position: 40 }]
      @EndUserText.label: 'Status'
      Status,

      @UI.lineItem:       [{ position: 50 }]
      @UI.identification: [{ position: 50 }]
      @EndUserText.label: 'Total CO2e'
      TotalCO2e,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,

      _Items    : redirected to composition child ZC_EmissionRecordItem,
      _Facility : redirected to ZC_Facility
}
