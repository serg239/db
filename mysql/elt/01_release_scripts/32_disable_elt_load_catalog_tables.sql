/*
  Scipt
    disable_elt_load_catalog_tables.sql
  Description:
    Remove load_catalog tables from ELT process.
*/

UPDATE elt.control_downloads
   SET src_table_load_status = 0,
       src_table_valid_status = 0
 WHERE src_schema_name = 'load_catalog'   
   AND src_table_name IN ('core_item', 'oi_item', 'oi_ksn', 'oi_pkg', 'oi_vend_pkg')
;

COMMIT;
