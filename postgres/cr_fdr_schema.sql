-- VERSION 2.1.08.12.22

-- DROP SCHEMA fdr CASCADE;
-- CREATE SCHEMA fdr AUTHORIZATION metrics;

-- Default tablespaces
\set dc_data  pg_default
\set dc_index pg_default

-- DC Tablespaces
-- \set dc_data  dc_data
-- \set dc_index dc_index

SET search_path TO fdr;

-- DROP TABLE IF EXISTS fdr.states;
-- DROP TABLE IF EXISTS fdr.stats;

-- =========================
-- Table "states"
-- =========================
-- States:
--   New        - 'n' 
--   Copy       - 'c'
--   Ready      - 'r'
--   Rollup     - 'l'
--   RollupDone - 'd'
--   Empty      - 'e'
--   Failure    - 'f'

CREATE TABLE fdr.states
(
  table_name    CHAR(16)  NOT NULL,
  state         CHAR(1)   NOT NULL DEFAULT 'n',
  copy_time     INT2      NOT NULL DEFAULT 0,
  rollup_time   INT2      NOT NULL DEFAULT 0,
  roll_rows     BIGINT    NOT NULL DEFAULT 0
)
TABLESPACE :dc_data;

-- Index
CREATE UNIQUE INDEX states$table_name_uidx
ON fdr.states (table_name)
TABLESPACE :dc_index;

ALTER TABLE fdr.states
ADD CONSTRAINT states$state_check
CHECK (state = 'n' 
OR state = 'c' 
OR state = 'r' 
OR state = 'l'
OR state = 'd'
OR state = 'e'
OR state = 'f');

-- Privileges on the Table
REVOKE ALL PRIVILEGES ON TABLE fdr.states FROM PUBLIC;
ALTER TABLE fdr.states OWNER TO metrics;
GRANT ALL ON TABLE fdr.states TO postgres;

-- =========================
-- Table "stats"
-- =========================

CREATE TABLE fdr.stats 
(
  table_name      CHAR(16) NOT NULL,
  period_id       INT4 NOT NULL,
  start_time      TIMESTAMPTZ,
  to_table_name   CHAR(16),
  copy_time       INT2 NOT NULL DEFAULT 0,
  rollup_time     INT2 NOT NULL DEFAULT 0,
  roll_rows       INT4 NOT NULL DEFAULT 0,
  nd_period_id    INT4 NOT NULL DEFAULT 0,
  nd_device_id    INT4 NOT NULL DEFAULT 0,
  nd_ud_class_id  INT4 NOT NULL DEFAULT 0,
  nd_src_ip       INT4 NOT NULL DEFAULT 0,
  nd_dst_ip       INT4 NOT NULL DEFAULT 0,
  nd_vlan_id      INT4 NOT NULL DEFAULT 0,
  nd_tos          INT4 NOT NULL DEFAULT 0,
  nd_service_id   INT4 NOT NULL DEFAULT 0,
  nd_ftype_num    INT4 NOT NULL DEFAULT 0
)
TABLESPACE :dc_data;

-- Index
CREATE UNIQUE INDEX stats$table_name_uidx
ON fdr.stats (table_name)
TABLESPACE :dc_index;

-- Privileges on the Table
REVOKE ALL PRIVILEGES ON TABLE fdr.stats FROM PUBLIC;
ALTER TABLE fdr.stats OWNER TO metrics;
GRANT ALL ON TABLE fdr.stats TO postgres;

-- Privileges on Schema
REVOKE ALL ON SCHEMA fdr FROM PUBLIC;
GRANT USAGE ON SCHEMA fdr TO rptuser;
GRANT USAGE ON SCHEMA fdr TO postgres;

\unset dc_data
\unset dc_index

-- Schema's Version
UPDATE metrics.components 
   SET version = '2.1.08.12.22' 
 WHERE name = 'fdr_schema';
