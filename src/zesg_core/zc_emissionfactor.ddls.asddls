@EndUserText.label: 'Emission Factor - Projection View'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: 'Emission Factor', typeNamePlural: 'Emission Factors' }
define root view entity ZC_EmissionFactor
  provider contract transactional_query
  as projection on ZI_EmissionFactor
{
  key ActivityType,
      Description,
      Scope,
      FactorValue,
      Unit
}
