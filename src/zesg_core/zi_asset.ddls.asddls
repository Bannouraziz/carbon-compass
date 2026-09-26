@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Asset - Interface View'

define root view entity ZI_Asset
  as select from zesg_asset
  association to ZI_Facility as _Facility
    on $projection.FacilityId = _Facility.FacilityId
{
  key asset_id      as AssetId,
      facility_id   as FacilityId,
      asset_name    as AssetName,
      asset_type    as Category,
      last_changed_at as LastChangedAt,
      _Facility
}
