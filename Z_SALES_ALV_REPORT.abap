*&---------------------------------------------------------------------*
*& Report  : Z_SALES_ALV_REPORT
*& Title   : Custom ALV Report - Sales Order Analysis Dashboard
*& Author  : Sunnik Chatterjee | Roll No: 2328052 | Batch: FSD Java 2023-2027
*& Date    : April 2026
*& Desc    : End-to-end ABAP Development — Custom ALV Report using
*&           REUSE_ALV_GRID_DISPLAY with dynamic field catalog,
*&           selection screen, variant management, and drill-down.
*&---------------------------------------------------------------------*

REPORT z_sales_alv_report
  NO STANDARD PAGE HEADING
  LINE-SIZE 255
  MESSAGE-ID z_sales_msg.

*&---------------------------------------------------------------------*
*& TYPE DEFINITIONS
*&---------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_sales_order,
    vbeln   TYPE vbeln_va,          "Sales Order Number
    erdat   TYPE erdat,             "Creation Date
    kunnr   TYPE kunnr,             "Customer Number
    name1   TYPE name1_gp,          "Customer Name
    matnr   TYPE matnr,             "Material Number
    arktx   TYPE arktx,             "Short Description
    kwmeng  TYPE kwmeng,            "Order Quantity
    meins   TYPE meins,             "Unit of Measure
    netwr   TYPE netwr,             "Net Value
    waerk   TYPE waerk,             "Currency
    vkorg   TYPE vkorg,             "Sales Organization
    vtweg   TYPE vtweg,             "Distribution Channel
    spart   TYPE spart,             "Division
    auart   TYPE auart,             "Order Type
    gbstk   TYPE gbstk,             "Overall Status
    traffic_light TYPE char1,       "Traffic Light Indicator (Z custom)
  END OF ty_sales_order.

TYPES:
  ty_t_sales_order TYPE STANDARD TABLE OF ty_sales_order.

*&---------------------------------------------------------------------*
*& INTERNAL TABLES & WORK AREAS
*&---------------------------------------------------------------------*
DATA:
  gt_sales_order    TYPE ty_t_sales_order,
  gs_sales_order    TYPE ty_sales_order,
  gt_fieldcat       TYPE slis_t_fieldcat_alv,
  gs_fieldcat       TYPE slis_fieldcat_alv,
  gs_layout         TYPE slis_layout_alv,
  gs_variant        TYPE disvariant,
  gs_print          TYPE slis_print_alv,
  gt_sort           TYPE slis_t_sortinfo_alv,
  gs_sort           TYPE slis_sortinfo_alv,
  gt_events         TYPE slis_t_event,
  gs_event          TYPE slis_alv_event,
  gv_repid          TYPE sy-repid,
  gv_title          TYPE lvc_title.

*&---------------------------------------------------------------------*
*& SELECTION SCREEN
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS:
    so_vbeln FOR gs_sales_order-vbeln MATCHCODE OBJECT vbeln,
    so_kunnr FOR gs_sales_order-kunnr MATCHCODE OBJECT debi,
    so_matnr FOR gs_sales_order-matnr MATCHCODE OBJECT mat1,
    so_erdat FOR gs_sales_order-erdat DEFAULT sy-datum OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  SELECT-OPTIONS:
    so_vkorg FOR gs_sales_order-vkorg,
    so_auart FOR gs_sales_order-auart.
  PARAMETERS:
    p_maxrec TYPE i DEFAULT 1000,
    p_vari   TYPE disvariant-variant.
SELECTION-SCREEN END OF BLOCK b2.

*&---------------------------------------------------------------------*
*& INITIALIZATION
*&---------------------------------------------------------------------*
INITIALIZATION.
  gv_repid = sy-repid.
  TEXT-001 = 'Selection Criteria'.
  TEXT-002 = 'Additional Filters'.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_vari
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_vari.
  gs_variant-report = gv_repid.
  CALL FUNCTION 'REUSE_ALV_VARIANT_F4'
    EXPORTING
      is_variant = gs_variant
      i_save     = 'A'
    IMPORTING
      es_variant = gs_variant
    EXCEPTIONS
      OTHERS     = 1.
  IF sy-subrc = 0.
    p_vari = gs_variant-variant.
  ENDIF.

*&---------------------------------------------------------------------*
*& START-OF-SELECTION
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM fetch_data.
  PERFORM process_data.

*&---------------------------------------------------------------------*
*& END-OF-SELECTION
*&---------------------------------------------------------------------*
END-OF-SELECTION.
  PERFORM build_field_catalog.
  PERFORM build_layout.
  PERFORM build_sort.
  PERFORM register_events.
  PERFORM display_alv.

*&---------------------------------------------------------------------*
*& FORM fetch_data
*& Fetches Sales Order Header + Item + Customer data via JOIN
*&---------------------------------------------------------------------*
FORM fetch_data.
  SELECT
      vbak~vbeln
      vbak~erdat
      vbak~kunnr
      kna1~name1
      vbap~matnr
      vbap~arktx
      vbap~kwmeng
      vbap~meins
      vbap~netwr
      vbak~waerk
      vbak~vkorg
      vbak~vtweg
      vbak~spart
      vbak~auart
      vbak~gbstk
    INTO CORRESPONDING FIELDS OF TABLE gt_sales_order
    FROM vbak
    INNER JOIN vbap ON vbap~vbeln = vbak~vbeln
    INNER JOIN kna1 ON kna1~kunnr = vbak~kunnr
    WHERE vbak~vbeln IN so_vbeln
      AND vbak~kunnr IN so_kunnr
      AND vbap~matnr IN so_matnr
      AND vbak~erdat IN so_erdat
      AND vbak~vkorg IN so_vkorg
      AND vbak~auart IN so_auart
    UP TO p_maxrec ROWS.

  IF sy-subrc <> 0 OR gt_sales_order IS INITIAL.
    MESSAGE 'No records found for the given selection criteria.' TYPE 'I'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM process_data
*& Derives traffic light status based on order overall status
*&---------------------------------------------------------------------*
FORM process_data.
  LOOP AT gt_sales_order INTO gs_sales_order.
    CASE gs_sales_order-gbstk.
      WHEN 'C'.   "Completed
        gs_sales_order-traffic_light = '1'.   "Green
      WHEN 'B'.   "Partially processed
        gs_sales_order-traffic_light = '2'.   "Yellow
      WHEN ' ' OR 'A'.  "Not started / Open
        gs_sales_order-traffic_light = '3'.   "Red
      WHEN OTHERS.
        gs_sales_order-traffic_light = '2'.
    ENDCASE.
    MODIFY gt_sales_order FROM gs_sales_order.
    CLEAR gs_sales_order.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM build_field_catalog
*& Builds ALV field catalog dynamically
*&---------------------------------------------------------------------*
FORM build_field_catalog.
  DEFINE add_field.
    CLEAR gs_fieldcat.
    gs_fieldcat-fieldname    = &1.
    gs_fieldcat-seltext_m    = &2.
    gs_fieldcat-col_pos      = &3.
    gs_fieldcat-outputlen    = &4.
    gs_fieldcat-key          = &5.
    gs_fieldcat-hotspot      = &6.
    gs_fieldcat-emphasize    = &7.
    gs_fieldcat-no_zero      = 'X'.
    APPEND gs_fieldcat TO gt_fieldcat.
  END-OF-DEFINITION.

  "           Field            Label                     Pos Len Key Hot Emph
  add_field 'TRAFFIC_LIGHT'  'Status'                    1   3  ' ' ' ' ' '.
  add_field 'VBELN'          'Sales Order'               2   10 'X' 'X' 'C100'.
  add_field 'ERDAT'          'Created On'                3   10 ' ' ' ' ' '.
  add_field 'KUNNR'          'Customer No.'              4   10 ' ' ' ' ' '.
  add_field 'NAME1'          'Customer Name'             5   35 ' ' ' ' ' '.
  add_field 'MATNR'          'Material'                  6   18 ' ' ' ' ' '.
  add_field 'ARKTX'          'Description'               7   40 ' ' ' ' ' '.
  add_field 'KWMENG'         'Qty'                       8   13 ' ' ' ' ' '.
  add_field 'MEINS'          'UoM'                       9   3  ' ' ' ' ' '.
  add_field 'NETWR'          'Net Value'                 10  15 ' ' ' ' ' '.
  add_field 'WAERK'          'Currency'                  11  5  ' ' ' ' ' '.
  add_field 'VKORG'          'Sales Org'                 12  4  ' ' ' ' ' '.
  add_field 'VTWEG'          'Dist. Channel'             13  2  ' ' ' ' ' '.
  add_field 'SPART'          'Division'                  14  2  ' ' ' ' ' '.
  add_field 'AUART'          'Order Type'                15  4  ' ' ' ' ' '.
  add_field 'GBSTK'          'Overall Status'            16  1  ' ' ' ' ' '.

  "Set traffic light field
  READ TABLE gt_fieldcat INTO gs_fieldcat
    WITH KEY fieldname = 'TRAFFIC_LIGHT'.
  IF sy-subrc = 0.
    gs_fieldcat-icon = 'X'.
    MODIFY gt_fieldcat FROM gs_fieldcat INDEX sy-tabix.
  ENDIF.

  "Set numeric formatting for Net Value
  READ TABLE gt_fieldcat INTO gs_fieldcat
    WITH KEY fieldname = 'NETWR'.
  IF sy-subrc = 0.
    gs_fieldcat-do_sum    = 'X'.
    gs_fieldcat-datatype  = 'CURR'.
    MODIFY gt_fieldcat FROM gs_fieldcat INDEX sy-tabix.
  ENDIF.

  "Set numeric formatting for Quantity
  READ TABLE gt_fieldcat INTO gs_fieldcat
    WITH KEY fieldname = 'KWMENG'.
  IF sy-subrc = 0.
    gs_fieldcat-do_sum    = 'X'.
    MODIFY gt_fieldcat FROM gs_fieldcat INDEX sy-tabix.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM build_layout
*& Sets ALV layout properties
*&---------------------------------------------------------------------*
FORM build_layout.
  gs_layout-colwidth_optimize  = 'X'.
  gs_layout-zebra              = 'X'.
  gs_layout-info_fieldname     = 'TRAFFIC_LIGHT'.
  gs_layout-detail_popup       = 'X'.
  gs_layout-totals_text        = 'Grand Total'.
  gs_layout-subtotals_text     = 'Sub Total'.
  gs_layout-no_input           = 'X'.
  gs_layout-box_fieldname      = space.
  gv_title = 'Sales Order Analysis Dashboard | Z_SALES_ALV_REPORT'.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM build_sort
*& Adds default sort on creation date descending
*&---------------------------------------------------------------------*
FORM build_sort.
  CLEAR gs_sort.
  gs_sort-fieldname  = 'ERDAT'.
  gs_sort-up         = ' '.
  gs_sort-down       = 'X'.
  gs_sort-spos       = 1.
  APPEND gs_sort TO gt_sort.

  CLEAR gs_sort.
  gs_sort-fieldname  = 'KUNNR'.
  gs_sort-up         = 'X'.
  gs_sort-spos       = 2.
  gs_sort-subtot     = 'X'.
  APPEND gs_sort TO gt_sort.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM register_events
*& Registers ALV events — TOP-OF-PAGE, USER-COMMAND, DOUBLE-CLICK
*&---------------------------------------------------------------------*
FORM register_events.
  CALL FUNCTION 'REUSE_ALV_EVENTS_GET'
    EXPORTING
      i_list_type = 0
    IMPORTING
      et_events   = gt_events.

  READ TABLE gt_events INTO gs_event WITH KEY name = slis_ev_top_of_page.
  IF sy-subrc = 0.
    gs_event-form = 'TOP_OF_PAGE'.
    MODIFY gt_events FROM gs_event INDEX sy-tabix.
  ENDIF.

  READ TABLE gt_events INTO gs_event WITH KEY name = slis_ev_user_command.
  IF sy-subrc = 0.
    gs_event-form = 'USER_COMMAND'.
    MODIFY gt_events FROM gs_event INDEX sy-tabix.
  ENDIF.

  READ TABLE gt_events INTO gs_event WITH KEY name = slis_ev_caller_exit_at_start.
  IF sy-subrc = 0.
    gs_event-form = 'CALLER_EXIT'.
    MODIFY gt_events FROM gs_event INDEX sy-tabix.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM display_alv
*& Calls REUSE_ALV_GRID_DISPLAY to render ALV output
*&---------------------------------------------------------------------*
FORM display_alv.
  gs_variant-report   = gv_repid.
  gs_variant-variant  = p_vari.

  gs_print-print      = ' '.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program      = gv_repid
      i_callback_top_of_page  = 'TOP_OF_PAGE'
      i_callback_user_command = 'USER_COMMAND'
      is_layout               = gs_layout
      it_fieldcat             = gt_fieldcat
      it_sort                 = gt_sort
      it_events               = gt_events
      i_save                  = 'A'
      is_variant              = gs_variant
      i_grid_title            = gv_title
    TABLES
      t_outtab                = gt_sales_order
    EXCEPTIONS
      program_error           = 1
      OTHERS                  = 2.

  IF sy-subrc <> 0.
    MESSAGE 'ALV display error. Please contact system administrator.' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM top_of_page
*& Renders company logo header and report info at top of ALV
*&---------------------------------------------------------------------*
FORM top_of_page.
  DATA: lt_header TYPE slis_t_listheader,
        ls_header TYPE slis_listheader.

  "Header line 1 — Report title
  ls_header-typ  = 'H'.
  ls_header-info = 'Sales Order Analysis Dashboard'.
  APPEND ls_header TO lt_header.
  CLEAR ls_header.

  "Header line 2 — Spacer / Sub-title
  ls_header-typ  = 'S'.
  ls_header-key  = 'Report:'.
  ls_header-info = 'Z_SALES_ALV_REPORT | Custom ALV Grid Report'.
  APPEND ls_header TO lt_header.
  CLEAR ls_header.

  "Header line 3 — Run date & user
  ls_header-typ  = 'A'.
  ls_header-key  = 'Run Date:'.
  ls_header-info = sy-datum.
  APPEND ls_header TO lt_header.
  CLEAR ls_header.

  ls_header-typ  = 'A'.
  ls_header-key  = 'Run By:'.
  ls_header-info = sy-uname.
  APPEND ls_header TO lt_header.
  CLEAR ls_header.

  ls_header-typ  = 'A'.
  ls_header-key  = 'Records:'.
  ls_header-info = lines( gt_sales_order ).
  APPEND ls_header TO lt_header.
  CLEAR ls_header.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = lt_header.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM user_command
*& Handles toolbar button actions and hotspot clicks
*&---------------------------------------------------------------------*
FORM user_command USING ucomm     TYPE sy-ucomm
                        selfield  TYPE slis_selfield.

  DATA: lv_vbeln TYPE vbeln_va.

  CASE ucomm.
    WHEN '&IC1'.    "Hotspot click / double-click on Sales Order field
      READ TABLE gt_sales_order INTO gs_sales_order INDEX selfield-tabindex.
      IF sy-subrc = 0.
        lv_vbeln = gs_sales_order-vbeln.
        "Navigate to VA03 — Display Sales Order
        SET PARAMETER ID 'AUN' FIELD lv_vbeln.
        CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
      ENDIF.

    WHEN 'ZREFRESH'.    "Custom refresh button (add via PF-Status)
      CLEAR gt_sales_order.
      PERFORM fetch_data.
      PERFORM process_data.
      selfield-refresh = 'X'.

    WHEN OTHERS.
      "Standard ALV toolbar commands handled by framework
  ENDCASE.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM caller_exit
*& Optional: modify grid properties before display (exclude toolbar btns)
*&---------------------------------------------------------------------*
FORM caller_exit USING rs_data TYPE slis_data_caller_exit.
  "Example: exclude standard 'Local File' export button
  DATA: ls_excl TYPE ui_func.
  ls_excl = 'EXPORT'.
  "Further exclusions can be added here
ENDFORM.

*&---------------------------------------------------------------------*
*& TEXT ELEMENTS (define in SE38 -> Goto -> Text Elements -> Text Symbols)
*& TEXT-001 = Selection Criteria
*& TEXT-002 = Additional Filters
*&---------------------------------------------------------------------*
