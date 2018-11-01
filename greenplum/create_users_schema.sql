SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = users, pg_catalog;

DROP TABLE users.user_log;
DROP TABLE users."user";
DROP SCHEMA users;
SET default_with_oids = false;

CREATE SCHEMA users;

ALTER SCHEMA users OWNER TO gpadmin;

SET default_tablespace = '';

CREATE TABLE "user" (
  user_id        bigint NOT NULL,
  email_address  character varying(100) NOT NULL,
  login_name     character varying(100),
  password       character varying(128) NOT NULL,
  first_name     character varying(45) NOT NULL,
  last_name      character varying(45) NOT NULL,
  salutation     character varying(10),
  dob            date,
  locale         character varying(10) DEFAULT 'en-US'::character varying NOT NULL,
  status         integer NOT NULL,
  modified_id    bigint NOT NULL,
  modified_dtm   timestamp without time zone DEFAULT now() NOT NULL,
  created_dtm    timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL
)
DISTRIBUTED BY (user_id);
ALTER TABLE users."user" OWNER TO gpadmin;

CREATE TABLE user_log 
(
    user_log_id      bigint NOT NULL,
    user_id          bigint,
    email_address    character varying(100),
    login_name       character varying(100),
    password         character varying(128),
    first_name       character varying(45),
    last_name        character varying(45),
    salutation       character varying(10),
    dob              date,
    locale           character varying(10),
    status           integer,
    modified_id      bigint,
    modified_dtm     timestamp without time zone,
    created_dtm      timestamp without time zone,
    log_modified_dtm timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL
)
DISTRIBUTED BY (user_id);
ALTER TABLE users.user_log OWNER TO gpadmin;

REVOKE ALL ON SCHEMA users FROM PUBLIC;
REVOKE ALL ON SCHEMA users FROM gpadmin;
GRANT ALL ON SCHEMA users TO gpadmin;
GRANT ALL ON SCHEMA users TO admin;
