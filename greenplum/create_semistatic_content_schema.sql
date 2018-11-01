SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = semistatic_content, pg_catalog;

DROP TABLE semistatic_content.value_trademark;
DROP TABLE semistatic_content.value;
DROP TABLE semistatic_content.trademark;
DROP TABLE semistatic_content.store_hierarchy;
DROP TABLE semistatic_content.profile_value;
DROP TABLE semistatic_content.profile_rule_output;
DROP TABLE semistatic_content.profile_class_lookup;
DROP TABLE semistatic_content.profile;
DROP TABLE semistatic_content.metadata_asset;
DROP TABLE semistatic_content.hierarchy;
DROP TABLE semistatic_content.content_item_class_hierarchy;
DROP TABLE semistatic_content.content_item_class_attribute;
DROP TABLE semistatic_content.content_item_class;
DROP TABLE semistatic_content.brand;
DROP TABLE semistatic_content.ban_term;
DROP TABLE semistatic_content.attribute_value;
DROP TABLE semistatic_content.attribute_label_group;
DROP TABLE semistatic_content.attribute;
DROP SCHEMA semistatic_content;
SET default_with_oids = false;

CREATE SCHEMA semistatic_content;

ALTER SCHEMA semistatic_content OWNER TO gpadmin;

SET default_tablespace = '';

CREATE TABLE attribute 
(
    attribute_id bigint NOT NULL,
    attribute_name character varying(128) NOT NULL,
    attribute_name_lower character varying(128),
    attribute_display_name character varying(128) NOT NULL,
    attribute_display_name_lower character varying(128),
    status smallint DEFAULT 1 NOT NULL,
    min_value integer,
    max_value integer,
    modified_id bigint NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    attribute_type_id smallint NOT NULL,
    attribute_entry_type_id smallint NOT NULL,
    uom_id bigint,
    global_flag smallint,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL,
    tool_tip character varying(1000),
    regex_format character varying(1000),
    attribute_data_type character varying(50),
    description character varying(2000)
)
DISTRIBUTED BY (attribute_id);
ALTER TABLE semistatic_content.attribute OWNER TO gpadmin;


CREATE TABLE attribute_label_group (
    attribute_label_group_id smallint NOT NULL,
    attribute_label_group_name character varying(40) NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL,
    rank character varying(254) DEFAULT '1'::character varying,
    attribute_label_group_name_lower character varying(40) NOT NULL
)
DISTRIBUTED BY (attribute_label_group_id);
ALTER TABLE semistatic_content.attribute_label_group OWNER TO gpadmin;

CREATE TABLE attribute_value 
(
    attribute_value_id bigint NOT NULL,
    attribute_id bigint NOT NULL,
    value_id bigint NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    modified_id bigint NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    rank integer NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL
) DISTRIBUTED BY (attribute_value_id);


ALTER TABLE semistatic_content.attribute_value OWNER TO gpadmin;

CREATE TABLE ban_term 
(
    ban_term_id bigint NOT NULL,
    column_name character varying(45) NOT NULL,
    table_name character varying(45) NOT NULL,
    schema_name character varying(45) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint DEFAULT 0 NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL
)
DISTRIBUTED BY (ban_term_id);
ALTER TABLE semistatic_content.ban_term OWNER TO gpadmin;

CREATE TABLE brand 
(
    brand_id bigint NOT NULL,
    brand_name character varying(128) NOT NULL,
    brand_name_lower character varying(128),
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint NOT NULL,
    logo_asset_id bigint,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL,
    excluded_site_mask bigint DEFAULT 0 NOT NULL
)
DISTRIBUTED BY (brand_id);
ALTER TABLE semistatic_content.brand OWNER TO gpadmin;

CREATE TABLE content_item_class 
(
    content_item_class_id bigint NOT NULL,
    content_item_class_name character varying(128) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_id bigint NOT NULL,
    default_content_provider_id bigint,
    parent_content_item_class_id bigint,
    description character varying(2000),
    content_item_class_id_path character varying(254) NOT NULL,
    content_item_class_display_path character varying(2000) NOT NULL,
    content_item_class_type character varying(255) DEFAULT 'REGULAR'::character varying NOT NULL,
    image_required_flag smallint DEFAULT 0 NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL,
    content_item_class_name_lower character varying(128) NOT NULL,
    CONSTRAINT content_item_class_content_item_class_type_check 
      CHECK (((content_item_class_type)::text = 
        ANY ((ARRAY['REGULAR'::character varying, 
                    'SERVICE'::character varying, 
                    'APPLIANCE'::character varying, 
                    'COLLECTION'::character varying
                   ])::text[])))
)
DISTRIBUTED BY (content_item_class_id);
ALTER TABLE semistatic_content.content_item_class OWNER TO gpadmin;

CREATE TABLE content_item_class_attribute 
(
    content_item_class_attribute_id bigint NOT NULL,
    content_item_class_id bigint NOT NULL,
    attribute_id bigint NOT NULL,
    rank integer NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    modified_id bigint NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    required_flag character varying(1) NOT NULL,
    attribute_label_group_id smallint,
    attribute_variation_type smallint DEFAULT 0 NOT NULL,
    web_type_mask integer DEFAULT 4 NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL
)
DISTRIBUTED BY (content_item_class_attribute_id);
ALTER TABLE semistatic_content.content_item_class_attribute OWNER TO gpadmin;

CREATE TABLE content_item_class_hierarchy 
(
    content_item_class_hierarchy_id bigint NOT NULL,
    content_item_class_id bigint NOT NULL,
    hierarchy_id bigint NOT NULL,
    is_primary_flag smallint DEFAULT 0 NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    modified_id bigint NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL
)
DISTRIBUTED BY (content_item_class_hierarchy_id);
ALTER TABLE semistatic_content.content_item_class_hierarchy OWNER TO gpadmin;

CREATE TABLE hierarchy 
(
    hierarchy_id bigint NOT NULL,
    hierarchy_name character varying(128) NOT NULL,
    hierarchy_name_lower character varying(128),
    site_id smallint NOT NULL,
    parent_hierarchy_id bigint,
    description character varying(2000),
    hierarchy_display_path character varying(2000) NOT NULL,
    hierarchy_id_path character varying(254) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    shelf_flag character(1) NOT NULL,
    rank smallint NOT NULL,
    start_dtm timestamp without time zone,
    end_dtm timestamp without time zone,
    comments character varying(255),
    modified_id bigint NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL
)
DISTRIBUTED BY (hierarchy_id);
ALTER TABLE semistatic_content.hierarchy OWNER TO gpadmin;

CREATE TABLE metadata_asset 
(
    metadata_asset_id bigint NOT NULL,
    metadata_asset_type_id smallint NOT NULL,
    metadata_asset_name character varying(254),
    metadata_asset_description text,
    metadata_asset_path character varying(800),
    metadata_asset_image_height smallint,
    metadata_asset_image_width smallint,
    metadata_asset_format character varying(15),
    metadata_asset_original_path character varying(1000) NOT NULL,
    metadata_asset_transfer_status smallint NOT NULL,
    metadata_asset_transfer_msg text,
    metadata_asset_provider_id bigint NOT NULL,
    status smallint NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    metadata_asset_publish_dtm timestamp without time zone,
    modified_id bigint NOT NULL
)
DISTRIBUTED BY (metadata_asset_id);
ALTER TABLE semistatic_content.metadata_asset OWNER TO gpadmin;

CREATE TABLE profile 
(
    profile_id bigint NOT NULL,
    profile_name character varying(40) NOT NULL,
    profile_class character varying(45) NOT NULL,
    profile_type character varying(45) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL
)
DISTRIBUTED BY (profile_id);
ALTER TABLE semistatic_content.profile OWNER TO gpadmin;

CREATE TABLE profile_class_lookup 
(
    profile_class character varying(45) NOT NULL,
    profile_class_description character varying(128) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL
)
DISTRIBUTED BY (profile_class);
ALTER TABLE semistatic_content.profile_class_lookup OWNER TO gpadmin;

CREATE TABLE profile_rule_output 
(
    profile_rule_output_id bigint NOT NULL,
    profile_id bigint NOT NULL,
    attribute_name character varying(45) NOT NULL,
    attribute_value character varying(45) NOT NULL,
    rank smallint NOT NULL,
    description character varying(127)
)
DISTRIBUTED BY (profile_rule_output_id);
ALTER TABLE semistatic_content.profile_rule_output OWNER TO gpadmin;

CREATE TABLE profile_value 
(
    profile_value_id bigint NOT NULL,
    profile_id bigint NOT NULL,
    profile_term_type character varying(45) NOT NULL,
    profile_term_value character varying(100) NOT NULL,
    operation_indicator character varying(30) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL,
    logical_operator character varying(30)
)
DISTRIBUTED BY (profile_value_id);
ALTER TABLE semistatic_content.profile_value OWNER TO gpadmin;

CREATE TABLE store_hierarchy 
(
    store_hierarchy_id bigint NOT NULL,
    store_hierarchy_name character varying(128) NOT NULL,
    store_hierarchy_name_lower character varying(128),
    store_id smallint NOT NULL,
    parent_store_hierarchy_id bigint,
    external_hierarchy_id character varying(128) NOT NULL,
    store_hierarchy_display_path character varying(2000) NOT NULL,
    store_hierarchy_id_path character varying(254) NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    external_hierarchy_id_path character varying(128) NOT NULL,
    store_hierarchy_line_type_id smallint DEFAULT 4 NOT NULL
)
DISTRIBUTED BY (store_hierarchy_id);
ALTER TABLE semistatic_content.store_hierarchy OWNER TO gpadmin;

CREATE TABLE trademark 
(
    trademark_id bigint NOT NULL,
    trademark_name character varying(128) NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    modified_id bigint NOT NULL,
    tool_tip character varying(1000)
)
DISTRIBUTED BY (trademark_id);
ALTER TABLE semistatic_content.trademark OWNER TO gpadmin;

CREATE TABLE value
(
    value_id bigint NOT NULL,
    value_name character varying(128) NOT NULL,
    value_name_lower character varying(128),
    tool_tip character varying(1000),
    status smallint DEFAULT 1 NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    modified_id bigint NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL
)
DISTRIBUTED BY (value_id);
ALTER TABLE semistatic_content.value OWNER TO gpadmin;

CREATE TABLE value_trademark 
(
    value_trademark_id bigint NOT NULL,
    value_id bigint NOT NULL,
    trademark_id bigint NOT NULL,
    created_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    modified_dtm timestamp without time zone DEFAULT now() NOT NULL,
    modified_id bigint NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    version_number bigint DEFAULT 1 NOT NULL,
    version_count bigint DEFAULT 1 NOT NULL
)
DISTRIBUTED BY (value_trademark_id);
ALTER TABLE semistatic_content.value_trademark OWNER TO gpadmin;

REVOKE ALL ON SCHEMA semistatic_content FROM PUBLIC;
REVOKE ALL ON SCHEMA semistatic_content FROM gpadmin;
GRANT ALL ON SCHEMA semistatic_content TO gpadmin;
GRANT ALL ON SCHEMA semistatic_content TO admin;
