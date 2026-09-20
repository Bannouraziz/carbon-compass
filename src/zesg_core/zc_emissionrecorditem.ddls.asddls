@EndUserText.label: 'Emission Record Item - Projection View'
define view entity ZC_EmissionRecordItem
  as projection on ZI_EmissionRecordItem
{
  key EmissionRecordItemId,
      EmissionRecordId,
      AssetId,
      ActivityType,
      Quantity,
      Unit,
      CO2e,
      _EmissionRecord : redirected to parent ZC_EmissionRecord,
      _Asset : redirected to ZC_Asset,
      _EmissionFactor : redirected to ZC_EmissionFactor
}
