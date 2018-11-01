/*
  Scipt
    34_schema_changes.sql
  Description:
    Drop old and create new tables in ELT schema to compare DDLs.
*/
SET SQL_MODE = '';

-- ====================================
-- TABLE ddl_table_changes
-- ====================================
DROP TABLE IF EXISTS elt.ddl_table_changes;

CREATE TABLE elt.ddl_table_changes
(
  ddl_table_change_id INT(11)     NOT NULL AUTO_INCREMENT COMMENT 'PK: DDL Table Change ID',
  action              CHAR(16)    NOT NULL                COMMENT 'Command [CREATE|DROP] TABLE',
  src_schema_name     VARCHAR(64) NOT NULL                COMMENT 'SRC Schema Name',
  src_table_name      VARCHAR(64) NOT NULL                COMMENT 'SRC Table Name',
  applied_status      TINYINT     NOT NULL DEFAULT 0      COMMENT '0 - not applied; 1 - applied',
  modified_by         VARCHAR(64) DEFAULT NULL,
  modified_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by          VARCHAR(64) NOT NULL,
  created_at          TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (ddl_table_change_id)
) 
ENGINE = InnoDB 
DEFAULT CHARSET = utf8 
COLLATE = utf8_bin
;

-- ====================================
-- TABLE ddl_column_changes
-- ====================================
DROP TABLE IF EXISTS elt.ddl_column_changes;

CREATE TABLE elt.ddl_column_changes 
(
  ddl_column_change_id    INT(11)      NOT NULL AUTO_INCREMENT COMMENT 'PK: DDL Column Change ID',
  action                  CHAR(16)     NOT NULL                COMMENT 'Command [ADD|DROP|MODIFY|ALTER]',
  src_schema_name         VARCHAR(64)  NOT NULL                COMMENT 'SRC Schema Name',
  src_table_name          VARCHAR(64)  NOT NULL                COMMENT 'SRC Table Name',
  src_column_name         VARCHAR(64)  NOT NULL                COMMENT 'SRC Column Name',
  column_attributes       VARCHAR(256) NOT NULL                COMMENT 'SRC Column Attributes',
  applied_status          TINYINT(4)   NOT NULL DEFAULT 0      COMMENT '0 - not applied; 1 - applied',
  modified_by             VARCHAR(64)  DEFAULT NULL,
  modified_at             TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by              VARCHAR(64)  NOT NULL,
  created_at              TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (ddl_column_change_id)
) 
ENGINE=InnoDB 
DEFAULT CHARSET=utf8 
COLLATE=utf8_bin;

-- ====================================
-- TABLE ddl_column_changes
-- ====================================
DROP TABLE IF EXISTS elt.ddl_index_changes;

CREATE TABLE elt.ddl_index_changes 
(
  ddl_index_change_id     INT(11)      NOT NULL AUTO_INCREMENT COMMENT 'PK: DDL Index Change ID',
  action                  CHAR(16)     NOT NULL                COMMENT 'Command [ADD|DROP|MODIFY|ALTER]',
  src_schema_name         VARCHAR(64)  NOT NULL                COMMENT 'SRC Schema Name',
  src_table_name          VARCHAR(64)  NOT NULL                COMMENT 'SRC Table Name',
  index_name              VARCHAR(64)  NOT NULL                COMMENT 'SRC Index Name',
  index_type              VARCHAR(32)  NULL                    COMMENT 'Unique/Non Unique', 
  index_columns           VARCHAR(256) NOT NULL                COMMENT 'Columns in the Index',
  applied_status          TINYINT(4)   NOT NULL DEFAULT 0      COMMENT '0 - not applied; 1 - applied',
  modified_by             VARCHAR(64)  DEFAULT NULL,
  modified_at             TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by              VARCHAR(64)  NOT NULL,
  created_at              TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (ddl_index_change_id)
) 
ENGINE=InnoDB 
DEFAULT CHARSET=utf8 
COLLATE=utf8_bin;
