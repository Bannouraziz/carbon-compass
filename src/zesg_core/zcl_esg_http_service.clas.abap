CLASS zcl_esg_http_service DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_service_extension.
ENDCLASS.

CLASS zcl_esg_http_service IMPLEMENTATION.
  METHOD if_http_service_extension~handle_request.
    DATA lv_entity TYPE string.
    DATA lv_json   TYPE string.

    " Read entity from custom header X-ESG-Entity
    TRY.
        lv_entity = request->get_header_field( 'x-esg-entity' ).
      CATCH cx_root.
        lv_entity = 'records'. " default
    ENDTRY.

    CASE lv_entity.
      WHEN 'records'.
        DATA lt_records TYPE TABLE OF zesg_emrec.
        SELECT * FROM zesg_emrec INTO TABLE @lt_records.
        lv_json = /ui2/cl_json=>serialize(
          data        = lt_records
          pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

      WHEN 'items'.
        DATA lt_items TYPE TABLE OF zesg_emrecitm.
        SELECT * FROM zesg_emrecitm INTO TABLE @lt_items.
        lv_json = /ui2/cl_json=>serialize(
          data        = lt_items
          pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

      WHEN 'facilities'.
        DATA lt_fac TYPE TABLE OF zesg_facility.
        SELECT * FROM zesg_facility INTO TABLE @lt_fac.
        lv_json = /ui2/cl_json=>serialize(
          data        = lt_fac
          pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

      WHEN 'factors'.
        DATA lt_factors TYPE TABLE OF zesg_emfactor.
        SELECT * FROM zesg_emfactor INTO TABLE @lt_factors.
        lv_json = /ui2/cl_json=>serialize(
          data        = lt_factors
          pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

      WHEN OTHERS.
        lv_json = '{"error":"Use header X-ESG-Entity: records|items|facilities|factors"}'.
    ENDCASE.

    response->set_header_field( i_name = 'Content-Type'                i_value = 'application/json' ).
    response->set_header_field( i_name = 'Access-Control-Allow-Origin' i_value = '*' ).
    response->set_text( lv_json ).
  ENDMETHOD.
ENDCLASS.
