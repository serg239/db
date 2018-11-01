SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = static_content, pg_catalog;

DROP TABLE static_content.uom;
DROP TABLE static_content.store_hierarchy_line_type;
DROP TABLE static_content.store;
DROP TABLE static_content.site;
DROP TABLE static_content.shc_status_lookup;
DROP TABLE static_content.shc_hier_hardline_softline_map;
DROP TABLE static_content.regex_lookup;
DROP TABLE static_content.lookup_type;
DROP TABLE static_content.lookup;
DROP TABLE static_content.item_relation_type;
DROP TABLE static_content.ima_uom_lookup;
DROP TABLE static_content.ima_store_hierarchy_to_uom;
DROP TABLE static_content.file_type;
DROP TABLE static_content.file_process_status;
DROP TABLE static_content.file_error_code_lookup;
DROP TABLE static_content.ban_type_config;
DROP TABLE static_content.ban_type;
DROP TABLE static_content.attribute_type;
DROP TABLE static_content.attribute_entry_type;
DROP TABLE static_content.asset_type;
DROP TABLE static_content.asset_format;
DROP TABLE static_content.allocation_lookup;
DROP SCHEMA static_content;
SET default_with_oids = false;

CREATE SCHEMA static_content;

ALTER SCHEMA static_content OWNER TO gpadmin;

SET default_tablespace = '';

CREATE TABLE allocation_lookup 
(
    allocation_lookup_id smallint NOT NULL,
    allocation_lookup_name character varying(128) NOT NULL,
    bit_value integer NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (allocation_lookup_id);
ALTER TABLE static_content.allocation_lookup OWNER TO gpadmin;

CREATE TABLE asset_format 
(
    asset_format_id smallint NOT NULL,
    asset_format_name character varying(128) NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (asset_format_id);
ALTER TABLE static_content.asset_format OWNER TO gpadmin;

CREATE TABLE asset_type 
(
    asset_type_id smallint NOT NULL,
    asset_type_name character varying(128) NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (asset_type_id);
ALTER TABLE static_content.asset_type OWNER TO gpadmin;

CREATE TABLE attribute_entry_type 
(
    attribute_entry_type_id smallint NOT NULL,
    attribute_entry_type_name character varying(40) NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (attribute_entry_type_id);
ALTER TABLE static_content.attribute_entry_type OWNER TO gpadmin;

CREATE TABLE attribute_type 
(
    attribute_type_id smallint NOT NULL,
    attribute_type_name character varying(40) NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (attribute_type_id);
ALTER TABLE static_content.attribute_type OWNER TO gpadmin;

CREATE TABLE ban_type 
(
    ban_type_id bigint NOT NULL,
    description character varying(100) NOT NULL,
    shc_status_bit bigint NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint DEFAULT 0 NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL
)
DISTRIBUTED BY (ban_type_id);
ALTER TABLE static_content.ban_type OWNER TO gpadmin;

CREATE TABLE ban_type_config 
(
    ban_type_config_id bigint NOT NULL,
    ban_type_id bigint NOT NULL,
    ban_term_id bigint NOT NULL,
    multivalue_flag smallint NOT NULL,
    operation_indicator character varying(30) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint DEFAULT 0 NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone
)
DISTRIBUTED BY (ban_type_config_id);
ALTER TABLE static_content.ban_type_config OWNER TO gpadmin;

CREATE TABLE file_error_code_lookup 
(
    file_error_code_lookup_id integer NOT NULL,
    file_error_code character varying(45) NOT NULL,
    file_error_code_description character varying(100) NOT NULL,
    file_error_display_value character varying(200) DEFAULT ' '::character varying NOT NULL,
    file_error_type character varying(10) NOT NULL,
    file_error_direction character varying(255) NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    CONSTRAINT file_error_code_lookup_file_error_direction_check 
      CHECK (((file_error_direction)::text = 
        ANY ((ARRAY['I'::character varying, 
                    'O'::character varying])::text[])))
)
DISTRIBUTED BY (file_error_code_lookup_id);
ALTER TABLE static_content.file_error_code_lookup OWNER TO gpadmin;

CREATE TABLE file_process_status 
(
    file_process_status_id smallint NOT NULL,
    file_process_status_code character varying(20) NOT NULL,
    file_process_status_description character varying(100) NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL
)
DISTRIBUTED BY (file_process_status_id);
ALTER TABLE static_content.file_process_status OWNER TO gpadmin;

CREATE TABLE file_type 
(
    file_type_id smallint NOT NULL,
    file_type_name character varying(45) NOT NULL,
    file_type_description character varying(100) NOT NULL,
    created_dtm timestamp without time zone DEFAULT now() NOT NULL,
    publish_flag smallint NOT NULL
)
DISTRIBUTED BY (file_type_id);
ALTER TABLE static_content.file_type OWNER TO gpadmin;

CREATE TABLE ima_store_hierarchy_to_uom 
(
    store_hierarchy_to_uom_id bigint NOT NULL,
    hierarchy_id bigint NOT NULL,
    external_hierarchy_id_path character varying(128) NOT NULL,
    uom_lookup_id bigint NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint DEFAULT 1 NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (store_hierarchy_to_uom_id);
ALTER TABLE static_content.ima_store_hierarchy_to_uom OWNER TO gpadmin;

CREATE TABLE ima_uom_lookup 
(
    uom_lookup_id bigint NOT NULL,
    uom_code character varying(50) NOT NULL,
    uom_code_lower character varying(50) NOT NULL,
    uom_code_description character varying(254) NOT NULL,
    uom_value_regex character varying(500),
    status smallint DEFAULT 1 NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    modified_id bigint DEFAULT 1 NOT NULL
)
DISTRIBUTED BY (uom_lookup_id);
ALTER TABLE static_content.ima_uom_lookup OWNER TO gpadmin;

CREATE TABLE item_relation_type 
(
    item_relation_type_id smallint NOT NULL,
    item_relation_type_name character varying(128) NOT NULL,
    bit_value integer NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint NOT NULL
)
DISTRIBUTED BY (item_relation_type_id);
ALTER TABLE static_content.item_relation_type OWNER TO gpadmin;

CREATE TABLE lookup 
(
    lookup_id smallint NOT NULL,
    lookup_value character varying(128) NOT NULL,
    lookup_description character varying(254) NOT NULL,
    bit_value integer,
    lookup_type_id smallint NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (lookup_id);
ALTER TABLE static_content.lookup OWNER TO gpadmin;

CREATE TABLE lookup_type 
(
    lookup_type_id smallint NOT NULL,
    lookup_type_name character varying(40) NOT NULL,
    lookup_type_description character varying(254) NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (lookup_type_id);
ALTER TABLE static_content.lookup_type OWNER TO gpadmin;

CREATE TABLE regex_lookup 
(
    regex_id smallint NOT NULL,
    regex_type character varying(128) NOT NULL,
    regex_pattern character varying(500) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    modified_id bigint NOT NULL
)
DISTRIBUTED BY (regex_id);
ALTER TABLE static_content.regex_lookup OWNER TO gpadmin;

CREATE TABLE shc_hier_hardline_softline_map 
(
    shc_hier_hardline_softline_map_id bigint NOT NULL,
    shc_division_nbr character varying(14) NOT NULL,
    store_hierarchy_line_type_id smallint DEFAULT 4 NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (shc_hier_hardline_softline_map_id);
ALTER TABLE static_content.shc_hier_hardline_softline_map OWNER TO gpadmin;

CREATE TABLE shc_status_lookup 
(
    shc_status_bit bigint NOT NULL,
    shc_status_description character varying(512) NOT NULL,
    shc_action_type character varying(45) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL
)
DISTRIBUTED BY (shc_status_bit);
ALTER TABLE static_content.shc_status_lookup OWNER TO gpadmin;

CREATE TABLE site 
(
    site_id smallint NOT NULL,
    site_name character varying(128) NOT NULL,
    bit_value integer NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (site_id);
ALTER TABLE static_content.site OWNER TO gpadmin;

CREATE TABLE store 
(
    store_id smallint NOT NULL,
    store_name character varying(32) NOT NULL,
    bit_mask smallint NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
) 
DISTRIBUTED BY (store_id);
ALTER TABLE static_content.store OWNER TO gpadmin;

CREATE TABLE store_hierarchy_line_type 
(
    store_hierarchy_line_type_id smallint NOT NULL,
    store_hierarchy_line_type_name character varying(32) NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (store_hierarchy_line_type_id);
ALTER TABLE static_content.store_hierarchy_line_type OWNER TO gpadmin;

CREATE TABLE uom 
(
    uom_id bigint NOT NULL,
    uom_name character varying(128) NOT NULL,
    uom_abbr character varying(50) NOT NULL,
    ima_uom_abbr character varying(50),
    uom_type character varying(255) DEFAULT 'ENGLISH'::character varying NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    modified_id bigint NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    CONSTRAINT uom_uom_type_check 
      CHECK (((uom_type)::text =
        ANY ((ARRAY['ENGLISH'::character varying, 
                    'METRIC'::character varying])::text[])))
)
DISTRIBUTED BY (uom_id);
ALTER TABLE static_content.uom OWNER TO gpadmin;

REVOKE ALL ON SCHEMA static_content FROM PUBLIC;
REVOKE ALL ON SCHEMA static_content FROM gpadmin;
GRANT ALL ON SCHEMA static_content TO gpadmin;
GRANT ALL ON SCHEMA static_content TO admin;
