CLASS zcl_esg_seed_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_esg_seed_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lt_assign TYPE TABLE OF zesg_usr_assign.

    lt_assign = VALUE #(
      ( client = '100' user_id = 'CB9980000313' facility_id = 'FR-LYO-01' role_type = 'OFFICER' )
      ( client = '100' user_id = 'CB9980000313' facility_id = 'NL-ROO-01' role_type = 'MANAGER' )
      ( client = '100' user_id = 'CB9980000313' facility_id = 'FR-PAR-01' role_type = 'AUDITOR' )
    ).

    DELETE FROM zesg_usr_assign.
    INSERT zesg_usr_assign FROM TABLE @lt_assign.

    IF sy-subrc = 0.
      out->write( 'User assignments inserted successfully.' ).
    ELSE.
      out->write( |Insert failed: { sy-subrc }| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
