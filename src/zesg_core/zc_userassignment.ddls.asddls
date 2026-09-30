@EndUserText.label: 'User Assignment - Projection View'
@Metadata.allowExtensions: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@UI.headerInfo: { typeName: 'User Assignment', typeNamePlural: 'User Assignments' }
define root view entity ZC_UserAssignment
  provider contract transactional_query
  as projection on ZI_UserAssignment
{
      @UI.facet: [
        { id:      'GeneralInfo',
          purpose: #STANDARD,
          type:    #IDENTIFICATION_REFERENCE,
          label:   'Assignment Details',
          position: 10 }
      ]
      
   @UI.lineItem: [{ position: 5 }]
      @EndUserText.label: 'User ID'
     key UserId,
   @UI.lineItem: [{ position: 10 }]
      @EndUserText.label: 'Facility'
    key  FacilityId,

      @UI.lineItem:       [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
      @EndUserText.label: 'Role'
      RoleType,

      LastChangedAt
}
