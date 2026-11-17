CLASS zcl_test DEFINITION
    PUBLIC

  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES : BEGIN OF itab,
              tarih(10),
              kod(3),
              currencycode(3),
              unit(5),
              isim(30),
              currencyname(30),
              forexbuying(15),
              forexselling(15),
              banknotebuying(15),
              banknoteselling(15),
              crossrateusd(10),
              crossrateother(10),
              crossrateeuro(10),
            END OF itab,
            tt_itab TYPE STANDARD TABLE OF itab.
    DATA : gv_kurtarih(10) TYPE c.
    DATA : gs_itab TYPE itab.

    DATA : gv_node TYPE REF TO if_ixml_node.
    DATA : gv_first_time.
    DATA : gv_nodetext TYPE string.

    METHODS: create_datatable  IMPORTING x_node  TYPE REF TO if_ixml_node
                               CHANGING  yt_item TYPE tt_itab.
    METHODS: kur_insert  IMPORTING p0  TYPE any
                                   p1  TYPE any
                                   p2  TYPE any
                                   p3  TYPE any
                                   p4  TYPE any
                                   p56 TYPE any
                                   p7  TYPE any
                                   p8  TYPE any.
    METHODS adjust_to_friday
      CHANGING cv_date TYPE d.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_TEST IMPLEMENTATION.


  METHOD adjust_to_friday.
    DATA: lv_year    TYPE i,
          lv_month   TYPE i,
          lv_day     TYPE i,
          lv_offset  TYPE i,
          lv_weekday TYPE i.

    lv_year  = cv_date+0(4).
    lv_month = cv_date+4(2).
    lv_day   = cv_date+6(2).

    IF lv_month < 3.
      lv_year = lv_year - 1.
    ENDIF.

    CASE lv_month.
      WHEN 1.  lv_offset = 0.
      WHEN 2.  lv_offset = 3.
      WHEN 3.  lv_offset = 2.
      WHEN 4.  lv_offset = 5.
      WHEN 5.  lv_offset = 0.
      WHEN 6.  lv_offset = 3.
      WHEN 7.  lv_offset = 5.
      WHEN 8.  lv_offset = 1.
      WHEN 9.  lv_offset = 4.
      WHEN 10. lv_offset = 6.
      WHEN 11. lv_offset = 2.
      WHEN 12. lv_offset = 4.
    ENDCASE.

    lv_weekday = (
        lv_year
      + lv_year DIV 4
      - lv_year DIV 100
      + lv_year DIV 400
      + lv_offset
      + lv_day ) MOD 7.

    IF lv_weekday = 6.
      cv_date = cv_date - 1.
    ELSEIF lv_weekday = 0.
      cv_date = cv_date - 2.
    ENDIF.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.

      DATA: cv_date TYPE datum VALUE '20260428'.
      DATA: pr_kurtr TYPE datum VALUE '20260428'.
    DATA lv_url TYPE string.
    DATA: gv_status      TYPE i                   ,  " programın işleyiş durumu
          gv_statxt(100) TYPE c.
*    lv_url = 'https://www.tcmb.gov.tr/kurlar/' && pr_kurtr(6) && '/' && pr_kurtr+6(2) && pr_kurtr+4(2) &&  pr_kurtr(4) && '.xml'.
*https://dap-yapi-subaccount-mxwqnzlc.it-cpi026-rt.cfapps.eu10-002.hana.ondemand.com/http/Get_Exchange_Rates?month=202603&datum=24032026
    SELECT SINGLE Link
    FROM zbct_is_links
    WHERE business_key = 'EXCHANGERATESDEV'
    INTO @lv_url.
    lv_url = lv_url && '?month='
                       && pr_kurtr(6)
                       && '&datum='
                       && pr_kurtr+6(2) && pr_kurtr+4(2) && pr_kurtr(4).
    CONDENSE lv_url.

    " HTTP Destination oluştur
    DATA lo_destination TYPE REF TO if_http_destination.
    TRY.
        lo_destination = cl_http_destination_provider=>create_by_url( lv_url ).
      CATCH cx_http_dest_provider_error INTO DATA(lx_dest).
        gv_status = 2.
        gv_statxt = lx_dest->get_text( ).
*           ls_lg-test =   gv_statxt.
*          INSERT ZTEST FROM @ls_lg.
*          COMMIT WORK.
        RETURN.
    ENDTRY.

    " HTTP Client oluştur
    DATA lo_client TYPE REF TO if_web_http_client.
    TRY.
        lo_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
      CATCH cx_web_http_client_error INTO DATA(lx_client).
        gv_status = 2.
        gv_statxt = lx_client->get_text( ).
*    ls_lg-test =   gv_statxt.
*          INSERT ZTEST FROM @ls_lg.
*          COMMIT WORK.
        RETURN.
    ENDTRY.

    " *** KRİTİK: Authorization header ekle ***
    DATA lv_username TYPE string.
    DATA lv_password TYPE string.

    SELECT SINGLE *
    FROM zbct_is_info
    WHERE sys_id EQ 'DEV'
    INTO @DATA(ls_info).
    lv_username  = ls_info-username.
    lv_password = ls_info-password.
*    lv_username = 'sb-cfd15ebf-4aaa-4aae-a4e4-6564231bf966!b646061|it-rt-dap-yapi-subaccount-mxwqnzlc!b410603'.
*
*    lv_password  =  '09e5f3da-aad9-4882-9c21-9b92ebc8ce49$VgAGbVc_rxh3YlRJLakOBNSbReNKVxJHi5_xHXj0ltk='.

    DATA(lv_auth) = |Basic { cl_web_http_utility=>encode_base64( |{ lv_username }:{ lv_password }| ) }|.

    " Header set et - i_name / i_value kullan
    DATA(lo_request) = lo_client->get_http_request( ).
    lo_request->set_header_field( i_name  = 'Authorization' i_value = lv_auth ).
*lo_request->set_header_field( i_name  = 'month'         i_value = pr_kurtr(6) ).
*lo_request->set_header_field( i_name  = 'datum'         i_value = pr_kurtr+6(2) && pr_kurtr+4(2) && pr_kurtr(4) ).
    " İsteği gönder
    DATA lo_response TYPE REF TO if_web_http_response.
    TRY.
        lo_response = lo_client->execute( i_method = if_web_http_client=>get ).
      CATCH cx_web_http_client_error INTO DATA(lx_exec).
        gv_status = 2.
        gv_statxt = lx_exec->get_text( ).
*    ls_lg-test =   gv_statxt.
*          INSERT ZTEST FROM @ls_lg.
*          COMMIT WORK.
        RETURN.
    ENDTRY.

    " Response kontrol et
    DATA(ls_status) = lo_response->get_status( ).
    IF ls_status-code <> 200.
      gv_status = 2.
      gv_statxt = |HTTP Error: { ls_status-code } - { ls_status-reason }|.
*    ls_lg-test =   gv_statxt.
*          INSERT ZTEST FROM @ls_lg.
*          COMMIT WORK.
      RETURN.
    ENDIF.

    DATA(ld_text) = lo_response->get_text( ).
    IF ld_text IS INITIAL.
      gv_status = 2.
      gv_statxt = 'Response boş geldi!'.
*    ls_lg-test =   gv_statxt.
*          INSERT ZTEST FROM @ls_lg.
*          COMMIT WORK.
      COMMIT WORK.
      RETURN.
    ENDIF.

    " XML Parse
    DATA(g_ixml)         = cl_ixml_core=>create( ).
    DATA(streamfactory)  = g_ixml->create_stream_factory( ).
    DATA(xstring)        = cl_abap_conv_codepage=>create_out( )->convert( source = ld_text ).
    DATA(istream)        = streamfactory->create_istream_xstring( string = xstring ).
    DATA(document)       = g_ixml->create_document( ).
    DATA(parser)         = g_ixml->create_parser( stream_factory = streamfactory
                                                  istream        = istream
                                                  document       = document ).

    DATA(parsed) = parser->parse( ).
    IF parsed <> 0.
      gv_status = 2.
      gv_statxt = 'XML parse hatası!'.
      RETURN.
    ENDIF.

    " Datatable oluştur
    DATA lt_itab TYPE tt_itab.
    DATA(lv_node) = CAST if_ixml_node( document ).
    gv_first_time = 'X'.
    create_datatable( EXPORTING x_node = lv_node CHANGING yt_item = lt_itab ).

    DATA(lines1) = lines( lt_itab ).
    DATA(lv_mes) = |Toplam kayıt: { lines1 }|.

*    ls_lg-test = LINES( lt_itab ) .
*    CONDENSE     ls_lg-test.
*        ls_lg-test =     ls_lg-test && 'İTAB'.
*          INSERT ZTEST FROM @ls_lg.
*          COMMIT WORK.
*     LOOP AT  so_rate  INTO DATA(LS_RT).
*             ls_lg-test =  LS_RT-low.
*          INSERT ZTEST FROM @ls_lg.
*          COMMIT WORK.
*     ENDLOOP.
    " Kurları kaydet
    LOOP AT lt_itab ASSIGNING FIELD-SYMBOL(<kur>).
      "döviz alış

        .
        kur_insert( EXPORTING p0  = 'direct'
                              p1  = 'M'
                              p2  = <kur>-kod
                              p3  = 'TRY'
                              p4  = pr_kurtr
                              p56 = <kur>-forexbuying
                              p7  = <kur>-unit
                              p8  = 1 ).


    ENDLOOP.


    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
    COMMIT WORK.


*    DATA: cv_date TYPE datum VALUE '20260425'.
*
*  DATA lv_is_holiday TYPE abap_boolean.
*DATA lv_weekday    TYPE i.
*DATA lv_ref_date   TYPE d VALUE '20240101'. " Pazartesi
*DATA lv_diff       TYPE i.
*
*DO.
*  " 1) Tatil mi?
*  TRY.
*      DATA(lo_holiday_rt) = cl_fhc_calendar_runtime=>create_holidaycalendar_runtime(
*                              iv_holidaycalendar_id = 'Z_TR' ).
*      lv_is_holiday = lo_holiday_rt->is_holiday( iv_date = cv_date ).
*      IF lv_is_holiday = abap_true.
*        cv_date = cv_date - 1.
*        CONTINUE.
*      ENDIF.
*    CATCH cx_fhc_runtime INTO DATA(lx_error).
*      out->write( |Takvim Hatası: { lx_error->get_text( ) }| ).
*      RETURN.
*  ENDTRY.
*
*  " 2) Hafta sonu kontrolü
*  " Referans: 20240101 = Pazartesi
*  " Farkı al, MOD 7 yap → 0=Pzt, 1=Sal, 2=Car, 3=Per, 4=Cum, 5=Cmt, 6=Paz
*  lv_diff = cv_date - lv_ref_date.
*  lv_weekday = ( ( lv_diff MOD 7 ) + 7 ) MOD 7.
*
*  IF lv_weekday = 5.        " Cumartesi
*    cv_date = cv_date - 1.
*    CONTINUE.
*  ELSEIF lv_weekday = 6.    " Pazar
*    cv_date = cv_date - 2.
*    CONTINUE.
*  ELSEIF lv_weekday = 0.    " Pazartesi
*    cv_date = cv_date - 3.
*    CONTINUE.
*  ENDIF.
*
*  EXIT.
*ENDDO.
*
**   DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
**    DATA lv_is_holiday TYPE abap_boolean.
***    DATA lo_holiday_rt TYPE REF TO IF_FHC_HOLIDAY_RUNTIME.
**
**    TRY.
**
**        DATA(lo_holiday_rt) = cl_fhc_calendar_runtime=>create_holidaycalendar_runtime( iv_holidaycalendar_id = 'Z_TR' ).
**
**
**        lv_is_holiday = lo_holiday_rt->is_holiday( iv_date = cv_date ).
**
**
**        IF lv_is_holiday = abap_true.
**          " Sonuç: EVET, bu tarih bir resmi tatil!
**
**        ELSE.
**          " Sonuç: HAYIR, bu tarih resmi tatil değil.
**
**        ENDIF.
**
***      CATCH cx_fhc_runtime.
**CATCH cx_fhc_runtime INTO DATA(lx_error).         out->write( |Takvim Hatası: { lx_error->get_text( ) }| ).
**    ENDTRY.
**  cl_scal_api=>day_attributes_get(
**          EXPORTING
**            iv_factory_calendar = 'TR'
**            iv_holiday_calendar = 'TR'
**            iv_date_from        = cv_date
**            iv_date_to          = cv_date
**          IMPORTING
**            ev_returncode       = DATA(lv_returncode)
**            et_day_attributes   =  DATA(lt_day_attr)
**        ).
*
**
**
**    DATA: lv_date         TYPE d.
**
*    cv_date = '20260101'.
**TRY.
**    cl_scal_api=>day_attributes_get(
**      EXPORTING
**        iv_factory_calendar = 'TR'
**        iv_holiday_calendar = 'TR'
**        iv_date_from        = lv_date
**        iv_date_to          = lv_date
**      IMPORTING
**        ev_returncode       = DATA(lv_returncode)
**        et_day_attributes   = DATA(lt_day_attr)
**    ).
**
**  CATCH cx_scal INTO DATA(lx_scal1).
**    " Hata yönetimi buraya
***    MESSAGE lx_scal->get_text( ) TYPE 'E'.
**ENDTRY.
**
**    READ TABLE lt_day_attr INTO DATA(ls_day_attr)  WHERE date = lv_date.
**    IF sy-subrc IS INITIAL AND ls_day_attr-holiday =  'X'.
**      lv_date = lv_date - 1.
**      TRY.
**      cl_scal_api=>day_attributes_get(
**      EXPORTING
**        iv_factory_calendar = 'TR'
**        iv_holiday_calendar = 'TR'
**        iv_date_from        = lv_date
**        iv_date_to          = lv_date
**      IMPORTING
**        ev_returncode       = lv_returncode
**        et_day_attributes   = lt_day_attr
**    ).
**
**  CATCH cx_scal INTO DATA(lx_scal).
**    " Hata yönetimi buraya
***    MESSAGE lx_scal->get_text( ) TYPE 'E'.
**ENDTRY.
**
**      READ TABLE lt_day_attr INTO ls_day_attr WHERE date = lv_date.
**      IF sy-subrc IS INITIAL AND ls_day_attr-holiday =  'X'.
**        lv_date = lv_date - 1.
**        TRY.
**        cl_scal_api=>day_attributes_get(
**        EXPORTING
**          iv_factory_calendar = 'TR'
**          iv_holiday_calendar = 'TR'
**          iv_date_from        = lv_date
**          iv_date_to          = lv_date
**        IMPORTING
**          ev_returncode       = lv_returncode
**          et_day_attributes   = lt_day_attr
**      ).
**  CATCH cx_scal INTO DATA(lx_scal2).
**    " Hata yönetimi buraya
***    MESSAGE lx_scal->get_text( ) TYPE 'E'.
**ENDTRY.
**      ENDIF.
**    ENDIF.
**
**
**
**
**
***DATA: lv_date        TYPE d,
***      lv_weekday_num TYPE cl_scal_api=>scalv_weekday_number,
***      lv_weekday_name TYPE cl_scal_api=>scalv_weekday_name.
***
***lv_date = '20260328'.
***
***cl_scal_api=>date_compute_day(
***  EXPORTING
***    iv_date           = lv_date
***  IMPORTING
***    ev_weekday_number = lv_weekday_num
***    ev_weekday_name   = lv_weekday_name
***).
***
***" 1=Pazartesi ... 6=Cumartesi, 7=Pazar
***IF lv_weekday_num >= 6.
***  lv_date = lv_date - ( lv_weekday_num - 5 ).
***ENDIF.
***
**
***CATCH cx_scal.
**
***DATA lv_date TYPE d VALUE '20260328'.
***
***adjust_to_friday(
***  CHANGING
***    cv_date = lv_date
***).
*** lv_date = '20260321'.
***adjust_to_friday(
***  CHANGING
***    cv_date = lv_date
***).
***lv_date = '20260411'.
***adjust_to_friday(
***  CHANGING
***    cv_date = lv_date
***).
***
***lv_date = '20260511'.
***adjust_to_friday(
***  CHANGING
***    cv_date = lv_date
***).
***
***lv_date = '20260524'.
***adjust_to_friday(
***  CHANGING
***    cv_date = lv_date
***).
**
***seleCT * fROM ztest into taBLE @dATA(l4).
***
***delete fROM ztest.
***    DATA so_rate TYPE RANGE OF  kurst_curr.
***    APPEND VALUE #( sign = 'I'
***                option = 'CP'
***                low = 'M'
***                     high = 'M'
***              ) TO so_rate.
***         data:  ls_lg type ztest.
****              ls_lg-test = lines( so_rate[] ).
****    INSERT ztest FROM @ls_lg.
****    COMMIT WORK.
***    DATA: pr_kurtr TYPE datum.
***    pr_kurtr = '20260320' .
***     DATA lv_url TYPE string.
***    DATA: gv_status      TYPE i                   ,  " programın işleyiş durumu
***          gv_statxt(100) TYPE c.
****    lv_url = 'https://www.tcmb.gov.tr/kurlar/' && pr_kurtr(6) && '/' && pr_kurtr+6(2) && pr_kurtr+4(2) &&  pr_kurtr(4) && '.xml'.
****https://dap-yapi-subaccount-mxwqnzlc.it-cpi026-rt.cfapps.eu10-002.hana.ondemand.com/http/Get_Exchange_Rates?month=202603&datum=24032026
***    SELECT SINGLE Link
***    FROM zbct_is_links
***    WHERE business_key = 'EXCHANGERATESDEV'
***    INTO @lv_url.
***    lv_url = lv_url && '?month='
***                       && pr_kurtr(6)
***                       && '&datum='
***                       && pr_kurtr+6(2) && pr_kurtr+4(2) && pr_kurtr(4).
***    CONDENSE lv_url.
***
***    " HTTP Destination oluştur
***    DATA lo_destination TYPE REF TO if_http_destination.
***    TRY.
***        lo_destination = cl_http_destination_provider=>create_by_url( lv_url ).
***      CATCH cx_http_dest_provider_error INTO DATA(lx_dest).
***        gv_status = 2.
***        gv_statxt = lx_dest->get_text( ).
***
*** ls_lg-test =   gv_statxt.
*** CONDENSE ls_lg-test.
***   INSERT ztest FROM @ls_lg.
***    COMMIT WORK.
***        RETURN.
***    ENDTRY.
***
***    " HTTP Client oluştur
***    DATA lo_client TYPE REF TO if_web_http_client.
***    TRY.
***        lo_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
***      CATCH cx_web_http_client_error INTO DATA(lx_client).
***        gv_status = 2.
***        gv_statxt = lx_client->get_text( ).
*** ls_lg-test =   gv_statxt.
*** CONDENSE ls_lg-test.
***   INSERT ztest FROM @ls_lg.
***    COMMIT WORK.
***        RETURN.
***    ENDTRY.
***
***    " *** KRİTİK: Authorization header ekle ***
***    DATA lv_username TYPE string.
***    DATA lv_password TYPE string.
***
***    SELECT SINGLE *
***    FROM zbct_is_info
***    WHERE sys_id EQ 'DEV'
***    INTO @DATA(ls_info).
***    lv_username  = ls_info-username.
***    lv_password = ls_info-password.
****    lv_username = 'sb-cfd15ebf-4aaa-4aae-a4e4-6564231bf966!b646061|it-rt-dap-yapi-subaccount-mxwqnzlc!b410603'.
****
****    lv_password  =  '09e5f3da-aad9-4882-9c21-9b92ebc8ce49$VgAGbVc_rxh3YlRJLakOBNSbReNKVxJHi5_xHXj0ltk='.
***
***    DATA(lv_auth) = |Basic { cl_web_http_utility=>encode_base64( |{ lv_username }:{ lv_password }| ) }|.
***
***    " Header set et - i_name / i_value kullan
***    DATA(lo_request) = lo_client->get_http_request( ).
***    lo_request->set_header_field( i_name  = 'Authorization' i_value = lv_auth ).
****lo_request->set_header_field( i_name  = 'month'         i_value = pr_kurtr(6) ).
****lo_request->set_header_field( i_name  = 'datum'         i_value = pr_kurtr+6(2) && pr_kurtr+4(2) && pr_kurtr(4) ).
***    " İsteği gönder
***    DATA lo_response TYPE REF TO if_web_http_response.
***    TRY.
***        lo_response = lo_client->execute( i_method = if_web_http_client=>get ).
***      CATCH cx_web_http_client_error INTO DATA(lx_exec).
***        gv_status = 2.
***        gv_statxt = lx_exec->get_text( ).
*** ls_lg-test =   gv_statxt.
*** CONDENSE ls_lg-test.
***   INSERT ztest FROM @ls_lg.
***    COMMIT WORK.
***        RETURN.
***    ENDTRY.
***
***    " Response kontrol et
***    DATA(ls_status) = lo_response->get_status( ).
***    IF ls_status-code <> 200.
***      gv_status = 2.
***      gv_statxt = |HTTP Error: { ls_status-code } - { ls_status-reason }|.
*** ls_lg-test =   gv_statxt.
*** CONDENSE ls_lg-test.
***   INSERT ztest FROM @ls_lg.
***    COMMIT WORK.
***      RETURN.
***    ENDIF.
***
***    DATA(ld_text) = lo_response->get_text( ).
***    IF ld_text IS INITIAL.
***      gv_status = 2.
***      gv_statxt = 'Response boş geldi!'.
***
***      COMMIT WORK.
***      RETURN.
***    ENDIF.
***
***    " XML Parse
***    DATA(g_ixml)         = cl_ixml_core=>create( ).
***    DATA(streamfactory)  = g_ixml->create_stream_factory( ).
***    DATA(xstring)        = cl_abap_conv_codepage=>create_out( )->convert( source = ld_text ).
***    DATA(istream)        = streamfactory->create_istream_xstring( string = xstring ).
***    DATA(document)       = g_ixml->create_document( ).
***    DATA(parser)         = g_ixml->create_parser( stream_factory = streamfactory
***                                                  istream        = istream
***                                                  document       = document ).
***
***    DATA(parsed) = parser->parse( ).
***    IF parsed <> 0.
***      gv_status = 2.
***      gv_statxt = 'XML parse hatası!'.
***      RETURN.
***    ENDIF.
***
***    " Datatable oluştur
***    DATA lt_itab TYPE tt_itab.
***    DATA(lv_node) = CAST if_ixml_node( document ).
***    gv_first_time = 'X'.
***    create_datatable( EXPORTING x_node = lv_node CHANGING yt_item = lt_itab ).
***
***    DATA(lines1) = lines( lt_itab ).
***    DATA(lv_mes) = |Toplam kayıt: { lines1 }|.
***
*** ls_lg-test =   lines( lt_itab  ).
***   CONDENSE ls_lg-test.
***  ls_lg-test =  'itab' && ls_lg-test.
***  CONDENSE ls_lg-test.
***   INSERT ztest FROM @ls_lg.
***    COMMIT WORK.
***    " Kurları kaydet
***    LOOP AT lt_itab ASSIGNING FIELD-SYMBOL(<kur>).
***      "döviz alış
***      READ TABLE so_rate INTO DATA(ls_r) WITH KEY low = '*M*'.
***      IF sy-subrc IS INITIAL.
*** ls_lg-test =   'okudı'.
***        kur_insert( EXPORTING p0  = 'direct'
***                              p1  = 'M'
***                              p2  = <kur>-kod
***                              p3  = 'TRY'
***                              p4  = pr_kurtr
***                              p56 = <kur>-forexbuying
***                              p7  = <kur>-unit
***                              p8  = 1 ).
***      ELSE.
*** ls_lg-test =   'okumadı'.
***
***      ENDIF.
***       CONDENSE ls_lg-test.
***   INSERT ztest FROM @ls_lg.
***    COMMIT WORK.
***      "döviz satış
***      READ TABLE so_rate INTO ls_r WITH KEY low = '*S*'.
***      IF sy-subrc IS INITIAL.
***        kur_insert( EXPORTING p0  = 'direct'
***                                 p1  = 'S'
***                                 p2  = <kur>-kod
***                                 p3  = 'TRY'
***                                 p4  = pr_kurtr
***                                 p56 = <kur>-forexselling
***                                 p7  = <kur>-unit
***                                 p8  = 1 ).
***      ENDIF.
***      "efektif alis
***      READ TABLE so_rate INTO ls_r WITH KEY low = '*A*'.
***      IF sy-subrc IS INITIAL.
***        kur_insert( EXPORTING p0  = 'direct'
***                              p1  = 'A'
***                              p2  = <kur>-kod
***                              p3  = 'TRY'
***                              p4  = pr_kurtr
***                              p56 = <kur>-banknotebuying
***                              p7  = <kur>-unit
***                              p8  = 1 ).
***
***      ENDIF.
***
***      "efektif satış
***      READ TABLE so_rate INTO ls_r WITH KEY low = '*E*'.
***      IF sy-subrc IS INITIAL.
***        kur_insert( EXPORTING p0  = 'direct'
***                              p1  = 'E'
***                              p2  = <kur>-kod
***                              p3  = 'TRY'
***                              p4  = pr_kurtr
***                              p56 = <kur>-banknoteselling
***                              p7  = <kur>-unit
***                              p8  = 1 ).
***
***      ENDIF.
***    ENDLOOP.
***
***    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
***    COMMIT WORK.

  ENDMETHOD.


  METHOD kur_insert.
    DATA lt_exrates TYPE cl_exchange_rates=>ty_exchange_rates.
    DATA ls_exrates LIKE LINE OF lt_exrates.


    ls_exrates-rate_type  = p1.
    ls_exrates-from_curr  = p2.
    ls_exrates-to_currncy = p3.
    ls_exrates-valid_from = p4.

    CASE p0.
      WHEN 'direct'.
        ls_exrates-exch_rate   = p56.
        ls_exrates-from_factor = p7.
        ls_exrates-to_factor   = p8.
      WHEN 'indirect'.
        ls_exrates-exch_rate_v   = p56.
        ls_exrates-from_factor_v = p8.
        ls_exrates-to_factor_v   = p7.
    ENDCASE.
    APPEND ls_exrates TO lt_exrates.

    DATA(lt_ret) = cl_exchange_rates=>put( EXPORTING exchange_rates = lt_exrates
                                       is_update_allowed = 'X'
                                       do_commit = 'X'  ).

  ENDMETHOD.


  METHOD create_datatable.


    DATA: indent      TYPE i.
    DATA: ptext       TYPE REF TO if_ixml_text.
    DATA: string      TYPE string.
    DATA: temp_string(100).
    DATA: ntipi TYPE i.
    DATA: nadi TYPE string.
    DATA: nval TYPE string.
    DATA: node2 TYPE REF TO if_ixml_node.
    DATA: attributes TYPE REF TO if_ixml_named_node_map.

    DATA: x_node_1 TYPE REF TO if_ixml_node.

    ntipi = x_node->get_type( ).
    nadi  = x_node->get_name( ).
    nval  = x_node->get_value( ).

    CASE x_node->get_type( ).
      WHEN if_ixml_node=>co_node_element.
        string = x_node->get_name( ).
        gv_nodetext = string.
        IF gv_nodetext EQ 'Tarih_Date'.
          attributes = x_node->get_attributes( ).

          CALL METHOD attributes->get_named_item
            EXPORTING
              name = 'Tarih'
*             NAMESPACE = ''
            RECEIVING
              rval = node2.
          string = node2->get_value( ).
          gv_kurtarih = string.

        ELSEIF gv_nodetext EQ 'Currency'.
          IF gv_first_time NE 'X'.
            gs_itab-tarih = gv_kurtarih.
            APPEND gs_itab TO yt_item.
            CLEAR : gs_itab.
          ENDIF.
          gv_first_time = ' '.

          attributes = x_node->get_attributes( ).

          CALL METHOD attributes->get_named_item
            EXPORTING
              name = 'Kod'
            RECEIVING
              rval = node2.
          string = node2->get_value( ).
          gs_itab-kod = string.

          CALL METHOD attributes->get_named_item
            EXPORTING
              name = 'CurrencyCode'
            RECEIVING
              rval = node2.
          string = node2->get_value( ).
          gs_itab-currencycode = string.
        ENDIF.

      WHEN if_ixml_node=>co_node_text.
        ptext ?= x_node->query_interface( 140 ).
        IF ptext->ws_only( ) IS INITIAL.
          string = x_node->get_value( ).

          CASE gv_nodetext.
            WHEN 'Kod'.
              gs_itab-kod = string.

            WHEN 'CurrencyCode'.
              gs_itab-currencycode = string.

            WHEN 'Unit'.
              gs_itab-unit = string.

            WHEN 'Isim'.
              gs_itab-isim = string.

            WHEN 'CurrencyName'.
              gs_itab-currencyname = string.

            WHEN 'ForexBuying'.
              gs_itab-forexbuying = string.

            WHEN 'ForexSelling'.
              gs_itab-forexselling = string.

            WHEN 'BanknoteBuying'.
              gs_itab-banknotebuying = string.

            WHEN 'BanknoteSelling'.
              gs_itab-banknoteselling = string.

            WHEN 'CrossRateUSD'.
              gs_itab-crossrateusd = string.

            WHEN 'CrossRateOther'.
              gs_itab-crossrateother = string.

            WHEN 'CrossRateEuro'.
              gs_itab-crossrateeuro = string.

          ENDCASE.

        ENDIF.
    ENDCASE.

* Get the next child



    x_node_1 = x_node.
    x_node_1 = x_node_1->get_first_child( ).

* Recurse
    WHILE NOT x_node_1 IS INITIAL.
      create_datatable( EXPORTING x_node = x_node_1 CHANGING yt_item = yt_item ).
      "DATA(v_iterator) = x_node_1->create_iterator( ).
      x_node_1 = x_node_1->get_next( ).
    ENDWHILE.

  ENDMETHOD.
ENDCLASS.
