@EndUserText.label: 'Facility - Projection View'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: 'Facility', typeNamePlural: 'Facilities' }
define root view entity ZC_Facility
  provider contract transactional_query
  as projection on ZI_Facility
{
  key FacilityId,
      FacilityName,
      Country,
      BusinessUnit
}
