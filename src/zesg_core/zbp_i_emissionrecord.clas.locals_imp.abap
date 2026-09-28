CLASS lhc_emissionrecorditem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateItemCO2e FOR DETERMINE ON SAVE
      keys FOR EmissionRecordItem~calculateItemCO2e.


ENDCLASS.

CLASS lhc_emissionrecorditem IMPLEMENTATION.

  METHOD calculateItemCO2e.
    " 1. Calculate each item's CO2e
    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecordItem
        FIELDS ( ActivityType Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items INTO DATA(ls_item).
      SELECT SINGLE factor_value
        FROM zesg_emfactor
        WHERE activity_type = @ls_item-ActivityType
        INTO @DATA(lv_factor).

      DATA(lv_co2e) = ls_item-Quantity * lv_factor.

      MODIFY ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
        ENTITY EmissionRecordItem
          UPDATE FIELDS ( CO2e )
          WITH VALUE #( ( %tky = ls_item-%tky
                          CO2e  = lv_co2e ) ).
    ENDLOOP.

    " 2. Find the parent record(s) of these items
    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecordItem BY \_EmissionRecord
        FIELDS ( EmissionRecordId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_parents).

    " 3. For each parent, sum all its items' CO2e into TotalCO2e
    DATA lt_totals TYPE TABLE FOR UPDATE ZI_EmissionRecord.

    LOOP AT lt_parents INTO DATA(ls_parent).
      READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
        ENTITY EmissionRecord BY \_Items
          FIELDS ( CO2e )
          WITH VALUE #( ( %tky-EmissionRecordId = ls_parent-EmissionRecordId ) )
        RESULT DATA(lt_siblings).

      DATA lv_total TYPE p LENGTH 8 DECIMALS 3.
      CLEAR lv_total.
      LOOP AT lt_siblings INTO DATA(ls_sib).
        lv_total = lv_total + ls_sib-CO2e.
      ENDLOOP.

      APPEND VALUE #( EmissionRecordId = ls_parent-EmissionRecordId
                      TotalCO2e        = lv_total ) TO lt_totals.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        UPDATE FIELDS ( TotalCO2e )
        WITH lt_totals.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_EmissionRecord DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR EmissionRecord RESULT result.




    METHODS submitRecord FOR MODIFY
      keys FOR ACTION EmissionRecord~submitRecord RESULT result.

    METHODS validateBeforeSubmit FOR VALIDATE ON SAVE
      keys FOR EmissionRecord~validateBeforeSubmit.

          METHODS approveRecord FOR MODIFY
      keys FOR ACTION EmissionRecord~approveRecord RESULT result.

    METHODS rejectRecord FOR MODIFY
      keys FOR ACTION EmissionRecord~rejectRecord RESULT result.


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





  METHOD submitRecord.
    MODIFY ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys
                      ( %tky = key-%tky Status = 'SUBMITTED' ) ).

    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_records).

    result = VALUE #( FOR rec IN lt_records
                      ( %tky = rec-%tky %param = rec ) ).
  ENDMETHOD.




  METHOD validateBeforeSubmit.
    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        FIELDS ( Status TotalCO2e )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_records).

    LOOP AT lt_records INTO DATA(ls_rec).
      IF ls_rec-Status = 'SUBMITTED' AND ls_rec-TotalCO2e <= 0.
        APPEND VALUE #( %tky = ls_rec-%tky ) TO failed-emissionrecord.
        APPEND VALUE #( %tky = ls_rec-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Cannot submit a record with zero total emissions' ) )
               TO reported-emissionrecord.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD approveRecord.
    MODIFY ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys
                      ( %tky = key-%tky Status = 'APPROVED' ) ).

    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_records).

    result = VALUE #( FOR rec IN lt_records
                      ( %tky = rec-%tky %param = rec ) ).
  ENDMETHOD.

  METHOD rejectRecord.
    MODIFY ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys
                      ( %tky = key-%tky Status = 'REJECTED' ) ).

    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_records).

    result = VALUE #( FOR rec IN lt_records
                      ( %tky = rec-%tky %param = rec ) ).
  ENDMETHOD.
ENDCLASS.
