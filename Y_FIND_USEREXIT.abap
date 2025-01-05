*&---------------------------------------------------------------------*
*& Report y_find_userexit
*&---------------------------------------------------------------------*
*& Report to find userexits and BADis for a given transaction code
*&---------------------------------------------------------------------*
REPORT y_find_userexit.
*&---------------------------------------------------------------------*
*&  DATA
*&---------------------------------------------------------------------*
" Global internal table
DATA gt_tadir  LIKE tadir OCCURS 0 WITH HEADER LINE.
" Global variables
DATA gv_field1 TYPE c LENGTH 30.
" Global work area
DATA gs_tadir  TYPE tadir.
DATA gs_tstc   TYPE tstc.
*&---------------------------------------------------------------------*
*&  SCREEN
*&---------------------------------------------------------------------*
PARAMETERS p_tcode LIKE gs_tstc-tcode.
PARAMETERS p_pgmna LIKE gs_tstc-pgmna.
*&---------------------------------------------------------------------*
*&  START-OF-SELECTION
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  " Check data
  PERFORM frm_check_data.
  " Select data
  PERFORM frm_select_data.
  " Display results
  PERFORM frm_display_results.
*&---------------------------------------------------------------------*
*&  AT LINE-SELECTION
*&---------------------------------------------------------------------*
AT LINE-SELECTION.
  " Handle line selection
  PERFORM frm_handle_line_selection.
*&---------------------------------------------------------------------*
*&      Form frm_check_data
*&---------------------------------------------------------------------*
FORM frm_check_data.
  " Check transaction code
  IF p_tcode IS NOT INITIAL.
    SELECT SINGLE * FROM tstc WHERE tcode = @p_tcode INTO @gs_tstc.
    IF sy-subrc <> 0.
      FORMAT COLOR COL_NEGATIVE INTENSIFIED ON.
      WRITE /(105) 'Transaction does not exist'.
    ENDIF.
  ENDIF.
  " Check program name
  IF p_pgmna IS NOT INITIAL.
    gs_tstc-pgmna = p_pgmna.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form frm_select_data
*&---------------------------------------------------------------------*
FORM frm_select_data.
  DATA lv_devclass TYPE tadir-devclass.

  " Read system table information
  SELECT SINGLE * FROM trdir
    WHERE name = @gs_tstc-pgmna
    INTO @DATA(ls_trdir).

  CASE ls_trdir-subc.
    WHEN 'F'. " Function module
      " Read function module information
      SELECT SINGLE * FROM tfdir
        WHERE pname = @gs_tstc-pgmna
        INTO @DATA(ls_tfdir).
      " Read additional function module information
      SELECT SINGLE * FROM enlfdir
        WHERE funcname = @ls_tfdir-funcname
        INTO @DATA(ls_enlfdir).
      " Read repository object
      SELECT SINGLE * FROM tadir
        WHERE pgmid    = 'R3TR'
          AND object   = 'FUGR'
          AND obj_name = @ls_enlfdir-area
        INTO @DATA(ls_tadir).
      IF sy-subrc = 0.
        lv_devclass = ls_tadir-devclass.
      ENDIF.
    WHEN OTHERS.
      " Read repository object
      SELECT SINGLE * FROM tadir
        WHERE pgmid    = 'R3TR'
          AND object   = 'PROG'
          AND obj_name = @gs_tstc-pgmna
        INTO @ls_tadir.
      IF sy-subrc = 0.
        lv_devclass = ls_tadir-devclass.
      ENDIF.
  ENDCASE.
  " Read system table information
  SELECT * FROM tadir
    INTO TABLE gt_tadir
    WHERE pgmid     = 'R3TR'
      AND object   IN ( 'SMOD', 'SXSD' )
      AND devclass  = lv_devclass.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form frm_display_results
*&---------------------------------------------------------------------*
FORM frm_display_results.
  DATA lv_txt    TYPE c LENGTH 60.
  DATA lv_smod   TYPE i.
  DATA lv_badi   TYPE i.
  DATA lv_object TYPE c LENGTH 30.

  " Read transaction code description
  SELECT SINGLE * FROM tstct
    WHERE sprsl = @sy-langu
      AND tcode = @p_tcode
    INTO @DATA(ls_tstct).
  " Output transaction code and description
  FORMAT COLOR COL_POSITIVE INTENSIFIED OFF.
  WRITE:/(19) 'Transaction Code - ',
  20(20) p_tcode,
  45(50) ls_tstct-ttext.
  SKIP.
  " Check if internal table is empty
  IF gt_tadir[] IS NOT INITIAL.
    WRITE /(105) sy-uline.
    FORMAT COLOR COL_HEADING INTENSIFIED ON.
    " Sort internal table
    SORT gt_tadir BY object.
    " Clear local variables
    CLEAR : lv_smod,
            lv_badi,
            lv_object.
    " Get total SMOD
    LOOP AT gt_tadir INTO gs_tadir.
      AT FIRST.
        FORMAT COLOR COL_HEADING INTENSIFIED ON.
        WRITE:/1 sy-vline,
        2 'Enhancement/ Business Add-in',
        41 sy-vline,
        42 'Description',
        105 sy-vline.
        WRITE /(105) sy-uline.
      ENDAT.
      " Clear text variable
      CLEAR lv_txt.
      " Handle new object
      AT NEW object.
        IF gs_tadir-object = 'SMOD'.
          lv_object = 'Enhancement'.
        ELSEIF gs_tadir-object = 'SXSD'.
          lv_object = ' Business Add-in'.
        ENDIF.
        FORMAT COLOR COL_GROUP INTENSIFIED ON.
        WRITE:/1 sy-vline,
        2 lv_object,
        105 sy-vline.
      ENDAT.
      " Handle according to object type
      CASE gs_tadir-object.
        WHEN 'SMOD'.
          lv_smod = lv_smod + 1.
          SELECT SINGLE modtext INTO lv_txt
            FROM modsapt
            WHERE sprsl = sy-langu
              AND name  = gs_tadir-obj_name.
          FORMAT COLOR COL_NORMAL INTENSIFIED OFF.
        WHEN 'SXSD'.
          " Handle BADIs
          lv_badi = lv_badi + 1.
          SELECT SINGLE text INTO lv_txt
            FROM sxs_attrt
            WHERE sprsl     = sy-langu
              AND exit_name = gs_tadir-obj_name.
          FORMAT COLOR COL_NORMAL INTENSIFIED ON.
      ENDCASE.
      " Output object name and description
      WRITE:/1 sy-vline,
      2 gs_tadir-obj_name HOTSPOT ON,
      41 sy-vline,
      42 lv_txt,
      105 sy-vline.
      " Handle end of object
      AT END OF object.
        WRITE /(105) sy-uline.
      ENDAT.
    ENDLOOP.
    " Output end line
    WRITE /(105) sy-uline.
    SKIP.
    FORMAT COLOR COL_TOTAL INTENSIFIED ON.
    WRITE:/ 'No.of Exits:', lv_smod.
    WRITE:/ 'No.of BADis:', lv_badi.
  ELSE.
    FORMAT COLOR COL_NEGATIVE INTENSIFIED ON.
    WRITE /(105) 'No userexits or BADis exist'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form frm_handle_line_selection
*&---------------------------------------------------------------------*
FORM frm_handle_line_selection.
  DATA lv_object TYPE tadir-object.

  " Clear variables
  GET CURSOR FIELD gv_field1.
  IF gv_field1(8) <> 'GS_TADIR'.
    RETURN.
  ENDIF.

  READ TABLE gt_tadir WITH KEY obj_name = sy-lisel+1(20).
  IF sy-subrc = 0.
    lv_object = gt_tadir-object.
  ENDIF.
  " Call transaction according to object type
  CASE lv_object.
    WHEN 'SMOD'.
      SET PARAMETER ID 'MON' FIELD sy-lisel+1(10).
      CALL TRANSACTION 'SMOD' AND SKIP FIRST SCREEN.
    WHEN 'SXSD'.
      SET PARAMETER ID 'EXN' FIELD sy-lisel+1(20).
      CALL TRANSACTION 'SE18' AND SKIP FIRST SCREEN.
  ENDCASE.
ENDFORM.