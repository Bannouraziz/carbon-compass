CLASS lhc_emissionrecorditem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateItemCO2e FOR DETERMINE ON SAVE
      keys FOR EmissionRecordItem~calculateItemCO2e.

ENDCLASS.

CLASS lhc_emissionrecorditem IMPLEMENTATION.

  METHOD calculateItemCO2e.
    " 1. Calculate each item CO2e
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

    " 2. Find parent records
    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecordItem BY \_EmissionRecord
        FIELDS ( EmissionRecordId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_parents).

    " 3. Sum all sibling items CO2e into TotalCO2e on parent
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

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR EmissionRecord RESULT result.

    METHODS setInitialRecordValues FOR DETERMINE ON MODIFY
      keys FOR EmissionRecord~setInitialRecordValues.

    METHODS submitRecord FOR MODIFY
      keys FOR ACTION EmissionRecord~submitRecord RESULT result.

    METHODS approveRecord FOR MODIFY
      keys FOR ACTION EmissionRecord~approveRecord RESULT result.

    METHODS rejectRecord FOR MODIFY
      keys FOR ACTION EmissionRecord~rejectRecord RESULT result.

    METHODS generateReport FOR MODIFY
      keys FOR ACTION EmissionRecord~generateReport RESULT result.

    METHODS validateBeforeSubmit FOR VALIDATE ON SAVE
      keys FOR EmissionRecord~validateBeforeSubmit.

ENDCLASS.

CLASS lhc_EmissionRecord IMPLEMENTATION.

  METHOD get_instance_authorizations.

    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        FIELDS ( FacilityId Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_records).

    SELECT COUNT(*) FROM zesg_usr_assign
      WHERE user_id = @sy-uname
      INTO @DATA(lv_total_assignments).

    DATA(lv_is_unassigned_owner) = xsdbool( lv_total_assignments = 0 ).

    LOOP AT lt_records INTO DATA(ls_rec).

      DATA lv_role TYPE zesg_usr_assign-role_type.
      CLEAR lv_role.

      IF lv_is_unassigned_owner = abap_false.
        SELECT SINGLE role_type
          FROM zesg_usr_assign
          WHERE user_id     = @sy-uname
            AND facility_id = @ls_rec-FacilityId
          INTO @lv_role.
      ENDIF.

      DATA lv_granted     TYPE abp_behv_flag.
      DATA lv_can_approve TYPE abp_behv_flag.
      DATA lv_can_submit  TYPE abp_behv_flag.

      IF lv_is_unassigned_owner = abap_true.
        "No assignments at all → treat as owner / admin
        lv_granted     = if_abap_behv=>fc-o-enabled.
        lv_can_approve = if_abap_behv=>fc-o-enabled.
        lv_can_submit  = if_abap_behv=>fc-o-enabled.

      ELSEIF sy-subrc <> 0.
        "User has assignments but none for this facility
        lv_granted     = if_abap_behv=>fc-o-disabled.
        lv_can_approve = if_abap_behv=>fc-o-disabled.
        lv_can_submit  = if_abap_behv=>fc-o-disabled.

      ELSEIF lv_role = 'AUDITOR'.
        lv_granted     = if_abap_behv=>fc-o-disabled.
        lv_can_approve = if_abap_behv=>fc-o-disabled.
        lv_can_submit  = if_abap_behv=>fc-o-disabled.

      ELSEIF lv_role = 'OFFICER'.
        lv_granted     = if_abap_behv=>fc-o-enabled.
        lv_can_approve = if_abap_behv=>fc-o-disabled.
        lv_can_submit  = COND #(
          WHEN ls_rec-Status = 'DRAFT' THEN if_abap_behv=>fc-o-enabled
          ELSE                              if_abap_behv=>fc-o-disabled ).

      ELSEIF lv_role = 'MANAGER'.
        lv_granted     = if_abap_behv=>fc-o-enabled.
        lv_can_approve = COND #(
          WHEN ls_rec-Status = 'SUBMITTED' THEN if_abap_behv=>fc-o-enabled
          ELSE                                  if_abap_behv=>fc-o-disabled ).
        lv_can_submit  = COND #(
          WHEN ls_rec-Status = 'DRAFT' THEN if_abap_behv=>fc-o-enabled
          ELSE                              if_abap_behv=>fc-o-disabled ).

      ELSE.
        lv_granted     = if_abap_behv=>fc-o-disabled.
        lv_can_approve = if_abap_behv=>fc-o-disabled.
        lv_can_submit  = if_abap_behv=>fc-o-disabled.
      ENDIF.

      APPEND VALUE #(
        %tky                    = ls_rec-%tky
        %update                 = lv_granted
        %delete                 = lv_granted
        %action-Edit            = lv_granted
        %action-submitRecord    = lv_can_submit
        %action-approveRecord   = lv_can_approve
        %action-rejectRecord    = lv_can_approve
        %action-generateReport  = lv_granted
      ) TO result.

    ENDLOOP.

  ENDMETHOD.

  METHOD setInitialRecordValues.

    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        FIELDS ( Status ReportingDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_records).

    DATA lt_update TYPE TABLE FOR UPDATE ZI_EmissionRecord\\EmissionRecord.

    LOOP AT lt_records INTO DATA(ls_rec).
      APPEND VALUE #(
        %tky                   = ls_rec-%tky
        Status                 = 'DRAFT'
        ReportingDate          = cl_abap_context_info=>get_system_date( )
        %control-Status        = if_abap_behv=>mk-on
        %control-ReportingDate = if_abap_behv=>mk-on
      ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
        ENTITY EmissionRecord
          UPDATE FIELDS ( Status ReportingDate )
          WITH lt_update
        REPORTED DATA(ls_rep).
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

  METHOD generateReport.
    "────────────────────────────────────────────────────────────────────────
    " generateReport action
    " Writes a plain-text summary into the Notes field.
    " The actual HTML/chart report is the standalone ESG dashboard page
    " opened separately in the browser.
    "────────────────────────────────────────────────────────────────────────

    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        FIELDS ( EmissionRecordId FacilityId ReportingPeriod Scope Status TotalCO2e )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_records).

    CHECK lt_records IS NOT INITIAL.

    DATA lt_update TYPE TABLE FOR UPDATE ZI_EmissionRecord\\EmissionRecord.

    LOOP AT lt_records INTO DATA(ls_rec).
      DATA(lv_note) =
        |=== ESG EMISSION REPORT ===| && cl_abap_char_utilities=>newline &&
        |Facility   : { ls_rec-FacilityId }| && cl_abap_char_utilities=>newline &&
        |Period     : { ls_rec-ReportingPeriod }| && cl_abap_char_utilities=>newline &&
        |Scope      : { ls_rec-Scope }| && cl_abap_char_utilities=>newline &&
        |Status     : { ls_rec-Status }| && cl_abap_char_utilities=>newline &&
        |Total CO2e : { ls_rec-TotalCO2e } tCO2e| && cl_abap_char_utilities=>newline &&
        |Generated  : { cl_abap_context_info=>get_system_date( ) }| && cl_abap_char_utilities=>newline &&
        |===========================|.

      APPEND VALUE #(
        %tky           = ls_rec-%tky
        Notes          = lv_note
        %control-Notes = if_abap_behv=>mk-on
      ) TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        UPDATE FIELDS ( Notes )
        WITH lt_update.

    READ ENTITIES OF ZI_EmissionRecord IN LOCAL MODE
      ENTITY EmissionRecord
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result (
      %tky   = ls-%tky
      %param = ls
    ) ).

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
                                 text     = 'Cannot submit: total CO2e must be greater than zero' ) )
               TO reported-emissionrecord.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

