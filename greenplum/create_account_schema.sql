SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = account, pg_catalog;

DROP TABLE account.account_status;
DROP TABLE account.account_log;
DROP TABLE account.account;
DROP SCHEMA account;
SET default_with_oids = false;

CREATE SCHEMA account;

ALTER SCHEMA account OWNER TO gpadmin;

SET default_tablespace = '';

CREATE TABLE account 
(
  account_id          bigint NOT NULL,
  account_status      integer NOT NULL,
  account_name        character varying(45) NOT NULL,
  account_email_addr  character varying(100),
  account_web_domain  character varying(200),
  modified_id         bigint DEFAULT 0 NOT NULL,
  modified_dtm        timestamp without time zone DEFAULT now() NOT NULL,
  created_dtm         timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
  account_type_mask   integer NOT NULL,
  account_name_upper  character varying(45)
)
DISTRIBUTED BY (account_id);
ALTER TABLE account.account OWNER TO gpadmin;

CREATE TABLE account_log 
(
  account_log_id      bigint NOT NULL,
  account_id          bigint,
  account_status      integer,
  account_name        character varying(45),
  account_email_addr  character varying(100),
  account_web_domain  character varying(200),
  modified_id         bigint,
  modified_dtm        timestamp without time zone,
  created_dtm         timestamp without time zone,
  account_type_mask   integer NOT NULL,
  log_modified_dtm    timestamp without time zone DEFAULT now() NOT NULL
)
DISTRIBUTED BY (account_id);
ALTER TABLE account.account_log OWNER TO gpadmin;

CREATE TABLE account_status 
(
  account_status integer NOT NULL,
  description    character varying(20) NOT NULL
)
DISTRIBUTED BY (account_status);
ALTER TABLE account.account_status OWNER TO gpadmin;

REVOKE ALL ON SCHEMA account FROM PUBLIC;
REVOKE ALL ON SCHEMA account FROM gpadmin;
GRANT ALL ON SCHEMA account TO gpadmin;
GRANT ALL ON SCHEMA account TO admin;
