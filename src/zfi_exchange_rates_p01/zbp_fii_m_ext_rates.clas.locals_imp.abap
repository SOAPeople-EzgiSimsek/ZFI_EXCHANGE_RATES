CLASS lcl_buffer DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_buffer,
             flag    TYPE c LENGTH 1,       " 'C' = Create, 'U' = Update, 'D' = Delete
             lv_data TYPE zfit_m_ext_rates,   " The structure that holds data data
           END OF ty_buffer.

    CLASS-DATA mt_buffer TYPE STANDARD TABLE OF ty_buffer WITH EMPTY KEY.  " Table to store buffer entries

    " Method to get an instance of the buffer class (Singleton pattern)
    CLASS-METHODS get_instance
      RETURNING VALUE(ro_instance) TYPE REF TO lcl_buffer.

    " Method to add records to the buffer (Create, Update, or Delete)
    METHODS add_to_buffer
      IMPORTING
        iv_flag TYPE c         " Flag to specify the type of operation (C/U/D)
        is_data TYPE zfit_m_ext_rates.  " data data to be added to the buffer
    METHODS job_data_create
      IMPORTING
        iv_run_uuid TYPE sysuuid_x16 OPTIONAL
        iv_rate     TYPE zfid_rate OPTIONAL
        iv_tdats    TYPE datum OPTIONAL
        iv_savedats TYPE datum OPTIONAL.
  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO lcl_buffer.  " Holds the single instance of the class

ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.

  METHOD get_instance.
    IF go_instance IS NOT BOUND.
      go_instance = NEW #( ).
    ENDIF.
    ro_instance = go_instance.
  ENDMETHOD.

  METHOD add_to_buffer.
    INSERT VALUE #( flag = iv_flag lv_data = is_data ) INTO TABLE mt_buffer.
  ENDMETHOD.
  METHOD job_data_create.


    DATA  lv_job_text TYPE cl_apj_rt_api=>ty_job_text VALUE 'Kur_Manuel_Job'.
    DATA lv_template_name TYPE cl_apj_rt_api=>ty_template_name.

    DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.
    DATA ls_scheduling_info TYPE cl_apj_rt_api=>ty_scheduling_info.
    DATA ls_end_info TYPE cl_apj_rt_api=>ty_end_info.

    DATA lt_job_parameters TYPE cl_apj_rt_api=>tt_job_parameter_value.
    DATA ls_job_parameters TYPE cl_apj_rt_api=>ty_job_parameter_value.
    DATA ls_value TYPE cl_apj_rt_api=>ty_value_range.

    DATA lv_jobname TYPE cl_apj_rt_api=>ty_jobname.
    DATA lv_jobcount TYPE cl_apj_rt_api=>ty_jobcount.

    DATA lv_status TYPE cl_apj_rt_api=>ty_job_status.
    DATA lv_statustext TYPE cl_apj_rt_api=>ty_job_status_text.

    DATA lv_txt TYPE string.
    DATA ls_ret TYPE bapiret2.

    " Choose the name of the existing job template.
    lv_template_name = 'ZFIJCE_EXCHANGE_RATES'.



    CLEAR:ls_start_info,ls_scheduling_info,ls_end_info ,lt_job_parameters,ls_job_parameters,ls_value.
    lv_job_text = 'Kur Manuel datajob' && iv_tdats && iv_savedats.
    " Start the job using a timestamp instead. This will start the job immediately but can have a delay depending on the current workload.
    GET TIME STAMP FIELD DATA(ls_ts1).
    " Add 1 hour
    DATA(ls_ts2) = cl_abap_tstmp=>add( tstmp = ls_ts1
                                       secs  = 5 ).

    ls_start_info-timestamp = ls_ts2.

    " Periodicity

    ls_scheduling_info-periodic_granularity = 'D'.
    ls_scheduling_info-periodic_value = 1.
    ls_scheduling_info-test_mode = abap_false.
    ls_scheduling_info-timezone = 'CET'.

    ls_end_info-type = 'NUM'.
    ls_end_info-max_iterations = '1'.


    ls_job_parameters-name = 'SO_WAERS'.
    ls_value-sign = 'I'.
    ls_value-option = 'EQ'.
    ls_value-low = 'TRY'.
    APPEND ls_value TO ls_job_parameters-t_value.

    APPEND ls_job_parameters TO lt_job_parameters.
    CLEAR ls_job_parameters.


    ls_job_parameters-name = 'SO_RATE'.
    ls_value-sign = 'I'.
    ls_value-option = 'EQ'.
    ls_value-low = 'M'.
    APPEND ls_value TO ls_job_parameters-t_value.
    APPEND ls_job_parameters TO lt_job_parameters.
    CLEAR ls_job_parameters.

    ls_job_parameters-name = 'SO_RATE'.
    ls_value-sign = 'I'.
    ls_value-option = 'EQ'.
    ls_value-low = 'S'.
    APPEND ls_value TO ls_job_parameters-t_value.
    APPEND ls_job_parameters TO lt_job_parameters.
    CLEAR ls_job_parameters.

    ls_job_parameters-name = 'SO_RATE'.
    ls_value-sign = 'I'.
    ls_value-option = 'EQ'.
    ls_value-low = 'A'.
    APPEND ls_value TO ls_job_parameters-t_value.
    APPEND ls_job_parameters TO lt_job_parameters.
    CLEAR ls_job_parameters.

    ls_job_parameters-name = 'SO_RATE'.
    ls_value-sign = 'I'.
    ls_value-option = 'EQ'.
    ls_value-low = 'E'.
    APPEND ls_value TO ls_job_parameters-t_value.
    APPEND ls_job_parameters TO lt_job_parameters.
    CLEAR ls_job_parameters.

    ls_job_parameters-name = 'PR_KURTR'.
    ls_value-sign = 'I'.
    ls_value-option = 'EQ'.
    ls_value-low = iv_tdats.
    APPEND ls_value TO ls_job_parameters-t_value.

    APPEND ls_job_parameters TO lt_job_parameters.
    CLEAR ls_job_parameters.

    ls_job_parameters-name = 'PR_INSTR'.
    ls_value-sign = 'I'.
    ls_value-option = 'EQ'.
    ls_value-low = iv_savedats.
    APPEND ls_value TO ls_job_parameters-t_value.

    APPEND ls_job_parameters TO lt_job_parameters.
    CLEAR ls_job_parameters.


    TRY.

        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = lv_template_name
            iv_job_text            = lv_job_text
            is_start_info          = ls_start_info
            is_scheduling_info     = ls_scheduling_info
            is_end_info            = ls_end_info
            it_job_parameter_value = lt_job_parameters
          IMPORTING
            ev_jobname             = lv_jobname
            ev_jobcount            = lv_jobcount
        ).


        cl_apj_rt_api=>get_job_status(
          EXPORTING
            iv_jobname         = lv_jobname
            iv_jobcount        = lv_jobcount
          IMPORTING
            ev_job_status      = lv_status
            ev_job_status_text = lv_statustext
        ).


      CATCH cx_apj_rt INTO DATA(exc).
        lv_txt = exc->get_longtext( ).
        ls_ret = exc->get_bapiret2( ).

    ENDTRY.


  ENDMETHOD.



ENDCLASS.

" Custom Exception Class
CLASS zcx_my_exception DEFINITION INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    INTERFACES if_t100_message.  " This interface is used for handling messages.
    METHODS constructor IMPORTING
                          textid LIKE if_t100_message=>t100key OPTIONAL.  " Constructor to initialize exception with a message
ENDCLASS.

CLASS zcx_my_exception IMPLEMENTATION.
  METHOD constructor.
    CALL METHOD super->constructor
      EXPORTING
        previous = previous.   " Calling the parent class constructor
    me->if_t100_message~t100key = textid.  " Set the error message key
  ENDMETHOD.
ENDCLASS.


CLASS lhc_rate DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR rate RESULT result.

    METHODS create FOR MODIFY
      IMPORTING entities FOR CREATE rate.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE rate.

    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE rate.

    METHODS read FOR READ
      IMPORTING keys FOR READ rate RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK rate.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR rate RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR rate RESULT result.

    METHODS setbuttonact FOR MODIFY
      IMPORTING keys FOR ACTION rate~setbuttonact RESULT result.

ENDCLASS.

CLASS lhc_rate IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD create.


    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity1>).

      IF <ls_entity1>-Instr <  <ls_entity1>-Kurtr.

        APPEND VALUE #(
          %cid = <ls_entity1>-%cid
        ) TO failed-rate.

        APPEND VALUE #(
          %cid = <ls_entity1>-%cid
          %msg = new_message(
                    id       = 'ZFI'
                    number   = '001'
                    severity = if_abap_behv_message=>severity-error
                  )
        ) TO reported-rate.

        CONTINUE.
      ENDIF.


    ENDLOOP.

    DATA(lo_buffer) = lcl_buffer=>get_instance( ).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).
      DATA ls_data TYPE zfit_m_ext_rates.


      " Map entity fields to data structure
*      ls_data-xguid       = to_upper( cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ) ).
      TRY.
          ls_data-xguid       = to_upper( cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ) ).
        CATCH cx_uuid_error.
          ASSERT 1 = 0.
      ENDTRY.
      ls_data-rate        = 'M,S,A,E'.
      ls_data-waers1    = 'TRY'.
      ls_data-waers2    = <ls_entity>-waers2.
      ls_data-kurtr      = <ls_entity>-kurtr.
      ls_data-instr      = <ls_entity>-instr.
      ls_data-rundt      = sy-datum.
      ls_data-runtm     = sy-uzeit.
      " Add to buffer as create
      lo_buffer->add_to_buffer( iv_flag = 'C' is_data = ls_data ).

      " Return mapped keys (required by RAP)
      INSERT VALUE #( %cid = <ls_entity>-%cid xguid = ls_data-xguid ) INTO TABLE mapped-rate.
    ENDLOOP.
  ENDMETHOD.

  METHOD update.
    DATA(lo_buffer) = lcl_buffer=>get_instance( ).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).
      " Fetch existing data from DB to buffer with flag U
      DATA ls_db TYPE zfit_m_ext_rates.
*      SELECT SINGLE * FROM zun_emp_tab WHERE emp_id = @<ls_entity>-EmpId INTO _db.
*      " Overwrite fields if updated in <ls_entity>
*      IF <ls_entity>-FirstName IS NOT INITIAL.
*        ls_db-first_name = <ls_entity>-FirstName.
*      ENDIF.
*      IF <ls_entity>-LastName IS NOT INITIAL.
*        ls_db-last_name = <ls_entity>-LastName.
*      ENDIF.
*      IF <ls_entity>-DateOfBirth IS NOT INITIAL.
*        ls_db-date_of_birth = <ls_entity>-DateOfBirth.
*      ENDIF.
*      IF <ls_entity>-email IS NOT INITIAL.
*        ls_db-email = <ls_entity>-email.
*      ENDIF.
*      IF <ls_entity>-HireDate IS NOT INITIAL.
*        ls_db-hire_date = <ls_entity>-HireDate.
*      ENDIF.
*      IF <ls_entity>-salary IS NOT INITIAL.
*        ls_db-salary = <ls_entity>-salary.
*      ENDIF.
*      IF <ls_entity>-curry IS NOT INITIAL.
*        ls_db-curry = <ls_entity>-curry.
*      ENDIF.

      " Add updated data to buffer with flag 'U'
      lo_buffer->add_to_buffer( iv_flag = 'U' is_data = ls_db ).

      " Return mapped keys
      INSERT VALUE #( %cid = <ls_entity>-%cid_ref xguid = ls_db-xguid ) INTO TABLE mapped-rate.
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.

    DATA(lo_buffer) = lcl_buffer=>get_instance( ).
    DATA ls_data TYPE zfit_m_ext_rates.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).

      CLEAR: ls_data.


      ls_data-xguid = <ls_key>-Xguid.

      " Add to buffer with flag 'D'
      lo_buffer->add_to_buffer( iv_flag = 'D' is_data = ls_data ).

      " Return mapped keys
      INSERT VALUE #( %cid = <ls_key>-%cid_ref xguid = <ls_key>-xguid ) INTO TABLE mapped-rate.
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    SELECT  *

   FROM zfit_m_ext_rates
   FOR ALL ENTRIES IN @keys
   WHERE  xguid    =  @keys-Xguid
     INTO TABLE @DATA(lt_mult).

    result = CORRESPONDING #( lt_mult ).
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.


    READ ENTITIES OF zfii_m_ext_rates IN LOCAL MODE
         ENTITY rate
         ALL FIELDS WITH
         CORRESPONDING #( keys )
         RESULT DATA(ratedata)
         FAILED failed.
    result = VALUE #(
      FOR activity IN ratedata
      (
        Xguid = activity-Xguid
        %tky    = activity-%tky   "KRİTİK
       %update = if_abap_behv=>fc-o-disabled



      )
    ).




  ENDMETHOD.

  METHOD setButtonAct.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZFII_M_EXT_RATES DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS adjust_numbers REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZFII_M_EXT_RATES IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD adjust_numbers.
  ENDMETHOD.

  METHOD save.

    DATA(lo_buffer) = lcl_buffer=>get_instance( ).
    LOOP AT lo_buffer->mt_buffer ASSIGNING FIELD-SYMBOL(<ls_buf>).
      CASE <ls_buf>-flag.
        WHEN 'C'.  " If the flag is 'C', perform Insert operation
          INSERT zfit_m_ext_rates FROM @<ls_buf>-lv_data.
* lo_buffer->
          lo_buffer->job_data_create(
            iv_run_uuid = <ls_buf>-lv_data-xguid
            iv_rate     = 'M'
            iv_tdats    =  <ls_buf>-lv_data-kurtr
            iv_savedats = <ls_buf>-lv_data-instr
          ).
        WHEN 'D'.  " If the flag is 'D', perform Delete operation
          DELETE FROM zfit_m_ext_rates WHERE xguid = @<ls_buf>-lv_data-xguid.
      ENDCASE.
    ENDLOOP.
    CLEAR lo_buffer->mt_buffer.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
