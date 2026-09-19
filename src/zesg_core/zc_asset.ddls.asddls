@EndUserText.label: 'Asset - Projection View'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: 'Asset', typeNamePlural: 'Assets' }
define root view entity ZC_Asset
  provider contract transactional_query
  as projection on ZI_Asset
{
  key AssetId,
      FacilityId,
      AssetName,
      Category,
      _Facility : redirected to ZC_Facility
}
