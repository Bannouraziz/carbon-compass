@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Emission Analytics Cube'
@Analytics.dataCategory: #CUBE
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_EmissionAnalyticsCube
  as select from ZI_EmissionRecord
{
  key EmissionRecordId,
      FacilityId,
      ReportingPeriod,
      Scope,
      Status,

      @Aggregation.default: #SUM
      TotalCO2e,

      @Aggregation.default: #SUM
      cast( 1 as abap.int4 ) as RecordCount
}
