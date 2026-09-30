@AccessControl.authorizationCheck: #NOT_REQUIRED
@AccessControl.auditing.type: #CUSTOM
@AccessControl.auditing.specification: 'User-to-facility assignment for ESG access control'
@EndUserText.label: 'User Facility Assignment'
define root view entity ZI_UserAssignment
  as select from zesg_usr_assign
{
  key user_id     as UserId,
  key facility_id as FacilityId,
      role_type   as RoleType,
            last_changed_at as LastChangedAt
      
}
