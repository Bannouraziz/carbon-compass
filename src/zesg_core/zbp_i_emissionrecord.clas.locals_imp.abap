CLASS lhc_EmissionRecord DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR EmissionRecord RESULT result.

ENDCLASS.

CLASS lhc_EmissionRecord IMPLEMENTATION.

METHOD get_global_authorizations.
  " Permissive stub — grant everything for now.
  " Real persona-based logic comes with the authorization milestone.
  IF requested_authorizations-%create = if_abap_behv=>mk-on.
    result-%create = if_abap_behv=>auth-allowed.
  ENDIF.
  IF requested_authorizations-%update = if_abap_behv=>mk-on.
    result-%update = if_abap_behv=>auth-allowed.
  ENDIF.
  IF requested_authorizations-%delete = if_abap_behv=>mk-on.
    result-%delete = if_abap_behv=>auth-allowed.
  ENDIF.
ENDMETHOD.

ENDCLASS.
