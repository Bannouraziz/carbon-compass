@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Emission Record Item - Interface View'
define view entity ZI_EmissionRecordItem
  as select from zesg_emrecitm

  association to parent ZI_EmissionRecord as _EmissionRecord
    on $projection.EmissionRecordId = _EmissionRecord.EmissionRecordId

  association to ZI_Asset as _Asset
    on $projection.AssetId = _Asset.AssetId

  association to ZI_EmissionFactor as _EmissionFactor
    on $projection.ActivityType = _EmissionFactor.ActivityType
{
  key emissionrecorditem_id as EmissionRecordItemId,
      emissionrecord_id     as EmissionRecordId,
      asset_id              as AssetId,
      activity_type         as ActivityType,
      quantity              as Quantity,
      unit                  as Unit,
      co2e                  as CO2e,

      _EmissionRecord,
      _Asset,
      _EmissionFactor
}
