REPORT y_find_userexit.

TABLES : tstc,
         tadir,
         modsapt,
         modact,
         trdir,
         tfdir,
         enlfdir,
         sxs_attrt,
         tstct.
DATA jtab       LIKE tadir OCCURS 0 WITH HEADER LINE.
DATA field1     TYPE c LENGTH 30.
DATA v_devclass LIKE tadir-devclass.
PARAMETERS : p_tcode LIKE tstc-tcode,
             p_pgmna LIKE tstc-pgmna.
DATA wa_tadir TYPE tadir.

START-OF-SELECTION.
  IF p_tcode IS NOT INITIAL.
    SELECT SINGLE * FROM tstc WHERE tcode = p_tcode.
  ELSEIF p_pgmna IS NOT INITIAL.
    tstc-pgmna = p_pgmna.
  ENDIF.
  IF sy-subrc = 0.
    SELECT SINGLE * FROM tadir
      WHERE pgmid    = 'R3TR'
        AND object   = 'PROG'
        AND obj_name = tstc-pgmna.
    v_devclass = tadir-devclass.
    IF sy-subrc <> 0.
      SELECT SINGLE * FROM trdir
        WHERE name = tstc-pgmna.
      IF trdir-subc = 'F'.
        SELECT SINGLE * FROM tfdir
          WHERE pname = tstc-pgmna.
        SELECT SINGLE * FROM enlfdir
          WHERE funcname = tfdir-funcname.
        SELECT SINGLE * FROM tadir
          WHERE pgmid    = 'R3TR'
            AND object   = 'FUGR'
            AND obj_name = enlfdir-area.
        v_devclass = tadir-devclass.
      ENDIF.
    ENDIF.
    SELECT * FROM tadir
      INTO TABLE jtab
      WHERE pgmid     = 'R3TR'
        AND object   IN ( 'SMOD', 'SXSD' )
        AND devclass  = v_devclass.
    SELECT SINGLE * FROM tstct
      WHERE sprsl = sy-langu
        AND tcode = p_tcode.
    FORMAT COLOR COL_POSITIVE INTENSIFIED OFF.
    WRITE:/(19) 'Transaction Code - ',
    20(20) p_tcode,
    45(50) tstct-ttext.
    SKIP.
    IF jtab[] IS NOT INITIAL.
      WRITE /(105) sy-uline.
      FORMAT COLOR COL_HEADING INTENSIFIED ON.
      " Sorting the internal Table
      SORT jtab BY object.
      DATA wf_txt     TYPE c LENGTH 60.
      DATA wf_smod    TYPE i.
      DATA wf_badi    TYPE i.
      DATA wf_object2 TYPE c LENGTH 30.
      CLEAR : wf_smod,
              wf_badi,
              wf_object2.
      " Get the total SMOD.
      LOOP AT jtab INTO wa_tadir.
        AT FIRST.
          FORMAT COLOR COL_HEADING INTENSIFIED ON.
          WRITE:/1 sy-vline,
          2 'Enhancement/ Business Add-in',
          41 sy-vline,
          42 'Description',
          105 sy-vline.
          WRITE /(105) sy-uline.
        ENDAT.
        CLEAR wf_txt.
        AT NEW object.
          IF wa_tadir-object = 'SMOD'.
            wf_object2 = 'Enhancement'.
          ELSEIF wa_tadir-object = 'SXSD'.
            wf_object2 = ' Business Add-in'.
          ENDIF.
          FORMAT COLOR COL_GROUP INTENSIFIED ON.
          WRITE:/1 sy-vline,
          2 wf_object2,
          105 sy-vline.
        ENDAT.
        CASE wa_tadir-object.
          WHEN 'SMOD'.
            wf_smod = wf_smod + 1.
            SELECT SINGLE modtext INTO wf_txt
              FROM modsapt
              WHERE sprsl = sy-langu
                AND name  = wa_tadir-obj_name.
            FORMAT COLOR COL_NORMAL INTENSIFIED OFF.
          WHEN 'SXSD'.
            " For BADis
            wf_badi = wf_badi + 1.
            SELECT SINGLE text INTO wf_txt
              FROM sxs_attrt
              WHERE sprsl     = sy-langu
                AND exit_name = wa_tadir-obj_name.
            FORMAT COLOR COL_NORMAL INTENSIFIED ON.
        ENDCASE.
        WRITE:/1 sy-vline,
        2 wa_tadir-obj_name HOTSPOT ON,
        41 sy-vline,
        42 wf_txt,
        105 sy-vline.
        AT END OF object.
          WRITE /(105) sy-uline.
        ENDAT.
      ENDLOOP.
      WRITE /(105) sy-uline.
      SKIP.
      FORMAT COLOR COL_TOTAL INTENSIFIED ON.
      WRITE:/ 'No.of Exits:', wf_smod.
      WRITE:/ 'No.of BADis:', wf_badi.
    ELSE.
      FORMAT COLOR COL_NEGATIVE INTENSIFIED ON.
      WRITE /(105) 'No userexits or BADis exist'.
    ENDIF.
  ELSE.
    FORMAT COLOR COL_NEGATIVE INTENSIFIED ON.
    WRITE /(105) 'Transaction does not exist'.
  ENDIF.

AT LINE-SELECTION.
  DATA wf_object TYPE tadir-object.

  CLEAR wf_object.
  GET CURSOR FIELD field1.
  CHECK field1(8) = 'WA_TADIR'.
  READ TABLE jtab WITH KEY obj_name = sy-lisel+1(20).
  wf_object = jtab-object.
  CASE wf_object.
    WHEN 'SMOD'.
      SET PARAMETER ID 'MON' FIELD sy-lisel+1(10).
      CALL TRANSACTION 'SMOD' AND SKIP FIRST SCREEN.
    WHEN 'SXSD'.
      SET PARAMETER ID 'EXN' FIELD sy-lisel+1(20).
      CALL TRANSACTION 'SE18' AND SKIP FIRST SCREEN.
  ENDCASE.