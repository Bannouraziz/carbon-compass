@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Emission Record - Interface View'
define root view entity ZI_EmissionRecord
  as select from zesg_emrec

  composition [0..*] of ZI_EmissionRecordItem as _Items

  association to ZI_Facility as _Facility
    on $projection.FacilityId = _Facility.FacilityId
{
  key emissionrecord_id  as EmissionRecordId,
      facility_id        as FacilityId,
      reporting_period   as ReportingPeriod,
      scope              as Scope,
      status             as Status,
      total_co2e         as TotalCO2e,

      @Semantics.user.createdBy: true
      created_by         as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at         as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by    as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at    as LastChangedAt,

      _Items,
      _Facility
}
