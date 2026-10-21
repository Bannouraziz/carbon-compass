"! ABAP Unit tests for the Carbon Compass emission record BO (ZI_EmissionRecord).
"!
"! Strategy
"! - The BO is driven through public EML (MODIFY / COMMIT / READ ENTITIES), so the
"!   real determinations, validation, actions and instance authorization run.
"! - ZESG_EMREC / ZESG_EMRECITM are replaced by CDS test doubles; the two tables the
"!   handlers read directly (ZESG_EMFACTOR, ZESG_USR_ASSIGN) by OSQL test doubles.

CLASS ltcl_emission_record DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_item,
        activity_type TYPE zesg_emrecitm-activity_type,
        quantity      TYPE zesg_emrecitm-quantity,
      END OF ty_item,
      tt_items    TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY,
      tt_db_items TYPE STANDARD TABLE OF zesg_emrecitm WITH EMPTY KEY.

    CONSTANTS:
      gc_fac_a TYPE zesg_emrec-facility_id VALUE 'TST-FAC-A',
      gc_fac_b TYPE zesg_emrec-facility_id VALUE 'TST-FAC-B'.

    CLASS-DATA:
      go_cds_env TYPE REF TO if_cds_test_environment,
      go_sql_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS:
      class_setup RAISING cx_static_check,
      class_teardown.

    METHODS:
      setup,
      teardown,

      "-- helpers -----------------------------------------------------------
      create_record
        IMPORTING iv_facility  TYPE zesg_emrec-facility_id DEFAULT gc_fac_a
                  it_items     TYPE tt_items OPTIONAL
        RETURNING VALUE(rv_id) TYPE zesg_emrec-emissionrecord_id,
      commit_entities
        RETURNING VALUE(rv_failed) TYPE abap_bool,
      submit
        IMPORTING iv_id            TYPE zesg_emrec-emissionrecord_id
        RETURNING VALUE(rv_failed) TYPE abap_bool,
      approve
        IMPORTING iv_id            TYPE zesg_emrec-emissionrecord_id
        RETURNING VALUE(rv_failed) TYPE abap_bool,
      reject
        IMPORTING iv_id            TYPE zesg_emrec-emissionrecord_id
        RETURNING VALUE(rv_failed) TYPE abap_bool,
      read_record
        IMPORTING iv_id            TYPE zesg_emrec-emissionrecord_id
        RETURNING VALUE(rs_record) TYPE zesg_emrec,
      status_of
        IMPORTING iv_id            TYPE zesg_emrec-emissionrecord_id
        RETURNING VALUE(rv_status) TYPE zesg_emrec-status,
      total_of
        IMPORTING iv_id           TYPE zesg_emrec-emissionrecord_id
        RETURNING VALUE(rv_total) TYPE zesg_emrec-total_co2e,
      read_items
        IMPORTING iv_id           TYPE zesg_emrec-emissionrecord_id
        RETURNING VALUE(rt_items) TYPE tt_db_items,
      assign_user
        IMPORTING iv_facility TYPE zesg_emrec-facility_id
                  iv_role     TYPE zesg_usr_assign-role_type,

      "-- determinations ------------------------------------------------------
      new_record_gets_draft_and_date  FOR TESTING RAISING cx_static_check,
      item_co2e_is_quantity_x_factor  FOR TESTING RAISING cx_static_check,
      total_is_sum_of_items           FOR TESTING RAISING cx_static_check,
      unknown_activity_gives_zero     FOR TESTING RAISING cx_static_check,
      quantity_change_recalculates    FOR TESTING RAISING cx_static_check,

      "-- validation -------------------------------------------------------------
      submit_fails_for_zero_total     FOR TESTING RAISING cx_static_check,
      submit_works_if_total_positive FOR TESTING RAISING cx_static_check,

      "-- actions -----------------------------------------------------------------
      approve_sets_approved           FOR TESTING RAISING cx_static_check,
      reject_sets_rejected            FOR TESTING RAISING cx_static_check,
      generate_report_fills_notes     FOR TESTING RAISING cx_static_check,

      "-- instance authorization ------------------------------------------------
      no_assignments_full_rights      FOR TESTING RAISING cx_static_check,
      officer_submits_but_no_approve  FOR TESTING RAISING cx_static_check,
      officer_cannot_resubmit         FOR TESTING RAISING cx_static_check,
      auditor_is_read_only            FOR TESTING RAISING cx_static_check,
      manager_approves_submitted      FOR TESTING RAISING cx_static_check,
      manager_cannot_approve_draft    FOR TESTING RAISING cx_static_check,
      other_facility_has_no_access    FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_emission_record IMPLEMENTATION.

  METHOD class_setup.
    go_cds_env = cl_cds_test_environment=>create_for_multiple_cds(
      i_for_entities = VALUE #(
        ( i_for_entity = 'ZI_EMISSIONRECORD' )
        ( i_for_entity = 'ZI_EMISSIONRECORDITEM' ) ) ).

    go_sql_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZESG_EMFACTOR' )
        ( 'ZESG_USR_ASSIGN' ) ) ).

    go_cds_env->enable_double_redirection( ).
  ENDMETHOD.

  METHOD class_teardown.
    go_cds_env->destroy( ).
    go_sql_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    go_cds_env->clear_doubles( ).
    go_sql_env->clear_doubles( ).

    "Known emission factors: 1 L diesel = 0.264, 1 kWh electricity = 0.200
    DATA lt_factors TYPE STANDARD TABLE OF zesg_emfactor WITH EMPTY KEY.
    lt_factors = VALUE #(
      ( activity_type = 'DIESEL' factor_value = '0.26400' unit = 'L' )
      ( activity_type = 'ELEC'   factor_value = '0.20000' unit = 'KWH' ) ).
    go_sql_env->insert_test_data( lt_factors ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.


  "=========================================================================
  " helpers
  "=========================================================================

  METHOD create_record.
    MODIFY ENTITIES OF zi_emissionrecord
      ENTITY EmissionRecord
        CREATE FIELDS ( FacilityId ReportingPeriod Scope )
        WITH VALUE #( ( %cid            = 'REC'
                        FacilityId      = iv_facility
                        ReportingPeriod = '2025-Q1'
                        Scope           = 'SCOPE1' ) )
      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Record creation failed' ).
    rv_id = ls_mapped-emissionrecord[ 1 ]-EmissionRecordId.

    IF it_items IS NOT INITIAL.
      MODIFY ENTITIES OF zi_emissionrecord
        ENTITY EmissionRecord
          CREATE BY \_Items
          FIELDS ( ActivityType Quantity Unit )
          WITH VALUE #( ( EmissionRecordId = rv_id
                          %target = VALUE #( FOR item IN it_items INDEX INTO idx
                                             ( %cid         = |ITM{ idx }|
                                               ActivityType = item-activity_type
                                               Quantity     = item-quantity
                                               Unit         = 'L' ) ) ) )
        FAILED   DATA(ls_failed_items)
        REPORTED DATA(ls_reported_items).

      cl_abap_unit_assert=>assert_initial( act = ls_failed_items msg = 'Item creation failed' ).
    ENDIF.

    cl_abap_unit_assert=>assert_false(
      act = commit_entities( )
      msg = 'Saving the new record failed' ).
  ENDMETHOD.

  METHOD commit_entities.
    COMMIT ENTITIES RESPONSE OF zi_emissionrecord
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).
    rv_failed = xsdbool( ls_failed-emissionrecord IS NOT INITIAL ).
  ENDMETHOD.

  METHOD submit.
    MODIFY ENTITIES OF zi_emissionrecord
      ENTITY EmissionRecord
        EXECUTE submitRecord FROM VALUE #( ( EmissionRecordId = iv_id ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).
    DATA(lv_commit_failed) = commit_entities( ).
    rv_failed = xsdbool( ls_failed-emissionrecord IS NOT INITIAL OR lv_commit_failed = abap_true ).
  ENDMETHOD.

  METHOD approve.
    MODIFY ENTITIES OF zi_emissionrecord
      ENTITY EmissionRecord
        EXECUTE approveRecord FROM VALUE #( ( EmissionRecordId = iv_id ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).
    DATA(lv_commit_failed) = commit_entities( ).
    rv_failed = xsdbool( ls_failed-emissionrecord IS NOT INITIAL OR lv_commit_failed = abap_true ).
  ENDMETHOD.

  METHOD reject.
    MODIFY ENTITIES OF zi_emissionrecord
      ENTITY EmissionRecord
        EXECUTE rejectRecord FROM VALUE #( ( EmissionRecordId = iv_id ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).
    DATA(lv_commit_failed) = commit_entities( ).
    rv_failed = xsdbool( ls_failed-emissionrecord IS NOT INITIAL OR lv_commit_failed = abap_true ).
  ENDMETHOD.

  METHOD read_record.
    "Read the persisted state straight from the (doubled) table.
    SELECT SINGLE * FROM zesg_emrec
      WHERE emissionrecord_id = @iv_id
      INTO @rs_record.
    cl_abap_unit_assert=>assert_subrc( msg = 'Record not found in the table double' ).
  ENDMETHOD.

  METHOD status_of.
    DATA(ls_rec) = read_record( iv_id ).
    rv_status = ls_rec-status.
  ENDMETHOD.

  METHOD total_of.
    DATA(ls_rec) = read_record( iv_id ).
    rv_total = ls_rec-total_co2e.
  ENDMETHOD.

  METHOD read_items.
    SELECT * FROM zesg_emrecitm
      WHERE emissionrecord_id = @iv_id
      ORDER BY emissionrecorditem_id
      INTO TABLE @rt_items.
  ENDMETHOD.

  METHOD assign_user.
    DATA lt_assign TYPE STANDARD TABLE OF zesg_usr_assign WITH EMPTY KEY.
    lt_assign = VALUE #(
      ( user_id = sy-uname facility_id = iv_facility role_type = iv_role ) ).
    go_sql_env->insert_test_data( lt_assign ).
  ENDMETHOD.


  "=========================================================================
  " determinations
  "=========================================================================

  METHOD new_record_gets_draft_and_date.
    DATA(lv_id) = create_record( ).
    DATA(ls_rec) = read_record( lv_id ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_rec-status exp = 'DRAFT'
      msg = 'setInitialRecordValues must set Status = DRAFT' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_rec-reporting_date exp = cl_abap_context_info=>get_system_date( )
      msg = 'setInitialRecordValues must set ReportingDate = today' ).
  ENDMETHOD.

  METHOD item_co2e_is_quantity_x_factor.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    DATA(lt_items) = read_items( lv_id ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ 1 ]-co2e exp = CONV zesg_emrecitm-co2e( '264.000' )
      msg = '1000 L x 0.264 = 264.000' ).
  ENDMETHOD.

  METHOD total_is_sum_of_items.
    DATA(lv_id) = create_record( it_items = VALUE #(
      ( activity_type = 'DIESEL' quantity = 1000 )     "264.000
      ( activity_type = 'ELEC'   quantity = 500 ) ) ). "100.000

    cl_abap_unit_assert=>assert_equals(
      act = total_of( lv_id ) exp = CONV zesg_emrec-total_co2e( '364.000' )
      msg = 'TotalCO2e must equal the sum of all item CO2e' ).
  ENDMETHOD.

  METHOD unknown_activity_gives_zero.
    "Documents CURRENT behaviour: an activity type without a factor yields
    "CO2e = 0 silently. If a validation is added later, update this test.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'NOSUCHFACTOR' quantity = 100 ) ) ).

    DATA(lt_items) = read_items( lv_id ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ 1 ]-co2e exp = CONV zesg_emrecitm-co2e( '0' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = total_of( lv_id ) exp = CONV zesg_emrec-total_co2e( '0' ) ).
  ENDMETHOD.

  METHOD quantity_change_recalculates.
    DATA(lv_id) = create_record( it_items = VALUE #(
      ( activity_type = 'DIESEL' quantity = 1000 )
      ( activity_type = 'ELEC'   quantity = 500 ) ) ).
    DATA(lt_items) = read_items( lv_id ).
    DATA(lv_diesel_item) = lt_items[ activity_type = 'DIESEL' ]-emissionrecorditem_id.

    MODIFY ENTITIES OF zi_emissionrecord
      ENTITY EmissionRecordItem
        UPDATE FIELDS ( Quantity )
        WITH VALUE #( ( EmissionRecordItemId = lv_diesel_item Quantity = 2000 ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).
    cl_abap_unit_assert=>assert_initial( ls_failed ).
    cl_abap_unit_assert=>assert_false( commit_entities( ) ).

    "2000 x 0.264 = 528.000, plus 500 x 0.2 = 100.000
    cl_abap_unit_assert=>assert_equals(
      act = total_of( lv_id ) exp = CONV zesg_emrec-total_co2e( '628.000' ) ).
  ENDMETHOD.


  "=========================================================================
  " validation
  "=========================================================================

  METHOD submit_fails_for_zero_total.
    DATA(lv_id) = create_record( ).   "no items => TotalCO2e = 0

    cl_abap_unit_assert=>assert_true(
      act = submit( lv_id )
      msg = 'validateBeforeSubmit must reject a SUBMITTED record with total <= 0' ).
    cl_abap_unit_assert=>assert_equals(
      act = status_of( lv_id ) exp = 'DRAFT'
      msg = 'The failed save must not persist the SUBMITTED status' ).
  ENDMETHOD.

  METHOD submit_works_if_total_positive.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).

    cl_abap_unit_assert=>assert_false( submit( lv_id ) ).
    cl_abap_unit_assert=>assert_equals( act = status_of( lv_id ) exp = 'SUBMITTED' ).
  ENDMETHOD.


  "=========================================================================
  " actions
  "=========================================================================

  METHOD approve_sets_approved.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    cl_abap_unit_assert=>assert_false( submit( lv_id ) ).
    cl_abap_unit_assert=>assert_false( approve( lv_id ) ).
    cl_abap_unit_assert=>assert_equals( act = status_of( lv_id ) exp = 'APPROVED' ).
  ENDMETHOD.

  METHOD reject_sets_rejected.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    cl_abap_unit_assert=>assert_false( submit( lv_id ) ).
    cl_abap_unit_assert=>assert_false( reject( lv_id ) ).
    cl_abap_unit_assert=>assert_equals( act = status_of( lv_id ) exp = 'REJECTED' ).
  ENDMETHOD.

  METHOD generate_report_fills_notes.
    DATA(lv_id) = create_record( it_items = VALUE #(
      ( activity_type = 'DIESEL' quantity = 1000 )
      ( activity_type = 'ELEC'   quantity = 500 ) ) ).

    MODIFY ENTITIES OF zi_emissionrecord
      ENTITY EmissionRecord
        EXECUTE generateReport FROM VALUE #( ( EmissionRecordId = lv_id ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).
    cl_abap_unit_assert=>assert_initial( ls_failed ).
    cl_abap_unit_assert=>assert_false( commit_entities( ) ).

    DATA(ls_rec) = read_record( lv_id ).
    DATA(lv_notes) = ls_rec-notes.
    cl_abap_unit_assert=>assert_char_cp( act = lv_notes exp = '*ESG EMISSION REPORT*' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_notes exp = |*{ gc_fac_a }*| ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_notes exp = '*364.000*' ).
  ENDMETHOD.


  "=========================================================================
  " instance authorization (get_instance_authorizations)
  "=========================================================================

  METHOD no_assignments_full_rights.
    "ZESG_USR_ASSIGN is empty => the user is treated as owner/admin.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    cl_abap_unit_assert=>assert_false( submit( lv_id ) ).
    cl_abap_unit_assert=>assert_false( approve( lv_id ) ).
  ENDMETHOD.

  METHOD officer_submits_but_no_approve.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    assign_user( iv_facility = gc_fac_a iv_role = 'OFFICER' ).

    cl_abap_unit_assert=>assert_false( act = submit( lv_id ) msg = 'OFFICER may submit a DRAFT' ).
    cl_abap_unit_assert=>assert_true( act = approve( lv_id ) msg = 'OFFICER must not approve' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( lv_id ) exp = 'SUBMITTED' ).
  ENDMETHOD.

  METHOD officer_cannot_resubmit.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    cl_abap_unit_assert=>assert_false( submit( lv_id ) ).       "admin submits
    assign_user( iv_facility = gc_fac_a iv_role = 'OFFICER' ).

    cl_abap_unit_assert=>assert_true(
      act = submit( lv_id )
      msg = 'OFFICER may only submit records in DRAFT' ).
  ENDMETHOD.

  METHOD auditor_is_read_only.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    assign_user( iv_facility = gc_fac_a iv_role = 'AUDITOR' ).

    cl_abap_unit_assert=>assert_true( act = submit( lv_id ) msg = 'AUDITOR must not submit' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( lv_id ) exp = 'DRAFT' ).
  ENDMETHOD.

  METHOD manager_approves_submitted.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    cl_abap_unit_assert=>assert_false( submit( lv_id ) ).       "admin submits
    assign_user( iv_facility = gc_fac_a iv_role = 'MANAGER' ).

    cl_abap_unit_assert=>assert_false( act = approve( lv_id ) msg = 'MANAGER may approve SUBMITTED' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( lv_id ) exp = 'APPROVED' ).
  ENDMETHOD.

  METHOD manager_cannot_approve_draft.
    DATA(lv_id) = create_record( it_items = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    assign_user( iv_facility = gc_fac_a iv_role = 'MANAGER' ).

    cl_abap_unit_assert=>assert_true(
      act = approve( lv_id )
      msg = 'Approval is only enabled for SUBMITTED records' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( lv_id ) exp = 'DRAFT' ).
  ENDMETHOD.

  METHOD other_facility_has_no_access.
    "User is assigned, but only to facility B => no rights on facility A.
    DATA(lv_id) = create_record( iv_facility = gc_fac_a
                                 it_items    = VALUE #( ( activity_type = 'DIESEL' quantity = 1000 ) ) ).
    assign_user( iv_facility = gc_fac_b iv_role = 'MANAGER' ).

    cl_abap_unit_assert=>assert_true( act = submit( lv_id ) msg = 'No assignment for facility A' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( lv_id ) exp = 'DRAFT' ).
  ENDMETHOD.

ENDCLASS.

