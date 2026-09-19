@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Emission Factor - Interface View'
define view entity ZI_EmissionFactor as select from zesg_emfactor
{
    key activity_type as ActivityType,
    description as Description,
    scope as Scope,
    factor_value as FactorValue,
    unit as Unit
}
