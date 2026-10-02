CLASS zcl_esg_seed_data DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_esg_seed_data IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    CONSTANTS lc_records TYPE i VALUE 60.          " how many records to create
    CONSTANTS lc_seeder  TYPE syuname VALUE 'SEEDER'.

    "── 1. Remove data from a previous seed run ───────────────────────────
    DELETE FROM zesg_emrecitm
      WHERE emissionrecord_id IN ( SELECT emissionrecord_id FROM zesg_emrec
                                    WHERE created_by = @lc_seeder ).
    DELETE FROM zesg_emrec WHERE created_by = @lc_seeder.

    "── 2. Master data we reuse ───────────────────────────────────────────
    SELECT activity_type, factor_value FROM zesg_emfactor
      INTO TABLE @DATA(lt_factors).
    IF lt_factors IS INITIAL.
      out->write( 'No emission factors in ZESG_EMFACTOR - seed them first.' ).
      RETURN.
    ENDIF.

    SELECT DISTINCT facility_id FROM zesg_emrec
      INTO TABLE @DATA(lt_fac_db).
    DATA lt_fac TYPE STANDARD TABLE OF zesg_emrec-facility_id WITH EMPTY KEY.
    lt_fac = VALUE #( FOR f IN lt_fac_db ( f-facility_id ) ).
    IF lt_fac IS INITIAL.
      lt_fac = VALUE #( ( 'FAC001' ) ( 'FAC002' ) ( 'FAC003' ) ( 'FAC004' ) ).
    ENDIF.

    DATA(lt_scope)  = VALUE string_table( ( `SCOPE1` ) ( `SCOPE2` ) ( `SCOPE3` ) ).
    DATA(lt_status) = VALUE string_table( ( `DRAFT` ) ( `SUBMITTED` )
                                          ( `APPROVED` ) ( `REJECTED` ) ).
    DATA(lt_period) = VALUE string_table(
      ( `2024-Q1` ) ( `2024-Q2` ) ( `2024-Q3` ) ( `2024-Q4` )
      ( `2025-Q1` ) ( `2025-Q2` ) ( `2025-Q3` ) ( `2025-Q4` ) ).

    DATA(lo_rnd) = cl_abap_random_int=>create( seed = CONV i( sy-uzeit )
                                               min  = 0
                                               max  = 100000 ).

    "── 3. Build records + items ──────────────────────────────────────────
    DATA lt_rec TYPE STANDARD TABLE OF zesg_emrec  WITH EMPTY KEY.
    DATA lt_itm TYPE STANDARD TABLE OF zesg_emrecitm WITH EMPTY KEY.
    DATA lv_ts  TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    DO lc_records TIMES.

      DATA(ls_rec) = VALUE zesg_emrec( ).
      ls_rec-emissionrecord_id = cl_system_uuid=>create_uuid_x16_static( ).
      ls_rec-facility_id       = lt_fac[ lo_rnd->get_next( ) MOD lines( lt_fac ) + 1 ].
      ls_rec-reporting_period  = lt_period[ lo_rnd->get_next( ) MOD lines( lt_period ) + 1 ].
      ls_rec-scope             = lt_scope[ lo_rnd->get_next( ) MOD lines( lt_scope ) + 1 ].
      ls_rec-status            = lt_status[ lo_rnd->get_next( ) MOD lines( lt_status ) + 1 ].
      ls_rec-reporting_date    = cl_abap_context_info=>get_system_date( )
                                 - ( lo_rnd->get_next( ) MOD 365 ).
      ls_rec-created_by        = lc_seeder.
      ls_rec-created_at        = lv_ts.
      ls_rec-last_changed_by   = lc_seeder.
      ls_rec-last_changed_at   = lv_ts.
      ls_rec-local_last_changed_at = lv_ts.

      DATA(lv_items) = 2 + ( lo_rnd->get_next( ) MOD 4 ).   " 2..5 items
      DATA(lv_total) = CONV zesg_emrec-total_co2e( 0 ).

      DO lv_items TIMES.
        DATA(ls_fct) = lt_factors[ lo_rnd->get_next( ) MOD lines( lt_factors ) + 1 ].
        DATA(ls_itm) = VALUE zesg_emrecitm( ).
        ls_itm-emissionrecorditem_id = cl_system_uuid=>create_uuid_x16_static( ).
        ls_itm-emissionrecord_id     = ls_rec-emissionrecord_id.
        ls_itm-activity_type         = ls_fct-activity_type.
        ls_itm-quantity              = 10 + ( lo_rnd->get_next( ) MOD 2000 ).
        ls_itm-unit                  = 'L'.
        ls_itm-co2e                  = ls_itm-quantity * ls_fct-factor_value.
        lv_total = lv_total + ls_itm-co2e.
        APPEND ls_itm TO lt_itm.
      ENDDO.

      ls_rec-total_co2e = lv_total.
      APPEND ls_rec TO lt_rec.
    ENDDO.

    "── 4. Insert ─────────────────────────────────────────────────────────
    INSERT zesg_emrec    FROM TABLE @lt_rec.
    INSERT zesg_emrecitm FROM TABLE @lt_itm.
    COMMIT WORK.

    out->write( |Inserted { lines( lt_rec ) } records and { lines( lt_itm ) } items.| ).

  ENDMETHOD.

ENDCLASS.
