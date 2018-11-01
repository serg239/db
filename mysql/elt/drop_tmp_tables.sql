SELECT CONCAT('DROP TABLE IF EXISTS ', table_schema, '.', table_name, ';') AS drop_queries
  FROM information_schema.tables
 WHERE table_schema = 'elt'
   AND table_name LIKE 'tmp_%';

SELECT CONCAT('DROP TABLE IF EXISTS ', table_schema, '.', table_name, ';') AS drop_queries
  FROM information_schema.tables
 WHERE table_schema = 'db_report'
   AND table_name LIKE 'tmp_%';
