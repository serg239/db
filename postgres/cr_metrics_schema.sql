-- VERSION 2.1.08.11.20

-- DROP SCHEMA metrics CASCADE;
-- CREATE SCHEMA metrics AUTHORIZATION metrics;

-- Default tablespaces
\set dc_data  pg_default
\set dc_index pg_default

-- DC Tablespaces
-- DROP TABLESPACE dc_data;
-- DROP TABLESPACE dc_index;
-- CREATE TABLESPACE dc_data OWNER metrics LOCATION E'C:\\Program Files\\PostgreSQL\\8.2\\data\\dc_data';
-- CREATE TABLESPACE dc_index OWNER metrics LOCATION E'C:\\Program Files\\PostgreSQL\\8.2\\data\\dc_index';
-- \set dc_data  dc_data
-- \set dc_index dc_index

SET search_path TO metrics;

-- ========================================================
--             Drop Schema Objects (the order)
-- ========================================================

-- Tables
--DROP TABLE IF EXISTS dev_classes;
--DROP TABLE IF EXISTS dev_links;
--DROP TABLE IF EXISTS dev_partitions;
--DROP TABLE IF EXISTS dev_interfaces;
--DROP TABLE IF EXISTS group_devices;
--DROP TABLE IF EXISTS application_classes;
--DROP TABLE IF EXISTS application_definitions;
--DROP TABLE IF EXISTS site_classes;
--DROP TABLE IF EXISTS site_definitions;
--DROP TABLE IF EXISTS classes;      -- CASCADE;
--DROP TABLE IF EXISTS links;        -- CASCADE;
--DROP TABLE IF EXISTS partitions;   -- CASCADE;
--DROP TABLE IF EXISTS applications;
--DROP TABLE IF EXISTS sites;
--DROP TABLE IF EXISTS groups;
--DROP TABLE IF EXISTS actions;
--DROP TABLE IF EXISTS interfaces;   -- CASCADE; 
--DROP TABLE IF EXISTS services;
--DROP TABLE IF EXISTS protocols;
--DROP TABLE IF EXISTS tcp_flags;
--DROP TABLE IF EXISTS rep_fields;
--DROP TABLE IF EXISTS reports;
--DROP TABLE IF EXISTS devices;      -- CASCADE;
--DROP TABLE IF EXISTS periods;      -- CASCADE;
--DROP TABLE IF EXISTS config_schemas;
--DROP TABLE IF EXISTS collection_vars;
--DROP TABLE IF EXISTS collection_types;
--DROP TABLE IF EXISTS components;
--DROP TABLE IF EXISTS codecs;
--DROP TABLE IF EXISTS timezone_names;
--DROP TABLE IF EXISTS ftypes;
--DROP TABLE IF EXISTS logs;
--DROP TABLE IF EXISTS perfs;

-- Sequences
--DROP SEQUENCE IF EXISTS class_id_seq;
--DROP SEQUENCE IF EXISTS partition_id_seq;
--DROP SEQUENCE IF EXISTS link_id_seq;
--DROP SEQUENCE IF EXISTS interface_id_seq;
--DROP SEQUENCE IF EXISTS service_id_seq;
--DROP SEQUENCE IF EXISTS protocol_id_seq;
--DROP SEQUENCE IF EXISTS device_id_seq;
--DROP SEQUENCE IF EXISTS period_id_seq;
--DROP SEQUENCE IF EXISTS config_schema_id_seq;
--DROP SEQUENCE IF EXISTS log_id_seq;
--DROP SEQUENCE IF EXISTS perf_id_seq;

-- =========================
-- Table "ftypes"
-- =========================
CREATE TABLE metrics.ftypes
(
  ftype_id         SMALLINT,
  ftype_num        SMALLINT,
  name             CHAR(8) NOT NULL,
  measure_type     CHARACTER(1) NOT NULL,
  server_location  CHARACTER(1) NOT NULL,
  descr            VARCHAR(32)
);

-- Primary key
ALTER TABLE metrics.ftypes
ADD CONSTRAINT ftypes$ftype_id_pk 
PRIMARY KEY (ftype_id)
WITH (FILLFACTOR = 100);
-- USING INDEX TABLESPACE :dc_index;

-- Index on Name
CREATE UNIQUE INDEX ftypes$name_uidx 
ON metrics.ftypes (name); 
-- TABLESPACE :dc_index;

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE metrics.ftypes FROM PUBLIC;
ALTER TABLE metrics.ftypes OWNER TO metrics;
GRANT ALL ON TABLE metrics.ftypes TO postgres;
GRANT SELECT ON TABLE metrics.ftypes TO rptuser;

-- Seed data (constants)
INSERT INTO metrics.ftypes VALUES
(1,  1, 'Flow-U', 'g', 'g', 'Flow, ServerLocation = g'),
(2,  1, 'Flow-D', 'g', 'd', 'Flow, ServerLocation = d'),
(3,  1, 'Flow-S', 'g', 's', 'Flow, ServerLocation = s'),
(4,  1, 'Ping-U', 'p', 'g', 'Ping, ServerLocation = g, Flow'),
(5,  2, 'Ping-D', 'p', 'd', 'Ping, ServerLocation = d'),
(6,  2, 'Ping-S', 'p', 's', 'Ping, ServerLocation = s'),
(7,  1, 'RTCP-U', 'v', 'g', 'VoIP, ServerLocation = g, Flow'),
(8,  3, 'RTCP-D', 'v', 'd', 'VoIP, ServerLocation = d'),
(9,  3, 'RTCP-S', 'v', 's', 'VoIP, ServerLocation = s'),
(10, 1, 'RTM-U',  'a', 'g', 'RTM,  ServerLocation = g, Flow'),
(11, 4, 'RTM-D',  'a', 'd', 'RTM,  ServerLocation = d'),
(12, 1, 'RTM-S',  'a', 's', 'RTM,  ServerLocation = s, Flow'),
(13, 1, 'TCP-U',  't', 'g', 'Pet,  ServerLocation = g, Flow'),
(14, 1, 'TCP-D',  't', 'd', 'Pet,  ServerLocation = d, Flow'),
(15, 5, 'TCP-S',  't', 's', 'Pet,  ServerLocation = s');

-- =========================
-- Table "logs"
-- =========================
CREATE SEQUENCE metrics.log_id_seq
INCREMENT BY 1
MINVALUE     1
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON metrics.log_id_seq TO metrics;   

CREATE TABLE metrics.logs
(
  log_id      INTEGER NOT NULL DEFAULT NEXTVAL('log_id_seq'), 
  func_name   VARCHAR NOT NULL,
  statement   TEXT NOT NULL DEFAULT '',
  message     TEXT, 
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Primary key
ALTER TABLE metrics.logs
ADD CONSTRAINT logs$log_id_pk 
PRIMARY KEY (log_id)
WITH (FILLFACTOR = 100);
-- USING INDEX TABLESPACE :dc_index;

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE metrics.logs FROM PUBLIC;
ALTER TABLE metrics.logs OWNER TO metrics;
GRANT ALL ON TABLE metrics.logs TO postgres;
GRANT INSERT, UPDATE, SELECT ON TABLE metrics.logs TO rptuser;

-- =========================
-- Table "perfs"
-- =========================
CREATE SEQUENCE metrics.perf_id_seq
INCREMENT BY 1
MINVALUE     1
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON metrics.perf_id_seq TO metrics;   

CREATE TABLE metrics.perfs
(
  perf_id     INTEGER NOT NULL DEFAULT NEXTVAL('perf_id_seq'), 
  func_name   VARCHAR NOT NULL,
  params      TEXT NOT NULL DEFAULT 'Undefined',
  beg_time    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  duration    INTERVAL
);

-- Primary key
ALTER TABLE metrics.perfs
ADD CONSTRAINT perfs$perf_id_pk 
PRIMARY KEY (perf_id)
WITH (FILLFACTOR = 100);
-- USING INDEX TABLESPACE :dc_index;

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE metrics.perfs FROM PUBLIC;
ALTER TABLE metrics.perfs OWNER TO metrics;
GRANT ALL ON TABLE metrics.perfs TO postgres;
GRANT INSERT, UPDATE, SELECT ON TABLE metrics.logs TO rptuser;

-- =========================
-- Table "classes"
-- =========================
CREATE SEQUENCE class_id_seq 
INCREMENT BY 1
MINVALUE     1
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON class_id_seq TO metrics;   

CREATE TABLE classes
(
  class_id   INT4         NOT NULL DEFAULT NEXTVAL('class_id_seq'), 
  name       VARCHAR(64)  NOT NULL DEFAULT '',
  path       VARCHAR(255) NOT NULL,
  l_idx      INT4         NOT NULL DEFAULT 0,
  r_idx      INT4         NOT NULL DEFAULT 0,
  parent_id  INT4
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE classes 
ADD CONSTRAINT classes$class_id_pk 
PRIMARY KEY (class_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Foreign key
ALTER TABLE classes 
ADD CONSTRAINT classes$parent_id_fk 
FOREIGN KEY (parent_id) 
REFERENCES metrics.classes (class_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Index oh Path
CREATE UNIQUE INDEX classes$path_uidx 
ON metrics.classes (path) 
TABLESPACE :dc_index;

-- Index on L_IDX field
CREATE INDEX classes$l_idx_idx 
ON metrics.classes (l_idx) 
TABLESPACE :dc_index;

-- Index on FK
CREATE INDEX classes$class_id_idx 
ON metrics.classes (class_id) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE classes IS 
'Contains information about Known Classes.';
COMMENT ON INDEX classes$path_uidx  IS 
'Enforces uniqueness on Full Class Name (path).';
COMMENT ON COLUMN classes.class_id  IS 'PK. Unique Id of the Known Class.';
COMMENT ON COLUMN classes.name      IS 'Short Name of the Class. Example: MPEG-Video';
COMMENT ON COLUMN classes.path      IS 'Full Name of the Class. Example: Outbound/Outside/MPEG-Video';
COMMENT ON COLUMN classes.l_idx     IS 'Left Index for the Tree Traversal Algorithm.';
COMMENT ON COLUMN classes.r_idx     IS 'Right Index for the Tree Traversal Algorithm.';
COMMENT ON COLUMN classes.parent_id IS 'Class Id of the Parent Class in the Tree of Classes.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE classes FROM PUBLIC;
ALTER TABLE classes OWNER TO metrics;
GRANT ALL ON TABLE classes TO postgres;
GRANT SELECT ON TABLE classes TO rptuser;

-- =========================
-- Table "partitions"
-- =========================
CREATE SEQUENCE partition_id_seq 
INCREMENT BY 1
MINVALUE     1
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON partition_id_seq TO metrics;   

CREATE TABLE partitions
(
  part_id    INT4         NOT NULL DEFAULT NEXTVAL('partition_id_seq'), 
  name       VARCHAR(64)  NOT NULL DEFAULT '',
  path       VARCHAR(255) NOT NULL,
  l_idx      INT4         NOT NULL DEFAULT 0,
  r_idx      INT4         NOT NULL DEFAULT 0,
  parent_id  INT4
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE partitions 
ADD CONSTRAINT partitions$part_id_pk 
PRIMARY KEY (part_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Foreign key
ALTER TABLE partitions 
ADD CONSTRAINT partitions$parent_id_fk 
FOREIGN KEY (parent_id)
REFERENCES metrics.partitions (part_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Index on Path
CREATE UNIQUE INDEX partitions$path_uidx 
ON metrics.partitions (path) 
TABLESPACE :dc_index;

-- Index on L_IDX field
CREATE INDEX partitions$l_idx_idx 
ON metrics.partitions (l_idx) 
TABLESPACE :dc_index;

-- Index on FK
CREATE INDEX partitions$parent_id_idx 
ON metrics.partitions (parent_id) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE partitions IS 
'Contains information about Partitions (ME).';
COMMENT ON INDEX partitions$path_uidx IS 
'Enforces uniqueness on Full Partition Name (path).';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE partitions FROM PUBLIC;
ALTER TABLE partitions OWNER TO metrics;
GRANT ALL ON TABLE partitions TO postgres;
GRANT SELECT ON TABLE partitions TO rptuser;

-- =========================
-- Table "links"
-- =========================
CREATE SEQUENCE link_id_seq 
INCREMENT BY 1
MINVALUE     1
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON link_id_seq TO metrics;   

CREATE TABLE links
(
  link_id    INT2  NOT NULL DEFAULT NEXTVAL('link_id_seq'), 
  name       CHAR(24)  NOT NULL DEFAULT '',
  path       CHAR(256) NOT NULL
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE links 
ADD CONSTRAINT links$link_id_pk 
PRIMARY KEY (link_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index on Path
CREATE UNIQUE INDEX links$path_uidx 
ON links (path) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE links IS 
'Contains information about Links (ME).';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE links FROM PUBLIC;
ALTER TABLE links OWNER TO metrics;
GRANT ALL ON TABLE links TO postgres;
GRANT SELECT ON TABLE links TO rptuser;

-- =========================
-- Table "interfaces"
-- =========================
CREATE SEQUENCE interface_id_seq 
INCREMENT BY 1
MINVALUE     1
MAXVALUE     32767
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON interface_id_seq TO metrics;   

CREATE TABLE interfaces
(
  interface_id  SMALLINT  NOT NULL DEFAULT NEXTVAL('interface_id_seq'), 
  name          CHAR(16)  NOT NULL,
  descr         VARCHAR(128) 
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE interfaces 
ADD CONSTRAINT interfaces$interface_id_pk 
PRIMARY KEY (interface_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index on Name
CREATE UNIQUE INDEX interfaces$name_uidx 
ON interfaces (name) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE interfaces IS 
'Contains the description of the Inerfaces.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE interfaces FROM PUBLIC;
ALTER TABLE interfaces OWNER TO metrics;
GRANT ALL ON TABLE interfaces TO postgres;
GRANT SELECT ON TABLE interfaces TO rptuser;

-- =========================
-- Table "services"
-- =========================
CREATE SEQUENCE service_id_seq 
INCREMENT BY 1
MINVALUE     1
MAXVALUE     32767
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON service_id_seq TO metrics;   

CREATE TABLE services
(
  service_id SMALLINT  NOT NULL DEFAULT NEXTVAL('service_id_seq'), 
  name       CHAR(24)  NOT NULL,
  ord_id     INT2
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE services 
ADD CONSTRAINT services$service_id_pk 
PRIMARY KEY (service_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index on Name
CREATE UNIQUE INDEX services$name_uidx 
ON services (name) 
TABLESPACE :dc_index;

-- Commants
COMMENT ON TABLE services IS 
'Dimension Table. Describes all Services.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE services FROM PUBLIC;
ALTER TABLE services OWNER TO metrics;
GRANT ALL ON TABLE services TO postgres;
GRANT SELECT ON TABLE services TO rptuser;

-- =========================
-- Table "protocols"
-- =========================
CREATE TABLE protocols
(
  protocol_id SMALLINT  NOT NULL, 
  name        CHAR(24)  NOT NULL,
  descr       VARCHAR(128)
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE protocols 
ADD CONSTRAINT protocols$protocol_id_pk 
PRIMARY KEY (protocol_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index on Name
CREATE UNIQUE INDEX protocols$name_idx 
ON protocols (name) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE protocols IS 
'Describes all Internet Protocols.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE protocols FROM PUBLIC;
ALTER TABLE protocols OWNER TO metrics;
GRANT ALL ON TABLE protocols TO postgres;
GRANT SELECT ON TABLE protocols TO rptuser;

-- =========================
-- Table "tcp_flags"
-- Note: tcp_flag_id = Setting Bits
-- =========================
CREATE TABLE tcp_flags
(
  tcp_flag_id   INT2      NOT NULL,
  descr         CHAR(32)  NOT NULL
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE tcp_flags
ADD CONSTRAINT tcp_flags$tcp_flag_id_pk 
PRIMARY KEY (tcp_flag_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index
CREATE UNIQUE INDEX tcp_flags$descr_idx 
ON tcp_flags (descr) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE tcp_flags IS 
'Dimension Table. Decode TCP Flags: ID -> Descr.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE tcp_flags FROM PUBLIC;
ALTER TABLE tcp_flags OWNER TO metrics;
GRANT ALL ON TABLE tcp_flags TO postgres;
GRANT SELECT ON TABLE tcp_flags TO rptuser;

-- =========================
-- Table "devices"
-- =========================
CREATE SEQUENCE device_id_seq 
INCREMENT BY 1
MINVALUE     1
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON device_id_seq TO metrics;   

CREATE TABLE devices 
(
  device_id           INT4     NOT NULL DEFAULT NEXTVAL('device_id_seq'),
  serial_num          CHAR(16) NOT NULL,
  ip_address          CHAR(16) NOT NULL,
  device_name         VARCHAR(128) NOT NULL DEFAULT 'Undefined',
  model_name          VARCHAR(64),
  password            CHAR(32) NOT NULL DEFAULT '',
  query_interval      INTEGER  NOT NULL DEFAULT 900,
  data_granularity    INTEGER  NOT NULL DEFAULT 300,
  discovery_interval  INTEGER  NOT NULL DEFAULT 43200,
  fdr_port_num        INTEGER  NOT NULL DEFAULT 0,
  me_port_num         INTEGER  NOT NULL DEFAULT 80,
  is_me_secure        BOOL     NOT NULL DEFAULT FALSE,
  time_zone           SMALLINT NOT NULL DEFAULT -7,
  is_collect_me       BOOL NOT NULL DEFAULT TRUE,
  is_collect_pktr2    BOOL NOT NULL DEFAULT TRUE,
  is_collect_netflow5 BOOL NOT NULL DEFAULT TRUE,
  is_available        BOOL NOT NULL DEFAULT TRUE,
  last_class_time     TIMESTAMPTZ NOT NULL DEFAULT DATE_TRUNC('hour', NOW()) + ((15 * (EXTRACT('minute' FROM NOW())::INT/15 - 1)::INT)::TEXT||' minute')::INTERVAL,
  last_partition_time TIMESTAMPTZ NOT NULL DEFAULT DATE_TRUNC('hour', NOW()) + ((15 * (EXTRACT('minute' FROM NOW())::INT/15 - 1)::INT)::TEXT||' minute')::INTERVAL,
  last_link_time      TIMESTAMPTZ NOT NULL DEFAULT DATE_TRUNC('hour', NOW()) + ((15 * (EXTRACT('minute' FROM NOW())::INT/15 - 1)::INT)::TEXT||' minute')::INTERVAL
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE devices
ADD CONSTRAINT devices$device_id_pk 
PRIMARY KEY (device_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Indexes
CREATE UNIQUE INDEX devices$serial_num_uidx 
ON devices (serial_num) 
TABLESPACE :dc_index;

CREATE INDEX devices$ip_address_idx 
ON devices (ip_address) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE devices IS 
'Dimension Table. Contains information about Packet Shapers.';
COMMENT ON COLUMN devices.device_id           IS 'PK. Unique ID of the Packet Shaper.';
COMMENT ON COLUMN devices.serial_num          IS 'Unique Serial Number Packet Shaper.';
COMMENT ON COLUMN devices.ip_address          IS 'Unique IP address of the Packet Shaper.';
COMMENT ON COLUMN devices.device_name         IS 'NOT Unique Name of the Packet Shaper.';
COMMENT ON COLUMN devices.model_name          IS 'Device Model Name';
COMMENT ON COLUMN devices.password            IS 'Password to connect to the Packet Shaper.';
COMMENT ON COLUMN devices.query_interval      IS 'How often (in secs) do we ask Shapers for ME data: 60 minutes = once per hour). Values 60 * [5, 15(def), 30, 60].';
COMMENT ON COLUMN devices.data_granularity    IS 'What we divide the period (in secs) by: 15 minutes give us four data samples per class or link or partition per hour. Values 60 * [1, 5(def), 15, 30, 60].';
COMMENT ON COLUMN devices.discovery_interval  IS 'How often (in secs) do we Refresh our Class or Partition Lists when there is, otherwise no event to trigger discovery. Default value: 12hrs = 43200 sec.';
COMMENT ON COLUMN devices.fdr_port_num        IS 'Device Port Number.';
COMMENT ON COLUMN devices.me_port_num         IS 'ME Port Number.';
COMMENT ON COLUMN devices.is_me_secure        IS 'ME secure collection attribute.';
COMMENT ON COLUMN devices.time_zone           IS 'Time zone number of the Packet Shaper.';
COMMENT ON COLUMN devices.is_collect_me       IS 'ME Collector attribute.';
COMMENT ON COLUMN devices.is_collect_pktr2    IS 'PKTR2 Collector attribute.';
COMMENT ON COLUMN devices.is_collect_netflow5 IS 'NETFLOW5 Collector attribute.';
COMMENT ON COLUMN devices.is_available        IS 'Device availability attribute.';
COMMENT ON COLUMN devices.last_class_time     IS 'The end time of last class data collection.';
COMMENT ON COLUMN devices.last_partition_time IS 'The end time of last partition data collection.';
COMMENT ON COLUMN devices.last_link_time      IS  'The end time of last link data collection.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE devices FROM PUBLIC;
ALTER TABLE devices OWNER TO metrics;
GRANT ALL ON TABLE devices TO postgres;
GRANT SELECT ON TABLE devices TO rptuser;

-- =========================
-- Table "dev_interfaces"
-- =========================
CREATE TABLE dev_interfaces
(
  device_id     INT4  NOT NULL,
  interface_id  INT2  NOT NULL 
)
TABLESPACE :dc_data;

-- Foreign key
ALTER TABLE dev_interfaces
ADD CONSTRAINT dev_ints$device_id_fk 
FOREIGN KEY (device_id)
REFERENCES devices (device_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Foreign key
ALTER TABLE dev_interfaces
ADD CONSTRAINT dev_ints$interface_id_fk 
FOREIGN KEY (interface_id)
REFERENCES interfaces (interface_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Indexes on FK
CREATE INDEX dev_ints$device_id_idx 
ON dev_interfaces (device_id) 
TABLESPACE :dc_index;

CREATE INDEX dev_ints$interface_id_idx 
ON dev_interfaces (interface_id) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE dev_interfaces IS 
'M:M Table. Describes which Interfaces are applicable to Device.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE dev_interfaces FROM PUBLIC;
ALTER TABLE dev_interfaces OWNER TO metrics;
GRANT ALL ON TABLE dev_interfaces TO postgres;
GRANT SELECT ON TABLE dev_interfaces TO rptuser;

-- =========================
-- Table "dev_classes"
-- =========================
-- ME, discovery: class_id    (ME tables)
-- FDR, pktr0:    ud_class_id (FDR tables)
CREATE TABLE dev_classes
(
  device_id     INT4  NOT NULL,
  class_id      INT4,
  ud_class_id   INT4
)
TABLESPACE :dc_data;

ALTER TABLE dev_classes 
ADD CONSTRAINT dev_classes$class_ids 
CHECK ((class_id IS NOT NULL) 
    OR (ud_class_id IS NOT NULL));

-- Foreign key
ALTER TABLE dev_classes
ADD CONSTRAINT dev_classes$device_id_fk 
FOREIGN KEY (device_id)
REFERENCES devices (device_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Foreign key
ALTER TABLE dev_classes
ADD CONSTRAINT dev_classes$class_id_fk 
FOREIGN KEY (class_id)
REFERENCES classes (class_id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Indexes on FK
CREATE UNIQUE INDEX dev_classes$device_class_id_uidx
ON metrics.dev_classes (device_id, class_id)
TABLESPACE :dc_index;

CREATE UNIQUE INDEX dev_classes$device_ud_class_id_uidx
ON metrics.dev_classes (device_id, ud_class_id)
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE dev_classes IS 
'M:M Table. Describes which Classes are applicable to Device.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE dev_classes FROM PUBLIC;
ALTER TABLE dev_classes OWNER TO metrics;
GRANT ALL ON TABLE dev_classes TO postgres;
GRANT SELECT ON TABLE dev_classes TO rptuser;

-- =========================
-- Table "dev_partitions"
-- =========================
CREATE TABLE dev_partitions
(
  device_id     INT4  NOT NULL,
  part_id       INT4, 
  ud_part_id    INT4
)
TABLESPACE :dc_data;

-- Foreign key
ALTER TABLE dev_partitions
ADD CONSTRAINT dev_parts$device_id_fk FOREIGN KEY (device_id)
REFERENCES devices (device_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Foreign key
ALTER TABLE dev_partitions
ADD CONSTRAINT dev_parts$part_id_fk FOREIGN KEY (part_id)
REFERENCES partitions (part_id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE dev_partitions 
ADD CONSTRAINT dev_parts$part_ids 
CHECK ((part_id IS NOT NULL) 
    OR (ud_part_id IS NOT NULL));

--CREATE INDEX dev_parts$device_id_idx  ON dev_partitions (device_id) TABLESPACE :dc_index;
--CREATE INDEX dev_parts$part_id_idx    ON dev_partitions (part_id) TABLESPACE :dc_index;
--CREATE INDEX dev_parts$ud_part_id_idx ON dev_partitions (ud_part_id) TABLESPACE :dc_index;

-- Index on FK
CREATE UNIQUE INDEX dev_parts$device_part_id_uidx
ON metrics.dev_partitions (device_id, part_id)
TABLESPACE :dc_index;

-- Unique Index
CREATE UNIQUE INDEX dev_parts$device_ud_part_id_uidx
ON metrics.dev_partitions (device_id, ud_part_id)
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE dev_partitions IS 
'M:M Table. Describes which Partitions are applicable to Device.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE dev_partitions FROM PUBLIC;
ALTER TABLE dev_partitions OWNER TO metrics;
GRANT ALL ON TABLE dev_partitions TO postgres;
GRANT SELECT ON TABLE dev_partitions TO rptuser;

-- =========================
-- Table "dev_links"
-- =========================
CREATE TABLE dev_links
(
  device_id     INT4  NOT NULL,
  link_id       INT2  NOT NULL 
)
TABLESPACE :dc_data;

-- Foreign key
ALTER TABLE dev_links
ADD CONSTRAINT dev_links$device_id_fk 
FOREIGN KEY (device_id)
REFERENCES devices (device_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Foreign key
ALTER TABLE dev_links
ADD CONSTRAINT dev_links$link_id_fk 
FOREIGN KEY (link_id)
REFERENCES links (link_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Indexes on FK
CREATE INDEX dev_links$device_id_idx
ON dev_links (device_id)
TABLESPACE :dc_index;

CREATE INDEX dev_links$link_id_idx
ON dev_links (link_id)
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE dev_links IS 
'M:M Table. Describes which Links are applicable to Device.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE dev_links FROM PUBLIC;
ALTER TABLE dev_links OWNER TO metrics;
GRANT ALL ON TABLE dev_links TO postgres;
GRANT SELECT ON TABLE dev_links TO rptuser;

-- =========================
-- Table "groups"
-- =========================
CREATE TABLE groups
(
  group_id  INTEGER NOT NULL,
  name      VARCHAR(32) NOT NULL,
  descr     VARCHAR(128)
)
TABLESPACE pg_default;

-- Primary key
ALTER TABLE groups
ADD CONSTRAINT groups$group_id_pk 
PRIMARY KEY (group_id)
WITH (FILLFACTOR = 100) 
USING INDEX
TABLESPACE pg_default;

-- Index on Name 
CREATE UNIQUE INDEX groups$name_uidx 
ON groups (name) 
TABLESPACE pg_default;

-- Comments
COMMENT ON TABLE groups IS 
'Contains information about Device Groups.';
COMMENT ON INDEX groups$name_uidx IS 
'Enforces uniqueness on Device Group Name.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE groups FROM PUBLIC;
ALTER TABLE groups OWNER TO metrics;
GRANT ALL ON TABLE groups TO postgres;
GRANT SELECT ON TABLE groups TO rptuser;

-- =========================
-- Table "group_definitions"
-- =========================
CREATE TABLE group_definitions
(
  group_id    INTEGER NOT NULL,
  definition  VARCHAR NOT NULL
)
TABLESPACE pg_default;

-- Foreign key
ALTER TABLE group_definitions
ADD CONSTRAINT group_definitions$group_id_fk 
FOREIGN KEY (group_id)
REFERENCES metrics.groups (group_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Unique Index (avoid duplicates of the definitions)
CREATE UNIQUE INDEX group_definitions$group_id_definition_uidx 
ON group_definitions (group_id, definition) 
TABLESPACE pg_default;

-- Comments
COMMENT ON TABLE group_definitions IS 
'Describes a set of definitions (device_ids for now) for every Device Group.';
COMMENT ON INDEX group_definitions$group_id_definition_uidx IS 
'Enforces uniqueness on Device Group Id and Definition.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE group_definitions FROM PUBLIC;
ALTER TABLE group_definitions OWNER TO metrics;
GRANT ALL ON TABLE group_definitions TO postgres;
GRANT SELECT ON TABLE group_definitions TO rptuser;

-- =========================
-- Table "group_devices"
-- =========================
CREATE TABLE group_devices
(
  group_id    INTEGER NOT NULL,
  device_id   INTEGER NOT NULL
)
TABLESPACE :dc_data;

-- Foreign keys
ALTER TABLE group_devices
ADD CONSTRAINT group_devices$group_id_fk 
FOREIGN KEY (group_id)
REFERENCES metrics.groups (group_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE group_devices
ADD CONSTRAINT group_devices$device_id_fk 
FOREIGN KEY (device_id)
REFERENCES metrics.devices (device_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Indexes on FK
CREATE INDEX group_devices$group_id_idx
ON group_devices (group_id)
TABLESPACE :dc_index;

CREATE INDEX group_devices$device_id_idx
ON group_devices (device_id)
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE group_devices IS 
'M:M Table. Describes which Devices are included in the Logical Group of Devices.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE group_devices FROM PUBLIC;
ALTER TABLE group_devices OWNER TO metrics;
GRANT ALL ON TABLE group_devices TO postgres;
GRANT SELECT ON TABLE group_devices TO rptuser;

-- =========================
-- Table "applications"
-- =========================
CREATE TABLE applications
(
  application_id  INTEGER NOT NULL,
  name            VARCHAR NOT NULL,
  descr           VARCHAR
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE applications
ADD CONSTRAINT applications$application_id_pk 
PRIMARY KEY (application_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index on Name 
CREATE UNIQUE INDEX applications$name_uidx 
ON metrics.applications (name) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE applications IS 
'Dimension table. Contains information about Applications.';
COMMENT ON INDEX applications$name_uidx IS 
'Enforces uniqueness on Application Name.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE applications FROM PUBLIC;
ALTER TABLE applications OWNER TO metrics;
GRANT ALL ON TABLE applications TO postgres;
GRANT SELECT ON TABLE applications TO rptuser;

-- ===============================
-- Table "application_definitions"
-- ===============================
CREATE TABLE application_definitions
(
  application_id  INTEGER NOT NULL,
  definition      VARCHAR NOT NULL
)
TABLESPACE :dc_data;

-- Foreign key
ALTER TABLE application_definitions
ADD CONSTRAINT appl_definitions$application_id_fk 
FOREIGN KEY (application_id)
REFERENCES metrics.applications (application_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Index on FK
CREATE UNIQUE INDEX appl_definitions$appl_id_definition_uidx 
ON metrics.application_definitions (application_id, definition) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE application_definitions IS 
'Describes a set of definitions (masks) for every Application.';
COMMENT ON INDEX appl_definitions$appl_id_definition_uidx IS 
'Enforces uniqueness on Application Id and Definitions.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE application_definitions FROM PUBLIC;
ALTER TABLE application_definitions OWNER TO metrics;
GRANT ALL ON TABLE application_definitions TO postgres;
GRANT SELECT ON TABLE application_definitions TO rptuser;

-- ===========================
-- Table "application_classes"
-- ===========================
CREATE TABLE application_classes
(
  application_id  INTEGER NOT NULL,
  class_id        INTEGER NOT NULL
)
TABLESPACE :dc_data;

-- Foreign key
ALTER TABLE application_classes
ADD CONSTRAINT appl_classes$application_id_fk 
FOREIGN KEY (application_id)
REFERENCES applications (application_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Foreign key
ALTER TABLE application_classes
ADD CONSTRAINT appl_classes$class_id_fk 
FOREIGN KEY (class_id)
REFERENCES classes (class_id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Indexes on FK
CREATE INDEX appl_classes$application_id_idx 
ON application_classes (application_id) 
TABLESPACE :dc_index;

CREATE INDEX appl_classes$class_id_idx  
ON application_classes (class_id) 
TABLESPACE :dc_index;

-- Unique Index
CREATE UNIQUE INDEX appl_classes$appl_class_id_uidx 
ON metrics.application_classes (application_id, class_id) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE application_classes IS 
'M:M Table. Describes which Traffic Classes are included in the Application.';
COMMENT ON INDEX appl_classes$appl_class_id_uidx IS 
'Enforces uniqueness on Application and Class Ids.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE application_classes FROM PUBLIC;
ALTER TABLE application_classes OWNER TO metrics;
GRANT ALL ON TABLE application_classes TO postgres;
GRANT SELECT ON TABLE application_classes TO rptuser;

-- =========================
-- Table "sites"
-- =========================
CREATE TABLE sites
(
  site_id  INTEGER NOT NULL,
  name     VARCHAR NOT NULL,
  descr    VARCHAR
)
TABLESPACE pg_default;

-- Primary key
ALTER TABLE sites
ADD CONSTRAINT sites$site_id_pk 
PRIMARY KEY (site_id)
WITH (FILLFACTOR = 100) 
USING INDEX 
TABLESPACE pg_default;

-- Index on Name 
CREATE UNIQUE INDEX sites$name_uidx 
ON sites (name) 
TABLESPACE pg_default;

-- Comments
COMMENT ON TABLE sites IS 
'Contains information about Sites.';
COMMENT ON INDEX sites$name_uidx IS 
'Enforces uniqueness on Site Name.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE sites FROM PUBLIC;
ALTER TABLE sites OWNER TO metrics;
GRANT ALL ON TABLE sites TO postgres;
GRANT SELECT ON TABLE sites TO rptuser;

-- =========================
-- Table "site_definitions"
-- =========================
CREATE TABLE site_definitions
(
  site_id     INTEGER NOT NULL,
  definition  VARCHAR NOT NULL
)
TABLESPACE pg_default;

-- Foreign key
ALTER TABLE site_definitions
ADD CONSTRAINT site_definitions$site_id_fk 
FOREIGN KEY (site_id)
REFERENCES metrics.sites (site_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Index on FK
CREATE UNIQUE INDEX site_definitions$site_id_definition_uidx 
ON site_definitions (site_id, definition) 
TABLESPACE pg_default;

-- Comments
COMMENT ON TABLE site_definitions IS 
'Describes a set of definitions (masks) for every Site.';
COMMENT ON INDEX site_definitions$site_id_definition_uidx IS 
'Enforces uniqueness on Site Id and Definitions.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE site_definitions FROM PUBLIC;
ALTER TABLE site_definitions OWNER TO metrics;
GRANT ALL ON TABLE site_definitions TO postgres;
GRANT SELECT ON TABLE site_definitions TO rptuser;

-- =========================
-- Table "site_classes"
-- =========================
CREATE TABLE site_classes
(
  site_id   INTEGER NOT NULL,
  class_id  INTEGER NOT NULL
)
TABLESPACE pg_default;

-- Foreign key
ALTER TABLE site_classes
ADD CONSTRAINT site_classes$site_id_fk 
FOREIGN KEY (site_id)
REFERENCES metrics.sites (site_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Foreign key
ALTER TABLE site_classes
ADD CONSTRAINT site_classes$class_id_fk 
FOREIGN KEY (class_id)
REFERENCES classes (class_id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Indexes on FK
CREATE INDEX site_classes$site_id_idx 
ON site_classes (site_id) 
TABLESPACE pg_default;

CREATE INDEX site_classes$class_id_idx  
ON site_classes (class_id) 
TABLESPACE pg_default;

-- Unique Index
CREATE UNIQUE INDEX site_classes$site_class_id_uidx 
ON site_classes (site_id, class_id) 
TABLESPACE pg_default;

-- Comments
COMMENT ON TABLE site_classes IS 
'M:M Table. Describes which Traffic Classes belongs to Site.';
COMMENT ON INDEX site_classes$site_class_id_uidx IS 
'Enforces uniqueness on Site and Class Ids.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE site_classes FROM PUBLIC;
ALTER TABLE site_classes OWNER TO metrics;
GRANT ALL ON TABLE site_classes TO postgres;
GRANT SELECT ON TABLE site_classes TO rptuser;

-- =========================
-- Table "periods"
-- =========================
-- Note: NO predefined set of period_ids
CREATE SEQUENCE period_id_seq
INCREMENT BY 1
MINVALUE     1
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON period_id_seq TO metrics;   

CREATE TABLE periods
(
  period_id         INT4 NOT NULL DEFAULT NEXTVAL('period_id_seq'),
  period_name       CHAR(16) NOT NULL,
  period_level      CHAR(8)  NOT NULL,
  period_year       INT2,   -- year_num
  period_month      INT2,   -- month_num_of_year
  period_day        INT2,   -- day_num_of_month
  period_hour       INT2,   -- hour_num_of_day
  period_min        INT2    -- Nmin_num_of_hour
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE periods
ADD CONSTRAINT periods$period_id_pk 
PRIMARY KEY (period_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index on Name
CREATE UNIQUE INDEX periods$period_name_uidx 
ON periods (period_name) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE periods IS 
'Dimension Table. Describes all Time Periods in the Measurement Tables.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE periods FROM PUBLIC;
ALTER TABLE periods OWNER TO metrics;
GRANT ALL ON TABLE periods TO postgres;
GRANT SELECT ON TABLE periods TO rptuser;

ALTER TABLE periods ADD CONSTRAINT periods$period_level_names 
CHECK (period_level = 'min'
  OR period_level = 'hour'
  OR period_level = 'day'
  OR period_level = 'month'
  OR period_level = 'year'
);

ALTER TABLE periods ADD CONSTRAINT periods$period_level_check
CHECK ( 
  (period_level = 'year'
  )
  OR (period_level = 'month'
    AND period_month IS NOT NULL
  )
  OR (period_level = 'day'
    AND period_month IS NOT NULL
    AND period_day IS NOT NULL
  )
  OR (period_level = 'hour'
    AND period_month IS NOT NULL
    AND period_day IS NOT NULL
    AND period_hour IS NOT NULL
  )
  OR (period_level = 'min'
    AND period_month IS NOT NULL
    AND period_day IS NOT NULL
    AND period_hour IS NOT NULL
    AND period_min IS NOT NULL
  )
);

-- =========================
-- Table "reports"
-- =========================
CREATE TABLE reports
(
  report_id       INT2 NOT NULL,
  schema_name     VARCHAR(16) NOT NULL,
  report_name     VARCHAR(64) NOT NULL,
  function_name   VARCHAR(64) NOT NULL,
  par_types       VARCHAR(255),
  res_type        VARCHAR(128),
  cond_str        VARCHAR(255),
  descr           VARCHAR(128)
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE reports
ADD CONSTRAINT reports$report_id_pk 
PRIMARY KEY (report_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index
CREATE UNIQUE INDEX reports$sch_rept_params_idx 
ON reports (schema_name, function_name, par_types) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE reports IS 
'Describes all Generated Reports.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE reports FROM PUBLIC;
ALTER TABLE reports OWNER TO metrics;
GRANT ALL ON TABLE reports TO postgres;
GRANT SELECT ON TABLE reports TO rptuser;

-- =========================
-- Table "rep_fields"
-- =========================
CREATE TABLE rep_fields
(
  report_id  INT2 NOT NULL,
  fld_name   VARCHAR(32) NOT NULL,
  fld_type   VARCHAR(16) NOT NULL,
  alias      VARCHAR(32),
  label      VARCHAR(32),
  unit       VARCHAR(8),
  aggregate  VARCHAR(16),
  ord_num    INT2 NOT NULL
)
TABLESPACE :dc_data;

-- Foreign key
ALTER TABLE rep_fields
ADD CONSTRAINT rep_fields$report_id_fk 
FOREIGN KEY (report_id) 
REFERENCES reports (report_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Indexes
CREATE UNIQUE INDEX rep_fields$rep_fld_name_idx 
ON rep_fields (report_id, fld_name)
TABLESPACE :dc_index;

CREATE UNIQUE INDEX rep_fields$rep_ord_idx 
ON rep_fields (report_id, ord_num) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE rep_fields IS 
'Describes all Fields for Generated Reports.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE rep_fields FROM PUBLIC;
ALTER TABLE rep_fields OWNER TO metrics;
GRANT ALL ON TABLE rep_fields TO postgres;
GRANT SELECT ON TABLE rep_fields TO rptuser;

-- ========================================================
--             Create Configuration tables
-- ========================================================

-- =========================
-- Table "config_schemas"
-- =========================
CREATE SEQUENCE config_schema_id_seq
INCREMENT BY 1
MINVALUE     1
MAXVALUE     128
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON config_schema_id_seq TO metrics;   

CREATE TABLE config_schemas
(
  config_schema_id  INT2         NOT NULL DEFAULT NEXTVAL('config_schema_id_seq'),
  sch_name          CHAR(8)      NOT NULL,
  type              CHAR(6)      NOT NULL, 
  granularity       CHAR(8)      NOT NULL,
  duration          INT2         NOT NULL,
  safeguard         INT2         NOT NULL DEFAULT 1,
  chunks            INT2         NOT NULL,
  table_prefix      CHAR(1)      NOT NULL,
  tname_length      INT2         NOT NULL,
  tpl_tname         VARCHAR(32)  NOT NULL,
  csv_status        BOOLEAN      NOT NULL DEFAULT FALSE,
  csv_duration      INT4         NOT NULL DEFAULT 0,
  csv_location      VARCHAR(128) NOT NULL DEFAULT '',
  created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
  created_by        VARCHAR(16)  NOT NULL DEFAULT USER,
  updated_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_by        VARCHAR(16)  NOT NULL DEFAULT USER
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE config_schemas
ADD CONSTRAINT config_schemas$config_schema_id_pk 
PRIMARY KEY (config_schema_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Indexes
CREATE UNIQUE INDEX config_schemas$sch_prefix_type_uidx 
ON config_schemas (sch_name, table_prefix, type) 
TABLESPACE :dc_index;

-- Comments
COMMENT ON TABLE config_schemas IS 
'Contains Configuration Information about FDR and ME Schemas.';
COMMENT ON COLUMN config_schemas.config_schema_id IS 'PK. DB generated ID.';
COMMENT ON COLUMN config_schemas.sch_name         IS 'Schema Name.';
COMMENT ON COLUMN config_schemas.type             IS 'Type of the Configuration Attribute.';
COMMENT ON COLUMN config_schemas.granularity      IS 'Level of Granularity for a Type.';
COMMENT ON COLUMN config_schemas.duration         IS 'User defined Duration for a given Type.';
COMMENT ON COLUMN config_schemas.safeguard        IS 'Safeguard interval in units of the duration.';
COMMENT ON COLUMN config_schemas.chunks           IS 'Application defined Number of Chunks (# of Tables per Type).';
COMMENT ON COLUMN config_schemas.table_prefix     IS 'Prefix of the Table Name.';
COMMENT ON COLUMN config_schemas.tname_length     IS 'Length of the Table Name for a Type.';
COMMENT ON COLUMN config_schemas.tpl_tname        IS 'Name of the template table for a Type.';
COMMENT ON COLUMN config_schemas.created_at       IS 'Datetime when record was created.';
COMMENT ON COLUMN config_schemas.created_by       IS 'User name who created the record.';
COMMENT ON COLUMN config_schemas.updated_at       IS 'Datetime when record was updated.';
COMMENT ON COLUMN config_schemas.updated_by       IS 'User name who updated the record.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE config_schemas FROM PUBLIC;
ALTER TABLE config_schemas OWNER TO metrics;
GRANT ALL ON TABLE config_schemas TO postgres;
-- GRANT SELECT ON TABLE config_schemas TO rptuser;

-- =========================
-- "config_pktr2"
-- =========================
INSERT INTO config_schemas VALUES (1,  'fdr', 'raw',   '0',      48, 1, 4, 'p', 13, 'pktr_raw_template');
INSERT INTO config_schemas VALUES (2,  'fdr', 'hour',  '15min',  48, 1, 1, 'p', 11, 'pktr_agg_template');
INSERT INTO config_schemas VALUES (3,  'fdr', 'day',   '1hour',  31, 1, 1, 'p', 9,  'pktr_agg_template');
INSERT INTO config_schemas VALUES (4,  'fdr', 'month', '1day',   6,  1, 1, 'p', 7,  'pktr_agg_template');
INSERT INTO config_schemas VALUES (5,  'fdr', 'year',  '1month', 2,  0, 1, 'p', 5,  'pktr_agg_template');

-- =========================
-- "config_netflow5"
-- =========================
INSERT INTO config_schemas VALUES (6,  'fdr', 'raw',   '0',      48, 1, 4, 'n', 13, 'netflow_raw_template');
INSERT INTO config_schemas VALUES (7,  'fdr', 'hour',  '15min',  48, 1, 1, 'n', 11, 'netflow_agg_template');
INSERT INTO config_schemas VALUES (8,  'fdr', 'day',   '1hour',  31, 1, 1, 'n', 9,  'netflow_agg_template');
INSERT INTO config_schemas VALUES (9,  'fdr', 'month', '1day',   6,  1, 1, 'n', 7,  'netflow_agg_template');
INSERT INTO config_schemas VALUES (10, 'fdr', 'year',  '1month', 2,  0, 1, 'n', 5,  'netflow_agg_template');

-- =========================
-- "config_classes"
-- =========================
INSERT INTO config_schemas VALUES (11, 'me', 'raw',   '0',      48, 1, 4, 'c', 13, 'class_raw_template');
INSERT INTO config_schemas VALUES (12, 'me', 'hour',  '15min',  48, 1, 1, 'c', 11, 'class_agg_template');
INSERT INTO config_schemas VALUES (13, 'me', 'day',   '1hour',  31, 1, 1, 'c', 9,  'class_agg_template');
INSERT INTO config_schemas VALUES (14, 'me', 'month', '1day',   6,  1, 1, 'c', 7,  'class_agg_template');
INSERT INTO config_schemas VALUES (15, 'me', 'year',  '1month', 2,  0, 1, 'c', 5,  'class_agg_template');

-- =========================
-- "config_partitions"
-- =========================
INSERT INTO config_schemas VALUES (16, 'me', 'raw',   '0',      48, 1, 4, 'p', 13, 'partition_raw_template'); 
INSERT INTO config_schemas VALUES (17, 'me', 'hour',  '15min',  48, 1, 1, 'p', 11, 'partition_agg_template'); 
INSERT INTO config_schemas VALUES (18, 'me', 'day',   '1hour',  31, 1, 1, 'p', 9,  'partition_agg_template'); 
INSERT INTO config_schemas VALUES (19, 'me', 'month', '1day',   6,  1, 1, 'p', 7,  'partition_agg_template'); 
INSERT INTO config_schemas VALUES (20, 'me', 'year',  '1month', 2,  0, 1, 'p', 5,  'partition_agg_template'); 

-- =========================
-- "config_links"
-- =========================
INSERT INTO config_schemas VALUES (21, 'me', 'raw',   '0',      48, 1, 4, 'l', 13, 'link_raw_template'); 
INSERT INTO config_schemas VALUES (22, 'me', 'hour',  '15min',  48, 1, 1, 'l', 11, 'link_agg_template'); 
INSERT INTO config_schemas VALUES (23, 'me', 'day',   '1hour',  31, 1, 1, 'l', 9,  'link_agg_template'); 
INSERT INTO config_schemas VALUES (24, 'me', 'month', '1day',   6,  1, 1, 'l', 7,  'link_agg_template'); 
INSERT INTO config_schemas VALUES (25, 'me', 'year',  '1month', 2,  0, 1, 'l', 5,  'link_agg_template'); 

-- Note: predefined config_schema_id = 1..25
ALTER SEQUENCE metrics.config_schema_id_seq RESTART WITH 26;

-- ========================================================
--             Collection Metadata Tables
-- ========================================================

-- =========================
-- Table "collection_types"
-- =========================
CREATE TABLE collection_types
(
  coll_type_id   INTEGER,  -- PK: Type of the Collection
  sch_name       VARCHAR,  -- Schema Name
  coll_name      VARCHAR,  -- Collection Name
  is_raw         BOOLEAN   -- Attribute: TRUE if RAW Data Collection; FALSE if Aggregated Data 
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE collection_types
ADD CONSTRAINT collection_types$coll_type_id_pk 
PRIMARY KEY (coll_type_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE collection_types FROM PUBLIC;
ALTER TABLE collection_types OWNER TO metrics;
GRANT ALL ON TABLE collection_types TO postgres;
-- GRANT SELECT ON TABLE collection_types TO rptuser;

-- Seed Data
INSERT INTO collection_types VALUES (1,  'fdr', 'pktr2', TRUE);
INSERT INTO collection_types VALUES (2,  'fdr', 'pktr2', FALSE);
INSERT INTO collection_types VALUES (3,  'fdr', 'netflow5', TRUE);
INSERT INTO collection_types VALUES (4,  'fdr', 'netflow5', FALSE);
INSERT INTO collection_types VALUES (5,  'me',  'classes', TRUE);
INSERT INTO collection_types VALUES (6,  'me',  'classes', FALSE);
INSERT INTO collection_types VALUES (7,  'me',  'links', TRUE);
INSERT INTO collection_types VALUES (8,  'me',  'links', FALSE);
INSERT INTO collection_types VALUES (9,  'me',  'partitions', TRUE);
INSERT INTO collection_types VALUES (10, 'me',  'partitions', FALSE);

-- =========================
-- Table "collection_vars"
-- =========================

CREATE SEQUENCE collection_var_id_seq
INCREMENT BY 1
MINVALUE     1
MAXVALUE     1024
START WITH   1
NO CYCLE;

GRANT ALL PRIVILEGES ON collection_var_id_seq TO metrics;   

CREATE TABLE collection_vars
(
  collection_var_id INT2 NOT NULL DEFAULT NEXTVAL('collection_var_id_seq'), -- PK
  coll_type_id      INTEGER NOT NULL,  -- FK: Type of the Collection
  ord_num           INTEGER NOT NULL,  -- Column Order Number
  agg_num           INTEGER NOT NULL,  -- Column Aggregation Number
  is_variable       BOOLEAN NOT NULL,  -- Attribute: TRUE, if Variable; FALSE otherwise
  is_axis           BOOLEAN NOT NULL,  -- Attribute: TRUE, if Axis; FALSE otherwise
  var_name          VARCHAR NOT NULL,  -- Name of the Variable or Field
  col_name          VARCHAR NOT NULL,  -- Column Name in the Database  
  db_type           VARCHAR NOT NULL,  -- Values: 'INTEGER'|'CHAR'|'VARCHAR'|'BYTEA'|'TIMESTAMPTZ'
  db_size           INTEGER NOT NULL,  -- Size of the variable in the Database
  db_condition      VARCHAR,           -- Values: 'NOT NULL' ['DEFAULT']
  agg_condition     VARCHAR,           -- Values: SUM(), COUNT(), MAX(), etc.
  is_index          BOOLEAN NOT NULL,  -- Index on Column: TRUE = index should be created
  var_type          VARCHAR,           -- Values: 'common'|'header'|'ignore'
  var_size          INTEGER,           -- Size of the variable in the Application 
  var_option        VARCHAR,           -- Option: 'persist'|
  cb_function       VARCHAR,           -- Name of the Callback Function
  is_standard       BOOLEAN NOT NULL DEFAULT FALSE, -- Standard variable attribute
  is_isp            BOOLEAN NOT NULL DEFAULT FALSE, -- ISP variable attribute
  is_turbo          BOOLEAN NOT NULL DEFAULT FALSE, -- Turbo variable attribute
  descr             VARCHAR            -- Description
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE collection_vars
ADD CONSTRAINT collection_vars$collection_var_id_pk 
PRIMARY KEY (collection_var_id)
WITH (FILLFACTOR = 100)
USING INDEX TABLESPACE :dc_index;

-- Foreign key
ALTER TABLE collection_vars
ADD CONSTRAINT collection_vars$coll_type_id_fk 
FOREIGN KEY (coll_type_id)
REFERENCES collection_types (coll_type_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Index on FK
CREATE UNIQUE INDEX collection_vars$coll_type_col_name_uidx 
ON collection_vars (coll_type_id, col_name) 
TABLESPACE :dc_index;

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE collection_vars FROM PUBLIC;
ALTER TABLE collection_vars OWNER TO metrics;
GRANT ALL ON TABLE collection_vars TO postgres;
-- GRANT SELECT ON TABLE collection_vars TO rptuser;

-- =========================
-- Table "components"
-- =========================
CREATE TABLE components
(
  comp_id      INTEGER NOT NULL,
  name         VARCHAR NOT NULL,
  version      VARCHAR,
  driver       VARCHAR,
  is_started   BOOLEAN NOT NULL DEFAULT FALSE
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE components
ADD CONSTRAINT components$comp_id_pk 
PRIMARY KEY (comp_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index on Name
CREATE UNIQUE INDEX components$name_uidx 
ON components (name) 
TABLESPACE :dc_index;

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE components FROM PUBLIC;
ALTER TABLE components OWNER TO metrics;
GRANT ALL ON TABLE components TO postgres;
-- GRANT SELECT ON TABLE components TO rptuser;

-- Seed data
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (1, 'postgresql', '8.2.4-1', '', TRUE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (2, 'collector', '2.1.08.11.20', '', TRUE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (3, 'metrics_schema', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (4, 'coll_db_config', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (5, 'metrics_functions', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (6, 'me_schema', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (7, 'me_functions', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (8, 'fdr_schema', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (9, 'fdr_functions', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (10, 'pljava', '2.0', 'pljava.jar', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (11, 'jdbc', '3.0', 'postgresql-8.2-505.jdbc3.jar', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (12, 'plpgsql_sec', '2.1.08.11.20', 'plpgsql_sec.sql', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (13, 'backup', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (14, 'check_performance', '2.1.08.11.20', '', FALSE);
INSERT INTO components (comp_id, name, version, driver, is_started) VALUES (15, 'error_log', '2.1.08.11.20', '', FALSE);

-- =========================
-- Table "codecs"
-- =========================
CREATE TABLE codecs
(
  codec_id          INT2 NOT NULL,
  codec_number      VARCHAR NOT NULL,
  standard_by       VARCHAR,
  bit_rate_kbps     NUMERIC(5, 2),
  eq_impair_factor  INT2,
  descr             VARCHAR(128)
)
TABLESPACE :dc_data;

-- Primary key
ALTER TABLE codecs
ADD CONSTRAINT codecs$codec_id_pk 
PRIMARY KEY (codec_id)
WITH (FILLFACTOR = 100) 
USING INDEX TABLESPACE :dc_index;

-- Index on codec_number
CREATE UNIQUE INDEX codecs$codec_number_bit_rate_uidx 
ON codecs (codec_number, bit_rate_kbps) 
TABLESPACE :dc_index;

-- Ñomments
COMMENT ON TABLE codecs IS 
'Dimension table. Contains information about Codecs.';

COMMENT ON COLUMN codecs.codec_id IS 'Codec Id.';
COMMENT ON COLUMN codecs.codec_number IS 'Number of the Codec (reference in the Standard).';
COMMENT ON COLUMN codecs.standard_by IS 'Owner of the Standard.';
COMMENT ON COLUMN codecs.bit_rate_kbps IS 'Based on the codec, this is the number of bits per second that need to be transmitted to deliver a voice call. (codec bit rate = codec sample size / codec sample interval).';
COMMENT ON COLUMN codecs.eq_impair_factor IS 'ITU-T G.113. Table 1.1. Equipmemnt Impairment Factor Ie.';
COMMENT ON COLUMN codecs.descr IS 'Description of the Codec Type.';

--COMMENT ON COLUMN codecs.sample_size_bytes IS 'Based on the codec, this is the number of bytes captured by the Digital Signal Processor (DSP) at each codec sample interval. For example, the G.729 coder operates on sample intervals of 10 ms, corresponding to 10 bytes (80 bits) per sample at a bit rate of 8 Kbps. (codec bit rate = codec sample size / codec sample interval).';
--COMMENT ON COLUMN codecs.sample_interval_ms IS 'This is the sample interval at which the codec operates. For example, the G.729 coder operates on sample intervals of 10 ms, corresponding to 10 bytes (80 bits) per sample at a bit rate of 8 Kbps. (codec bit rate = codec sample size / codec sample interval).'; 
--COMMENT ON COLUMN codecs.mean_option_score IS 'MOS is a system of grading the voice quality of telephone connections. With MOS, a wide range of listeners judge the quality of a voice sample on a scale of one (bad) to five (excellent). The scores are averaged to provide the MOS for the codec.'; 
--COMMENT ON COLUMN codecs.voice_payload_size_bytes IS 'The voice payload size represents the number of bytes (or bits) that are filled into a packet. The voice payload size must be a multiple of the codec sample size. For example, G.729 packets can use 10, 20, 30, 40, 50, or 60 bytes of voice payload size.'; 
--COMMENT ON COLUMN codecs.voice_payload_size_ms IS 'The voice payload size can also be represented in terms of the codec samples. For example, a G.729 voice payload size of 20 ms (two 10 ms codec samples) represents a voice payload of 20 bytes [ (20 bytes * 8) / (20 ms) = 8 Kbps ]';
--COMMENT ON COLUMN codecs.pps IS 'PPS represents the number of packets that need to be transmitted every second in order to deliver the codec bit rate. For example, for a G.729 call with voice payload size per packet of 20 bytes (160 bits), 50 packets need to be transmitted every second [50 pps = (8 Kbps) / (160 bits per packet) ]';
--http://www.cisco.com/en/US/tech/tk652/tk698/technologies_tech_note09186a0080094ae2.shtml
--COMMENT ON COLUMN codecs.mean_option_score IS 'Mean Opinion Score, a value derived from the R-Factor per ITU?T Recommendation G.10, measures VoIP call quality (see rfactor). Packeteer measures MOS using a scale of 10-50. To convert to a standard MOS score (which uses a scale of 1-5), divide the Packeteer MOS value by 10.';

COMMENT ON INDEX codecs$codec_number_bit_rate_uidx IS 
'Enforces uniqueness on Codec Number and Bit Rate.';

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE codecs FROM PUBLIC;
ALTER TABLE codecs OWNER TO metrics;
GRANT ALL ON TABLE codecs TO postgres;
GRANT SELECT ON TABLE codecs TO rptuser;

-- Seed data
INSERT INTO metrics.codecs VALUES
( 1, 'G.711a',      'ITU-T',     64,     0, 'PCM (Pulse Code Modulation), 64 Kbps, sample-based. Also known as A-law (European standard).'),
( 2, 'G.711u',      'ITU-T',     64,     0, 'PCM (Pulse Code Modulation), 64 Kbps, sample-based. Also known as U-law (US standard).'),
( 3, 'G.721(1988)', 'ITU-T',     32,     7, 'ADPCM (Adaptive Differential Pulse Code Modulation).'),
( 4, 'G.722',       'ITU-T',     48,  NULL, 'SBADPCM (Sub-Band Adaptive Differential Pulse Code Modulation), 7Khz audio bandwidth.'),
( 5, 'G.722',       'ITU-T',     56,  NULL, 'SBADPCM (Sub-Band Adaptive Differential Pulse Code Modulation), 7Khz audio bandwidth.'),
( 6, 'G.722',       'ITU-T',     64,  NULL, 'SBADPCM (Sub-Band Adaptive Differential Pulse Code Modulation), 7Khz audio bandwidth.'),
( 7, 'G.722.1',     'ITU-T',     24,  NULL, '24 Kbps 7Khz audio bandwidth (based on Polycom''s SIREN codec)'),
( 8, 'G.722.1',     'ITU-T',     32,  NULL, '32 Kbps 7Khz audio bandwidth (based on Polycom''s SIREN codec)'),
( 9, 'G.722.1C',    'ITU-T',     32,  NULL, '32 Kbps, a Polycom extension, 14Khz audio bandwidth.)'),
(10, 'G.722.2',     'ITU-T',    6.6,  NULL, '6.6Kbps to 23.85Kbps. Also known as AMR-WB. CELP 7Khz audio bandwidth.'),
(11, 'G.723.1',     'ITU-T',    5.3,    19, 'ACELP (Algebraic Code Excited Linear Prediction), Pass-thru only.'),
(12, 'G.723.1',     'ITU-T',    6.3,    15, 'MP-MLQ (Multi-rate Coder, 30ms frame size. Pass-thru only.'),
(13, 'G.726',       'ITU-T',     16,    50, 'ADPCM (Adaptive Differential Pulse Code Modulation).'),
(14, 'G.726',       'ITU-T',     24,    25, 'ADPCM (Adaptive Differential Pulse Code Modulation).'),
(15, 'G.726',       'ITU-T',     32,     7, 'ADPCM (Adaptive Differential Pulse Code Modulation).'),
(16, 'G.726',       'ITU-T',     40,     2, 'ADPCM (Adaptive Differential Pulse Code Modulation).'),
(17, 'G.727',       'ITU-T',     16,    50, 'Variable-Rate ADPCM.'),
(18, 'G.727',       'ITU-T',     24,    25, 'Variable-Rate ADPCM.'),
(19, 'G.727',       'ITU-T',     32,     7, 'Variable-Rate ADPCM.'),
(20, 'G.727',       'ITU-T',     40,     2, 'Variable-Rate ADPCM.'),
(21, 'G.728',       'ITU-T',   12.8,    20, 'LD-CELP (Low-Delay Code Excited Linear Prediction).'),
(22, 'G.728',       'ITU-T',     16,     7, 'LD-CELP (Low-Delay Code Excited Linear Prediction).'),
(23, 'G.729',       'ITU-T',      8,    10, 'CS-ACELP (Conjugate Structure Algebraic-Code Excited Linear Prediction).'),
(24, 'G.729A',      'ITU-T',      8,    11, 'CS-ACELP (Conjugate Structure Algebraic-Code Excited Linear Prediction).'),
(25, 'GIPS',        '',        13.3,  NULL, 'GIPS Family - 13.3 Kbps and up.'),
(26, 'GSM 06.10',   'ETSI',      13,    20, 'RPE-LTP (Regular Pulse Excitation Long-Term Prediction), Full Rate, 20ms frame size.'),
(27, 'GSM 06.20',   'ETSI',     5.6,    23, 'VSELP (Vector Sum Excited Linear Prediction), Half Rate.'),
(28, 'GSM 06.60',   'ETSI',    12.2,     5, 'ACELP (Algebraic Code Excited Linear Prediction), Enhanced Full Rate, 20ms frame size.'),
(29, 'Japanese PDC','',         6.7,    24, 'VSELP (Vector Sum Excited Linear Prediction).'),
(30, 'IS-54',       '',           8,    20, 'VSELP (Vector Sum Excited Linear Prediction).'),
(31, 'IS-641',      '',         7.4,     6, 'ACELP (Code Excited Linear Prediction).'),
(32, 'IS-96a',      '',           8,    19, 'QCELP (Code Excited Linear Prediction).'),
(33, 'IS-127',      '',           8,     6, 'RCELP (Code Excited Linear Prediction).'),
(34, 'GSM',         'ETSI',    11.4,  NULL, 'CELP-VSELP (Code Excited Linear Prediction - Vector Sum Excited Linear Prediction), Half Rate, 20ms frame size'),
(35, 'iLBC',        '',        13.3,  NULL, 'Internet Low Bitrate Codec, 30ms frame size.'),
(36, 'iLBC',        '',          15,  NULL, 'Internet Low Bitrate Codec, 20ms frame size.'),
(37, 'Speex',       '',        2.15,  NULL, 'CELP (Code Excited Linear Prediction), 2.15 to 44.2 Kbps'),
(38, 'LPC10',       'USA Gov.', 2.5,  NULL, ''),
(39, 'DoD CELP',    'American Department of Defense (DoD) USA Government', 4.8, NULL, 'CELP (Code Excited Linear Prediction).'),
(40, 'EVRC',        '3GPP2',     32,  NULL, 'Enhanced Variable Rate CODEC. Bit Rate 9.6/4.8/1.2'),
(41, 'DVI',         'Interactive Multimedia Association (IMA)', NULL,  NULL, 'DVI4 uses an adaptive delta pulse code modulation (ADPCM).'),
(42, 'L16',         '',         128,  NULL, 'Uncompressed audio data samples.');

-- =========================
-- Table "timezone_names"
-- =========================
CREATE TABLE timezone_names 
TABLESPACE :dc_data
AS 
  SELECT * 
    FROM pg_catalog.pg_timezone_names
;

-- Index
CREATE INDEX timezone_names$name_idx 
ON timezone_names (name) 
TABLESPACE :dc_index;

-- Privileges
REVOKE ALL PRIVILEGES ON TABLE timezone_names FROM PUBLIC;
ALTER TABLE timezone_names OWNER TO metrics;
GRANT ALL ON TABLE timezone_names TO postgres;
GRANT SELECT ON TABLE timezone_names TO rptuser;

-- ========================================================
--      Insert Seed Data into Dimension tables
-- ========================================================

SET datestyle = SQL;

-- ======
-- Links --------------------------------------------------
-- ======

INSERT INTO links (link_id, name, path) VALUES (1, 'Inbound', '/Inbound');
INSERT INTO links (link_id, name, path) VALUES (2, 'Outbound', '/Outbound');

-- Note: predefined link_id = 1, 2
ALTER SEQUENCE metrics.link_id_seq RESTART WITH 3;

-- ===========
-- Partitions ---------------------------------------------
-- ===========

INSERT INTO partitions (part_id, name, path, l_idx, r_idx, parent_id ) VALUES (0, 'Root', '/Root', 0, 0, NULL);
INSERT INTO partitions (part_id, name, path, l_idx, r_idx, parent_id ) VALUES (2, 'Inbound', '/Inbound', 0, 0, 0);
INSERT INTO partitions (part_id, name, path, l_idx, r_idx, parent_id ) VALUES (3, 'Outbound', '/Outbound', 0, 0, 0);

-- Note: predefined part_id = 0, 2, 3
ALTER SEQUENCE metrics.partition_id_seq RESTART WITH 4;

-- ========
-- Classes ------------------------------------------------
-- ========

COPY classes (path)
FROM './known_classes.lst'
CSV;

-- =========
-- Services -----------------------------------------------
-- =========

COPY services (ord_id, name)
FROM './services.lst'
WITH DELIMITER AS ',';

-- ==========
-- Protocols ----------------------------------------------
-- ==========

COPY protocols (protocol_id, name, descr)
FROM './protocols.lst'
WITH DELIMITER AS ',';

-- ==========
-- TCP Flags ----------------------------------------------
-- ==========

COPY tcp_flags (tcp_flag_id, descr)
FROM './tcp_flags.lst'
WITH DELIMITER AS ',';

-- ========
-- Periods ------------------------------------------------
-- ========

COPY metrics.periods (period_id, period_name, period_level, period_year, period_month, period_day, period_hour, period_min)
FROM './periods.lst'
WITH CSV;

-- ========
-- Metadata ------------------------------------------------
-- ========

COPY collection_vars (coll_type_id,ord_num,agg_num,is_variable,is_axis,var_name,col_name,db_type,db_size,db_condition,agg_condition,is_index,var_type,var_size,var_option,cb_function,is_standard,is_isp,is_turbo,descr)
FROM './collection_vars.lst'
WITH CSV 
NULL AS 'NULL';

-- ========================================================
--                    Rebuild Indexes
-- ========================================================

ANALYZE classes;

ANALYZE services;

ANALYZE protocols;

ANALYZE tcp_flags;

ANALYZE periods;
REINDEX INDEX periods$period_name_uidx;  -- Lock table 'periods' for I/U/D

-- It's possible but 3 times slower if Generate the Periods as
-- SELECT gen_periods_data ('metrics', now(), '2012-12-31 23:59:59-07');

--COPY interfaces (interface_id, name)
--FROM './interfaces.lst'
--WITH DELIMITER AS  ',';

\unset dc_data
\unset dc_index

-- Schema's Version
UPDATE metrics.components 
   SET version = '2.1.08.11.20' 
 WHERE name = 'metrics_schema';
