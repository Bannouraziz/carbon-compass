@EndUserText.label: 'Emission Factor - Projection View'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: 'Emission Factor', typeNamePlural: 'Emission Factors' }
define root view entity ZC_EmissionFactor
  provider contract transactional_query
  as projection on ZI_EmissionFactor
{
      @UI.facet: [
        { id:       'GeneralInfo',
          purpose:  #STANDARD,
          type:     #IDENTIFICATION_REFERENCE,
          label:    'General Information',
          position: 10 }
      ]
  key ActivityType,

      @UI.lineItem:       [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
      @EndUserText.label: 'Description'
      Description,

      @UI.lineItem:       [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      @EndUserText.label: 'Scope'
      Scope,

      @UI.lineItem:       [{ position: 30 }]
      @UI.identification: [{ position: 30 }]
      @EndUserText.label: 'Factor Value'
      FactorValue,

      @UI.lineItem:       [{ position: 40 }]
      @UI.identification: [{ position: 40 }]
      @EndUserText.label: 'Unit'
      Unit,
      
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt
      
}
