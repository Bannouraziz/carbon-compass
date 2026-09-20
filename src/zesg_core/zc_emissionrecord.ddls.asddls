@EndUserText.label: 'Emission Record - Projection View'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: 'Emission Record', typeNamePlural: 'Emission Records' }
define root view entity ZC_EmissionRecord
  provider contract transactional_query
  as projection on ZI_EmissionRecord
{
  key EmissionRecordId,
      FacilityId,
      ReportingPeriod,
      Scope,
      Status,
      TotalCO2e,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      _Items : redirected to composition child ZC_EmissionRecordItem,
      _Facility : redirected to ZC_Facility
}
