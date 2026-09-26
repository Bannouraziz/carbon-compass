@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Facility - Interface View'
define root view entity ZI_Facility as select from zesg_facility
{
    key facility_id as FacilityId,
    facility_name as FacilityName,
    country as Country,
    business_unit as BusinessUnit,
     last_changed_at as LastChangedAt
}
