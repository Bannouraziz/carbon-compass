@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Emission Factor - Interface View'
define root view entity ZI_EmissionFactor as select from zesg_emfactor
{
    key activity_type as ActivityType,
    description as Description,
    scope as Scope,
    factor_value as FactorValue,
   last_changed_at as LastChangedAt,
    unit as Unit
}
