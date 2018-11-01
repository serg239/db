SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

CREATE SCHEMA IF NOT EXISTS 'account' 
DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

USE 'account' ;

-- -----------------------------------------------------
-- Table account.account_status
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_status 
(
  account_status_id  MEDIUMINT NOT NULL,
  description        VARCHAR(20) NOT NULL,
  PRIMARY KEY (account_status_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account 
(
  account_id          BIGINT NOT NULL AUTO_INCREMENT,
  account_status_id   MEDIUMINT NOT NULL,
  account_name        VARCHAR(45) NOT NULL,
  account_email_addr  VARCHAR(100) NULL,
  account_web_domain  VARCHAR(200) NULL,
  modified_by         BIGINT NOT NULL DEFAULT 0,
  modified_dtm        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm         TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  account_type_mask   MEDIUMINT NOT NULL,
  account_name_upper  VARCHAR(45) NULL,
  PRIMARY KEY (account_id),
  INDEX idx_account_email_addr (account_email_addr ASC),
  INDEX idx_account_modified_dtm (modified_dtm ASC),
  INDEX fk_account_account_status (account_status ASC),
  CONSTRAINT fk_account_account_status_id
    FOREIGN KEY (account_status_id)
    REFERENCES account.account_status(account_status_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_log 
(
  account_log_id     BIGINT NOT NULL AUTO_INCREMENT,
  account_id         BIGINT,
  account_status_id  MEDIUMINT,
  account_name       VARCHAR(45),
  account_email_addr VARCHAR(100),
  account_web_domain VARCHAR(200),
  modified_by        BIGINT,
  modified_dtm       TIMESTAMP,
  created_dtm        TIMESTAMP,
  account_type_mask  MEDIUMINT,
  log_modified_dtm   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (account_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_user
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_user 
(
  account_user_id       INT NOT NULL AUTO_INCREMENT,
  account_id            BIGINT NOT NULL,
  user_id               BIGINT NOT NULL,
  is_owner              CHAR(1) NOT NULL,
  token                 VARCHAR(200) NOT NULL,
  token_expiration_date DATETIME NOT NULL,
  ip_address            VARCHAR(20) NULL,
  account_user_status   MEDIUMINT NOT NULL,
  modified_by           BIGINT NOT NULL,
  modified_dtm          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm           TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_user_id),
  INDEX fk_account_user_user_id (user_id ASC),
  UNIQUE INDEX uidx_account_account_id_user_id (account_id ASC, user_id ASC),
  INDEX fk_account_user_account_id (account_id ASC),
  CONSTRAINT fk_account_user_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_user_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_user_log 
(
  account_user_log_id   BIGINT NOT NULL AUTO_INCREMENT,
  account_user_id       INT,
  account_id            BIGINT,
  user_id               BIGINT,
  is_owner              CHAR(1),
  token                 VARCHAR(200),
  token_expiration_date DATETIME,
  ip_address            VARCHAR(20),
  account_user_status   MEDIUMINT,
  modified_by           BIGINT,
  modified_dtm          TIMESTAMP,
  created_dtm           TIMESTAMP,
  log_modified_dtm      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (account_user_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_user_hist
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_user_hist 
(
  account_user_id       INT NOT NULL,
  account_id            BIGINT NULL,
  action_id             TINYINT(1) NULL, 
  user_id               BIGINT NULL,
  is_owner              CHAR(1) NULL,
  token                 VARCHAR(200) NULL,
  token_expiration_date DATETIME NULL,
  account_user_status   MEDIUMINT NULL,
  modified_by           BIGINT NULL,
  modified_dtm          TIMESTAMP NULL,
  created_dtm           TIMESTAMP NULL
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.attribute
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.attribute 
(
  attribute_id                 INT NOT NULL,
  attribute_name               VARCHAR(40) NOT NULL,
  attribute_short_description  VARCHAR(80) NOT NULL,
  attribute_long_description   VARCHAR(200) NOT NULL,
  attribute_type               MEDIUMINT NULL,
  attribute_db_datatype        VARCHAR(30) NOT NULL,
  attribute_java_datatype      VARCHAR(30) NOT NULL,
  attribute_validation_pattern VARCHAR(100) NULL,
  attribute_status             MEDIUMINT NOT NULL,
  modified_by                  BIGINT NOT NULL,
  modified_dtm                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                  TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  is_time_phased               TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (attribute_id),
  UNIQUE INDEX uidx_attribute_name (attribute_name ASC),
  UNIQUE INDEX uidx_attribute_short_description (attribute_short_description ASC),
  UNIQUE INDEX uidx_attribute_long_description (attribute_long_description ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_attribute_value
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_attribute_value 
(
  account_attribute_value_id         BIGINT NOT NULL AUTO_INCREMENT,
  account_id                         BIGINT NOT NULL,
  attribute_id                       INT NOT NULL,
  attribute_value                    VARCHAR(2500) NOT NULL,
  account_attribute_value_start_date DATETIME NOT NULL,
  account_attribute_value_end_date   DATETIME NULL DEFAULT NULL,
  account_attribute_value_status     MEDIUMINT NOT NULL,
  modified_by                        BIGINT NOT NULL,
  modified_dtm                       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                        TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_attribute_value_id),
  UNIQUE INDEX uidx_account_attribute_value (account_id ASC, attribute_id ASC, account_attribute_value_start_date ASC),
  INDEX fk_account_attribute_value_account_id (account_id ASC),
  CONSTRAINT fk_account_attribute_value_account_id
    FOREIGN KEY (account_id )
    REFERENCES account.account (account_id )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_account_attribute_value_attribute_id (attribute_id ASC),
  CONSTRAINT fk_account_attribute_value_attribute_id
    FOREIGN KEY (attribute_id)
    REFERENCES account.attribute(attribute_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_attribute_value_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_attribute_value_log 
(
  account_attribute_value_log_id      BIGINT NOT NULL AUTO_INCREMENT,
  account_attribute_value_id          BIGINT,
  account_id                          BIGINT,
  attribute_id                        INT,
  attribute_value                     VARCHAR(2500),
  account_attribute_value_start_date  DATETIME,
  account_attribute_value_end_date    DATETIME,
  account_attribute_value_status      MEDIUMINT,
  modified_by                         BIGINT,
  modified_dtm                        TIMESTAMP,
  created_dtm                         TIMESTAMP,
  account_type_mask                   MEDIUMINT,
  log_modified_dtm                    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (account_attribute_value_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_web_domain_ban
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_web_domain_ban 
(
  account_web_domain_ban_id     INT NOT NULL AUTO_INCREMENT,
  account_web_domain_ban_name   VARCHAR(200) NOT NULL,
  account_web_domain_ban_status MEDIUMINT(9) NOT NULL,
  modified_by                   BIGINT(20) NOT NULL,
  modified_dtm                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                   TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_web_domain_ban_id),
  UNIQUE INDEX uidx_account_web_domain_ban_name (account_web_domain_ban_name ASC) 
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.global_attribute
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.global_attribute 
(
  global_attribute_id                INT NOT NULL,
  global_attribute_name              VARCHAR(40) NOT NULL,
  global_attribute_short_description VARCHAR(80) NOT NULL,
  global_attribute_long_description  VARCHAR(200) NOT NULL,
  global_attribute_value    		 VARCHAR(200) NOT NULL,
  global_attribute_type     		 MEDIUMINT NOT NULL,
  global_attribute_db_datatype       VARCHAR(30) NOT NULL,
  global_attribute_java_datatype     VARCHAR(30) NOT NULL,
  global_attribute_status            MEDIUMINT NOT NULL,
  modified_by                        BIGINT NOT NULL,
  modified_dtm                       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                        TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (global_attribute_id),
  UNIQUE INDEX uidx_global_attribute_name (global_attribute_name ASC),
  UNIQUE INDEX uidx_global_attribute_short_description (global_attribute_short_description ASC),
  UNIQUE INDEX uidx_global_attribute_long_description (global_attribute_long_description ASC) 
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_message
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_message 
(
  account_message_id       BIGINT NOT NULL AUTO_INCREMENT,
  account_id               BIGINT NOT NULL,
  account_message_subject  VARCHAR(200) NOT NULL,
  account_message_body     TEXT NOT NULL,
  account_message_type     MEDIUMINT NOT NULL,
  account_message_status   MEDIUMINT NOT NULL,
  modified_by              BIGINT NOT NULL,
  modified_dtm             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_by               BIGINT NOT NULL,
  created_dtm              TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_message_id),
  INDEX fk_account_message_account_id (account_id ASC),
  CONSTRAINT fk_account_message_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_contact_type
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_contact_type 
(
  account_contact_type_id   MEDIUMINT NOT NULL,
  account_contact_type_desc VARCHAR(40) NOT NULL,
  PRIMARY KEY (account_contact_type_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_contact
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_contact 
(
  account_contact_id      BIGINT(20) NOT NULL AUTO_INCREMENT,
  account_contact_type_id MEDIUMINT NOT NULL,
  account_id              BIGINT NOT NULL,
  first_name              VARCHAR(45) DEFAULT NULL,
  last_name               VARCHAR(45) DEFAULT NULL,
  salutation              VARCHAR(10) DEFAULT NULL,
  email_address           VARCHAR(100) DEFAULT NULL,
  phone                   VARCHAR(20) DEFAULT NULL,
  phone_ext               VARCHAR(10) DEFAULT NULL,
  alternate_phone         VARCHAR(20),
  fax                     VARCHAR(20),
  status                  MEDIUMINT NOT NULL,
  modified_by             BIGINT(20) NOT NULL,
  modified_dtm            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm             TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_contact_id),
  INDEX fk_account_contact_account_id (account_id ASC),
  CONSTRAINT fk_account_contact_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_account_contact_account_contact_type_id (account_contact_type_id ASC),
  CONSTRAINT fk_account_contact_account_contact_type_id
    FOREIGN KEY (account_contact_type_id)
    REFERENCES account.account_contact_type(account_contact_type_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.address
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.address 
(
  address_id     BIGINT NOT NULL AUTO_INCREMENT,
  address_name   VARCHAR(100) NOT NULL,
  street_1       VARCHAR(100) NOT NULL,
  street_2       VARCHAR(100) DEFAULT NULL,
  street_3       VARCHAR(100) DEFAULT NULL,
  city           VARCHAR(100) NOT NULL,
  postal_code    VARCHAR(45)  NOT NULL,
  state_province VARCHAR(100) NOT NULL,
  country        VARCHAR(100) NOT NULL,
  address_status MEDIUMINT(9) NOT NULL,
  modified_by    BIGINT NOT NULL,
  modified_dtm   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm    TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  longitude      DECIMAL(10,6),
  latitude       DECIMAL(10,6),
  PRIMARY KEY (address_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_address_type_cd
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_address_type_cd
(
  address_type_cd    VARCHAR(3) NOT NULL,
  address_type_name  VARCHAR(45) NOT NULL,
  address_type_desc  VARCHAR(200) DEFAULT NULL,
  modified_dtm       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm        TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (address_type_cd)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_address
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_address 
(
  account_address_id            BIGINT NOT NULL AUTO_INCREMENT,
  account_id                    BIGINT NOT NULL,
  address_id                    BIGINT NOT NULL,
  account_address_type_cd       VARCHAR(3) NOT NULL,
  account_address_phone         VARCHAR(20) NULL,
  account_address_phone_ext     VARCHAR(10) NULL,
  account_address_fax           VARCHAR(20) NULL,
  account_address_email         VARCHAR(100) NULL,
  account_address_first_name    VARCHAR(100) NULL DEFAULT NULL,
  account_address_last_name     VARCHAR(100) NULL DEFAULT NULL,
  account_address_business_name VARCHAR(100) NULL DEFAULT NULL,
  account_address_status        MEDIUMINT NOT NULL,
  modified_by                   BIGINT NOT NULL,
  modified_dtm                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                   TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_address_id),
  INDEX fk_account_address_account_id (account_id ASC),
  CONSTRAINT fk_account_address_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account (account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_account_address_address_type_cd (account_address_type_cd ASC),
  CONSTRAINT fk_account_address_address_type_cd
    FOREIGN KEY (account_address_type_cd)
    REFERENCES account.account_address_type_cd(address_type_cd)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_account_address_address_id (address_id ASC),
  CONSTRAINT fk_account_address_address_id
    FOREIGN KEY (address_id)
    REFERENCES account.address (address_id )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_cc
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_cc 
(
  account_cc_id     BIGINT NOT NULL AUTO_INCREMENT,
  account_id        BIGINT NOT NULL,
  user_cc_id        BIGINT NOT NULL,
  account_cc_status MEDIUMINT NOT NULL,
  modified_by       BIGINT NOT NULL,
  modified_dtm      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm       TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_cc_id),
  UNIQUE INDEX uidx_account_cc_account_id_user_cc_id (account_id ASC, user_cc_id ASC),
  INDEX fk_account_cc_account_id (account_id ASC),
  CONSTRAINT fk_account_cc_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_cc_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_cc_log 
(
  account_cc_log_id  BIGINT NOT NULL AUTO_INCREMENT,
  account_cc_id      BIGINT,
  account_id         BIGINT,
  user_cc_id         BIGINT,
  account_cc_status  MEDIUMINT,
  modified_by        BIGINT,
  modified_dtm       TIMESTAMP,
  created_dtm        TIMESTAMP,
  log_modified_dtm   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (account_cc_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_ba
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_ba 
(
  account_ba_id     BIGINT NOT NULL AUTO_INCREMENT,
  account_id        BIGINT NOT NULL,
  user_ba_id        BIGINT NOT NULL,
  account_ba_status MEDIUMINT NOT NULL,
  modified_by       BIGINT NOT NULL,
  modified_dtm      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm       TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_ba_id),
  UNIQUE INDEX uidx_account_ba_account_id_user_ba_id (account_id ASC, user_ba_id ASC),
  INDEX fk_account_ba_account_id (account_id ASC),
  CONSTRAINT fk_account_ba_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_brand_ban
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_brand_ban 
(
  account_brand_ban_id     INT NOT NULL AUTO_INCREMENT,
  account_brand_ban_name   VARCHAR(254) NOT NULL,
  account_brand_ban_status MEDIUMINT NOT NULL,
  modified_by              BIGINT NOT NULL,
  modified_dtm             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm              TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_brand_ban_id),
  UNIQUE INDEX u_account_brand_ban_name (account_brand_ban_name ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.sudo_account
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.sudo_account 
(
  sudo_account_id    BIGINT NOT NULL AUTO_INCREMENT,
  account_name       VARCHAR(45) NOT NULL,
  account_status     MEDIUMINT NOT NULL DEFAULT 1,
  account_web_domain VARCHAR(200) NOT NULL,
  account_email_addr VARCHAR(100) NOT NULL,
  modified_by        BIGINT NOT NULL DEFAULT 0,
  modified_dtm       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm        TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (sudo_account_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_return_policy
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_return_policy 
(
  account_id     BIGINT NOT NULL,
  return_policy  TEXT NOT NULL,
  modified_by    BIGINT NOT NULL DEFAULT 0,
  modified_dtm   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm    TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_id),
  INDEX fk_account_return_policy_account_id (account_id ASC),
  CONSTRAINT fk_account_return_policy_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table account.shipping_type
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.shipping_type 
(
  shipping_type_id          INT NOT NULL,
  shipping_type_name        VARCHAR(45) NOT NULL,
  shipping_type_description VARCHAR(100) NOT NULL,
  shipping_type_status      TINYINT NOT NULL,
  modified_by               BIGINT NOT NULL,
  modified_dtm              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm               TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (shipping_type_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.shipping_surcharge_type
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.shipping_surcharge_type 
(
  shipping_surcharge_type_id          INT NOT NULL,
  shipping_surcharge_type_name        VARCHAR(45) NOT NULL,
  shipping_surcharge_type_description VARCHAR(100) NOT NULL,
  shipping_surcharge_type_status      TINYINT NOT NULL,
  modified_by                         BIGINT NOT NULL,
  modified_dtm TIMESTAMP              NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                         TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (shipping_surcharge_type_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_shipping_surcharge
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_shipping_surcharge 
(
  account_shipping_surcharge_id BIGINT NOT NULL AUTO_INCREMENT,
  account_id                    BIGINT NOT NULL,
  shipping_surcharge_standard   BIGINT NOT NULL,
  shipping_surcharge_expedited  BIGINT NOT NULL,
  shipping_surcharge_premium    BIGINT NOT NULL,
  shipping_surcharge_type_id    INT NOT NULL,
  shipping_surcharge_status     TINYINT NOT NULL,
  modified_by                   BIGINT NOT NULL,
  modified_dtm                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                   TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_shipping_surcharge_id),
  INDEX idx_account_shipping_surcharge_account_id (account_id ASC, shipping_surcharge_status ASC),
  INDEX fk_account_shipping_surcharge_type_id (shipping_surcharge_type_id ASC),
  CONSTRAINT fk_account_shipping_surcharge_type_id
    FOREIGN KEY (shipping_surcharge_type_id)
    REFERENCES account.shipping_surcharge_type(shipping_surcharge_type_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_shipping_rate
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_shipping_rate 
(
  account_shipping_rate_id BIGINT NOT NULL AUTO_INCREMENT,
  account_id               BIGINT NOT NULL,
  min_weight               DECIMAL(12,4) NOT NULL,
  max_weight               DECIMAL(12,4) NOT NULL,
  shipping_rate_standard   BIGINT NOT NULL,
  shipping_rate_expedited  BIGINT NOT NULL,
  shipping_rate_premium    BIGINT NOT NULL,
  shipping_type_id         INT NOT NULL,
  shipping_rate_status     TINYINT NOT NULL,
  modified_by              BIGINT NOT NULL,
  modified_dtm             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm              TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_shipping_rate_id),
  INDEX idx_account_shipping_rate_account_id (account_id ASC, shipping_rate_status ASC),
  INDEX fk_account_shipping_rate_shipping_type_id (shipping_type_id ASC),
  CONSTRAINT fk_account_shipping_rate_shipping_type_id
    FOREIGN KEY (shipping_type_id)
    REFERENCES account.shipping_type(shipping_type_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_type
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_type 
(
  store_type_id          INT NOT NULL,
  store_type_name        VARCHAR(45) NOT NULL,
  store_type_description VARCHAR(100) NOT NULL,
  store_type_status      MEDIUMINT NOT NULL,
  modified_by            BIGINT NOT NULL,
  modified_dtm           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm            TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (store_type_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store 
(
  store_id           BIGINT NOT NULL AUTO_INCREMENT,
  store_type_id      INT NOT NULL,
  store_name         VARCHAR(45) NOT NULL,
  operational_status MEDIUMINT NOT NULL DEFAULT 1,
  time_zone          VARCHAR(128) NOT NULL,
  modified_by        BIGINT NOT NULL,
  modified_dtm       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm        TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (store_id),
  INDEX fk_store_store_type_id (store_type_id ASC),
  CONSTRAINT fk_store_store_type_id
    FOREIGN KEY (store_type_id)
    REFERENCES account.store_type(store_type_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_log 
(
  store_log_id             BIGINT NOT NULL AUTO_INCREMENT,
  store_id                 BIGINT,
  account_id               BIGINT,
  external_store_id        VARCHAR(20),
  store_type_id            INT,
  store_name               VARCHAR(45),
  days_closed_mask         MEDIUMINT,
  service_start_time       TIME,
  service_end_time         TIME,
  operational_status       MEDIUMINT,
  store_operational_status MEDIUMINT,
  time_zone                VARCHAR(20),
  modified_by              BIGINT,
  modified_dtm             TIMESTAMP,
  created_dtm              TIMESTAMP,
  log_modified_dtm         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (store_log_id),
  INDEX i_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_contact
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_contact 
(
  store_contact_id     BIGINT NOT NULL AUTO_INCREMENT,
  store_id             BIGINT NOT NULL,
  account_contact_id   BIGINT(20) NOT NULL,
  store_contact_status MEDIUMINT NOT NULL,
  modified_by          BIGINT NOT NULL,
  modified_dtm         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm          TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (store_contact_id),
  INDEX fk_store_contact_store_id (store_id ASC),
  CONSTRAINT fk_store_contact_store_id
    FOREIGN KEY (store_id )
    REFERENCES account.store(store_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_store_contact_account_contact_id (account_contact_id ASC),
  CONSTRAINT fk_store_contact_account_contact_id
    FOREIGN KEY (account_contact_id)
    REFERENCES account.account_contact(account_contact_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_attribute_value
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_attribute_value 
(
  store_attribute_value_id   BIGINT NOT NULL AUTO_INCREMENT,
  account_id                 BIGINT NOT NULL,
  store_id                   BIGINT NOT NULL,
  attribute_id               INT NOT NULL,
  attribute_value            VARCHAR(2500) NOT NULL,
  attribute_value_start_date DATETIME NOT NULL,
  attribute_value_end_date   DATETIME NULL DEFAULT NULL,
  attribute_value_status     MEDIUMINT NOT NULL,
  modified_by                BIGINT NOT NULL,
  modified_dtm               TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (store_attribute_value_id),
  UNIQUE INDEX uidx_attribute_value_store_id_attribute_id_start_date (store_id ASC, attribute_id ASC, attribute_value_start_date ASC),
  INDEX fk_store_attribute_value_store_id (store_id ASC),
  CONSTRAINT fk_store_attribute_value_store_id
    FOREIGN KEY (store_id)
    REFERENCES account.store(store_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_store_attribute_value_account_id (account_id ASC),
  CONSTRAINT fk_store_attribute_value_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_store_attribute_value_attribute_id (attribute_id ASC),
  CONSTRAINT fk_store_attribute_value_attribute_id
    FOREIGN KEY (attribute_id)
    REFERENCES account.attribute(attribute_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_attribute_value_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_attribute_value_log 
(
  store_attribute_value_log_id BIGINT NOT NULL AUTO_INCREMENT,
  store_attribute_value_id     BIGINT,
  account_id                   BIGINT,
  store_id                     BIGINT,
  attribute_id                 INT,
  attribute_value              VARCHAR(2500),
  attribute_value_start_date   DATETIME,
  attribute_value_end_date     DATETIME,
  attribute_value_status       MEDIUMINT,
  modified_by                  BIGINT,
  modified_dtm                 TIMESTAMP,
  created_dtm                  TIMESTAMP,
  log_modified_dtm             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (store_attribute_value_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_address
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_address 
(
  store_address_id     BIGINT NOT NULL AUTO_INCREMENT,
  store_id             BIGINT NOT NULL,
  address_id           BIGINT NOT NULL,
  store_address_status MEDIUMINT NOT NULL,
  modified_by          BIGINT NOT NULL,
  modified_dtm         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm          TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (store_address_id),
  INDEX fk_store_address_store_id (store_id ASC),
  CONSTRAINT fk_store_address_store_id
    FOREIGN KEY (store_id)
    REFERENCES account.store(store_id) 
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_store_address_address_id (address_id ASC),
  CONSTRAINT fk_store_address_address_id
    FOREIGN KEY (address_id)
    REFERENCES account.address(address_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_address_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_address_log 
(
  store_address_log_id BIGINT NOT NULL AUTO_INCREMENT,
  store_address_id     BIGINT,
  store_id             BIGINT,
  address_id           BIGINT,
  store_address_status MEDIUMINT,
  modified_by          BIGINT,
  modified_dtm         TIMESTAMP,
  created_dtm          TIMESTAMP,
  log_modified_dtm     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (store_address_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC) 
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_contact_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_contact_log 
(
  store_contact_log_id BIGINT NOT NULL AUTO_INCREMENT,
  store_contact_id     BIGINT,
  store_id             BIGINT,
  account_contact_id   BIGINT(20),
  store_contact_status MEDIUMINT,
  modified_by          BIGINT,
  modified_dtm         TIMESTAMP,
  created_dtm          TIMESTAMP,
  log_modified_dtm     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (store_contact_log_id),
  INDEX i_log_modified_dtm (log_modified_dtm ASC) 
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_store
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_store 
(
  account_store_id     INT NOT NULL AUTO_INCREMENT,
  store_id             BIGINT NOT NULL,
  account_id           BIGINT NOT NULL,
  external_store_id    VARCHAR(20) NOT NULL,
  account_store_status TINYINT NOT NULL DEFAULT 1,
  modified_by          BIGINT NOT NULL,
  modified_dtm         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_dtm          TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_store_id),
  INDEX fk_account_store_store (store_id ASC),
  INDEX fk_account_store_account (account_id ASC),
  UNIQUE INDEX u_store_acc_id_ext_store_id (account_id ASC, external_store_id ASC) 
)
ENGINE = INNODB;

-- -----------------------------------------------------
-- Table account.account_store_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_store_log 
(
  account_store_log_id  INT NOT NULL AUTO_INCREMENT,
  account_store_id      INT DEFAULT NULL,
  store_id              BIGINT DEFAULT NULL,
  account_id            BIGINT DEFAULT NULL,
  external_store_id     VARCHAR(20),
  account_store_status  TINYINT DEFAULT NULL,
  modified_by           BIGINT DEFAULT NULL,
  modified_dtm          TIMESTAMP DEFAULT NULL,
  created_dtm           TIMESTAMP DEFAULT NULL,
  log_modified_dtm      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (account_store_log_id),
  INDEX i_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = INNODB;

-- -----------------------------------------------------
-- Table account.rule
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.rule 
(
  rule_id            INT NOT NULL AUTO_INCREMENT,
  rule_name          VARCHAR(45) NOT NULL,
  rule_description   VARCHAR(100) NOT NULL,
  rule_bit           BIGINT NOT NULL,
  operational_status MEDIUMINT NOT NULL DEFAULT 1,
  modified_by        BIGINT NOT NULL DEFAULT 0,
  created_dtm        TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  modified_dtm       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (rule_id),
  INDEX idx_rule_rule_bit (rule_bit ASC),
  UNIQUE INDEX uidx_rule_rule_name (rule_name ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.approval_status
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.approval_status 
(
  approval_status_id          INT NOT NULL,
  approval_status_name        VARCHAR(45) NOT NULL,
  approval_status_description VARCHAR(100) NOT NULL,
  operational_status          MEDIUMINT NOT NULL DEFAULT 1,
  modified_by                 BIGINT NOT NULL DEFAULT 0,
  created_dtm                 TIMESTAMP NOT NULL DEFAULT 0000-00-00 00:00:00,
  modified_dtm                TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (approval_status_id),
  UNIQUE INDEX u_approval_status_name (approval_status_name ASC) 
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_rule
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_rule 
(
  account_rule_approval_id  BIGINT NOT NULL AUTO_INCREMENT,
  account_id                BIGINT NOT NULL,
  approval_status_id        INT NOT NULL,
  rule_bit                  BIGINT NOT NULL,
  operational_status        MEDIUMINT NOT NULL DEFAULT 1,
  modified_by               BIGINT NOT NULL DEFAULT 0,
  created_dtm               TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  modified_dtm              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (account_rule_approval_id),
  UNIQUE INDEX uidx_account_rule_account_id_rule_bit (account_id ASC, rule_bit ASC),
  INDEX fk_account_rule_account_id (account_id ASC),
  CONSTRAINT fk_account_rule_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_account_rule_rule_bit (rule_bit ASC),
  CONSTRAINT fk_account_rule_rule_bit
    FOREIGN KEY (rule_bit)
    REFERENCES account.rule(rule_bit)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_account_rule_approval_status_id (approval_status_id ASC),
  CONSTRAINT fk_account_rule_approval_status_id
    FOREIGN KEY (approval_status_id)
    REFERENCES account.approval_status(approval_status_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_rule_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_rule_log 
(
  account_rule_log_id      BIGINT NOT NULL AUTO_INCREMENT,
  account_rule_approval_id BIGINT,
  account_id               BIGINT,
  approval_status_id       INT,
  rule_bit                 BIGINT,
  operational_status       MEDIUMINT,
  modified_by              BIGINT,
  created_dtm              TIMESTAMP,
  modified_dtm             TIMESTAMP,
  log_modified_dtm         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (account_rule_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_rule
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_rule 
(
  store_rule_approval_id  BIGINT NOT NULL AUTO_INCREMENT,
  store_id                BIGINT NOT NULL,
  approval_status_id      INT NOT NULL,
  rule_bit                BIGINT NOT NULL,
  operational_status      INT NOT NULL DEFAULT 1,
  modified_by             BIGINT NOT NULL DEFAULT 0,
  created_dtm             TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  modified_dtm            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (store_rule_approval_id),
  UNIQUE INDEX uidx_store_rule_store_id_rule_bit (store_id ASC, rule_bit ASC),
  INDEX fk_store_rule_store_id (store_id ASC),
  CONSTRAINT fk_store_rule_store_id
    FOREIGN KEY (store_id)
    REFERENCES account.store(store_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_store_rule_rule_bit (rule_bit ASC),
  CONSTRAINT fk_store_rule_rule_bit
    FOREIGN KEY (rule_bit)
    REFERENCES account.rule(rule_bit)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX fk_store_rule_approval_status_id (approval_status_id ASC),
  CONSTRAINT fk_store_rule_approval_status_id
    FOREIGN KEY (approval_status_id)
    REFERENCES account.approval_status(approval_status_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_rule_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_rule_log
(
  store_rule_log_id      BIGINT NOT NULL AUTO_INCREMENT,
  store_rule_approval_id BIGINT,
  store_id               BIGINT,
  approval_status_id     INT,
  rule_bit               BIGINT,
  operational_status     INT,
  modified_by            BIGINT,
  created_dtm            TIMESTAMP,
  modified_dtm           TIMESTAMP,
  log_modified_dtm       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (store_rule_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_operating_time
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_operating_time
(
  store_operating_time_id     BIGINT NOT NULL AUTO_INCREMENT,
  store_id                    BIGINT NOT NULL,
  day_of_week                 VARCHAR(9) NOT NULL,
  service_start_time          TIME NULL,
  service_end_time            TIME NULL,
  is_closed_day               TINYINT(1) NOT NULL DEFAULT 0,
  store_operating_time_status MEDIUMINT NOT NULL DEFAULT 1,
  modified_by                 BIGINT NOT NULL,
  modified_dtm                TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                 TIMESTAMP NOT NULL DEFAULT 0000-00-00 00:00:00,
  PRIMARY KEY (store_operating_time_id),
  UNIQUE INDEX uidx_store_operating_time_store_day_of_week (store_id ASC, day_of_week ASC),
  INDEX fk_store_operating_time_store_id (store_id ASC),
  CONSTRAINT fk_store_operating_time_store_id
    FOREIGN KEY (store_id)
    REFERENCES account.store(store_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_operating_time_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_operating_time_log 
(
  store_operating_time_log_id BIGINT NOT NULL AUTO_INCREMENT,
  store_operating_time_id     BIGINT,
  store_id                    BIGINT,
  day_of_week                 VARCHAR(9),
  service_start_time          TIME,
  service_end_time            TIME,
  is_closed_day               TINYINT(1),
  store_operating_time_status MEDIUMINT,
  modified_by                 BIGINT,
  modified_dtm                TIMESTAMP,
  created_dtm                 TIMESTAMP,
  log_modified_dtm            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (store_operating_time_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC) 
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_operating_time_override
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_operating_time_override 
(
  store_operating_time_override_id BIGINT NOT NULL AUTO_INCREMENT,
  store_id                         BIGINT NOT NULL,
  calendar_date                    DATE NOT NULL,
  service_start_time               TIME NULL,
  service_end_time                 TIME NULL,
  is_closed_day                    TINYINT(1) NOT NULL DEFAULT 0,
  store_operating_time_status      MEDIUMINT NOT NULL DEFAULT 1,
  modified_by                      BIGINT NOT NULL,
  modified_dtm                     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                      TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (store_operating_time_override_id),
  UNIQUE INDEX uidx_store_operating_hour_override_store_calendar_date (store_id ASC, calendar_date ASC),
  INDEX fk_store_operating_time_override_store_id (store_id ASC),
  CONSTRAINT fk_store_operating_time_override_store_id
    FOREIGN KEY (store_id)
    REFERENCES account.store(store_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.store_operating_time_override_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.store_operating_time_override_log 
(
  store_operating_time_override_log_id BIGINT NOT NULL AUTO_INCREMENT,
  store_operating_time_override_id     BIGINT,
  store_id                             BIGINT,
  calendar_date                        DATE,
  service_start_time                   TIME,
  service_end_time                     TIME,
  is_closed_day                        TINYINT(1),
  store_operating_time_status          MEDIUMINT,
  modified_by                          BIGINT,
  modified_dtm                         TIMESTAMP,
  created_dtm                          TIMESTAMP,
  log_modified_dtm                     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (store_operating_time_override_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC) 
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.day_of_week
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.day_of_week 
(
  day_of_week_id  INT NOT NULL,
  day_of_week     VARCHAR(10) NOT NULL,
  PRIMARY KEY (day_of_week_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.content_provider_lookup
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.content_provider_lookup (
  content_provider_lookup_id   MEDIUMINT NOT NULL,
  content_provider_name        VARCHAR(45) NOT NULL,
  content_provider_description VARCHAR(100) NOT NULL,
  status                       TINYINT NOT NULL DEFAULT 1,
  modified_by                  BIGINT NOT NULL,
  modified_dtm                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                  TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (content_provider_lookup_id),
  UNIQUE INDEX uidx_content_provider_name (content_provider_name ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_type_lookup
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_type_lookup 
(
  account_type_lookup_id    MEDIUMINT NOT NULL,
  account_type_code         VARCHAR(10) NOT NULL,
  account_type_description  VARCHAR(100) NOT NULL,
  account_type_status       TINYINT NOT NULL DEFAULT 1,
  account_type_bit          MEDIUMINT NOT NULL DEFAULT 0,
  modified_by               BIGINT NOT NULL,
  modified_dtm              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm               TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_type_lookup_id),
  UNIQUE INDEX uidx_account_type_lookup_account_type_code (account_type_code ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.fulfillment_type_lookup
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.fulfillment_type_lookup 
(
  fulfillment_type_lookup_id   MEDIUMINT NOT NULL,
  fulfillment_type_name        VARCHAR(40) NOT NULL,
  fulfillment_type_description VARCHAR(200) NOT NULL,
  fulfillment_type_mask        MEDIUMINT NOT NULL,
  fulfillment_type_status      MEDIUMINT NOT NULL,
  modified_by                  BIGINT NOT NULL DEFAULT 0,
  modified_dtm                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm                  TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (fulfillment_type_lookup_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_order_dun
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_order_dun 
(
  account_order_dun_id INT NOT NULL AUTO_INCREMENT,
  account_id           BIGINT NOT NULL,
  order_dun            VARCHAR(20) NOT NULL,
  store                VARCHAR(1) NOT NULL,
  modified_dtm         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm          TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (account_order_dun_id),
  INDEX idx_account_pay_duns_duns (order_dun ASC),
  INDEX fk_account_order_dun_account_id (account_id ASC),
  CONSTRAINT fk_account_order_dun_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.pay_duns
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.pay_duns 
(
  pay_duns_id    INT NOT NULL AUTO_INCREMENT,
  duns           BIGINT NOT NULL,
  account_name   VARCHAR(100) NOT NULL,
  modified_dtm   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm    VARCHAR(45) NOT NULL,
  PRIMARY KEY (pay_duns_id),
  UNIQUE INDEX uidx_pay_duns_duns (duns ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.order_duns
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.order_duns 
(
  order_duns_id   INT NOT NULL AUTO_INCREMENT,
  duns            BIGINT NOT NULL,
  order_duns      BIGINT NOT NULL,
  site_id         SMALLINT NOT NULL,
  vd_display      SMALLINT NOT NULL,
  modified_dtm    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm     TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (order_duns_id),
  UNIQUE INDEX uidx_order_duns_duns_order_duns (order_duns ASC, duns ASC),
  INDEX fk_order_duns_pay_duns (duns ASC),
  CONSTRAINT fk_order_duns_pay_duns
    FOREIGN KEY (duns )
    REFERENCES account.pay_duns (duns )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.vendor_account
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.vendor_account 
(
  vendor_account_id     BIGINT NOT NULL AUTO_INCREMENT,
  account_id            BIGINT NOT NULL,
  external_seller_id    BIGINT NULL,
  fulfillment_type_mask MEDIUMINT NOT NULL,
  parent_id             BIGINT NULL DEFAULT 0,
  vid                   CHAR(3) NULL DEFAULT NULL,
  description           VARCHAR(2500) NULL DEFAULT NULL,
  catalog_shard_index   TINYINT NOT NULL,
  sharding_status       TINYINT NOT NULL DEFAULT 0,
  oms_shard_index       TINYINT NOT NULL,
  channel_mask          MEDIUMINT NULL,
  remit_to_duns         BIGINT NULL,
  modified_by           BIGINT NOT NULL DEFAULT 0,
  modified_dtm          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm           TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (vendor_account_id),
  INDEX idx_account_parent_id (parent_id ASC),
  UNIQUE INDEX uidx_account_vid (vid ASC),
  INDEX idx_vendor_account_fullfillment_type_mask (fulfillment_type_mask ASC),
  INDEX idx_vendor_account_modified_dtm (modified_dtm ASC),
  UNIQUE INDEX uidx_account_remit_to_duns (remit_to_duns ASC),
  INDEX fk_vendor_account_account_id (account_id ASC),
  CONSTRAINT fk_vendor_account_account_id
    FOREIGN KEY (account_id )
    REFERENCES account.account (account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.vendor_account_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.vendor_account_log 
(
  vendor_account_log_id BIGINT NOT NULL AUTO_INCREMENT,
  vendor_account_id     BIGINT,
  account_id            BIGINT,
  external_seller_id    BIGINT,
  fulfillment_type_mask MEDIUMINT,
  parent_id             BIGINT,
  vid                   CHAR(3),
  description           VARCHAR(2500),
  catalog_shard_index   TINYINT,
  oms_shard_index       TINYINT,
  channel_mask          MEDIUMINT,
  remit_to_duns         BIGINT,
  modified_by           BIGINT,
  modified_dtm          TIMESTAMP,
  created_dtm           TIMESTAMP,
  log_modified_dtm      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (vendor_account_log_id),
  INDEX idx_log_modified_dtm (log_modified_dtm ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.shard_type
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.shard_type 
(
  shard_type_id          TINYINT(4) NOT NULL,
  shard_type_name        VARCHAR(45) NOT NULL,
  shard_type_description VARCHAR(100),
  shard_type_status      MEDIUMINT(9) NOT NULL DEFAULT 1,
  shard_type_bit_value   MEDIUMINT(9) NOT NULL DEFAULT 0,
  modified_by            BIGINT(20) NOT NULL DEFAULT 0,
  modified_dtm           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm            TIMESTAMP NOT NULL,
  PRIMARY KEY (shard_type_id),
  UNIQUE INDEX uidx_shard_type_name (shard_type_name ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.shard_type_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.shard_type_log 
(
  shard_type_log_id      BIGINT(20) NOT NULL AUTO_INCREMENT,
  shard_type_id          TINYINT(4),
  shard_type_name        VARCHAR(45),
  shard_type_description VARCHAR(100),
  shard_type_status      MEDIUMINT(9),
  shard_type_bit_value   MEDIUMINT NULL DEFAULT 0,
  modified_by            BIGINT(20),
  modified_dtm           TIMESTAMP,
  created_dtm            TIMESTAMP,
  log_modified_dtm       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (shard_type_log_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.shard
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.shard 
(
  shard_id             INT(11) NOT NULL AUTO_INCREMENT,
  shard_index          TINYINT(4) NOT NULL,
  shard_name           VARCHAR(45),
  shard_description    VARCHAR(100),
  db_host              VARCHAR(45) NOT NULL,
  db_port              VARCHAR(45) NOT NULL,
  shard_type_bit_value BIGINT(20) NOT NULL DEFAULT 0,
  shard_status         MEDIUMINT(9) NOT NULL DEFAULT 1,
  modified_by          BIGINT(20) NOT NULL DEFAULT 0,
  modified_dtm         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_dtm          TIMESTAMP,
  PRIMARY KEY (shard_id),
  UNIQUE INDEX u_shard_index (shard_index ASC)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.shard_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.shard_log 
(
  shard_log_id         BIGINT(20) NOT NULL AUTO_INCREMENT,
  shard_id             INT(11),
  shard_index          TINYINT(4),
  shard_name           VARCHAR(45),
  shard_description    VARCHAR(100),
  db_host              VARCHAR(45),
  db_port              VARCHAR(45),
  shard_type_bit_value BIGINT(20),
  shard_status         MEDIUMINT(9),
  modified_by          BIGINT(20),
  modified_dtm         TIMESTAMP,
  created_dtm          TIMESTAMP,
  log_modified_dtm     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (shard_log_id)
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_brand
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_brand 
(
  account_brand_id   BIGINT NOT NULL AUTO_INCREMENT,
  account_id         BIGINT NOT NULL,
  brand_id           BIGINT NOT NULL,
  status             TINYINT NOT NULL DEFAULT 1,
  created_dtm        TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
  modified_dtm       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  modified_by        BIGINT NOT NULL,
  PRIMARY KEY (account_brand_id),
  UNIQUE INDEX uidx_account_brand_account_id_brand_id (account_id ASC, brand_id ASC),
  INDEX fk_account_account_id (account_id ASC),
  CONSTRAINT fk_account_account_id
    FOREIGN KEY (account_id)
    REFERENCES account.account(account_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table account.account_brand_log
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS account.account_brand_log
(
  account_brand_log_id BIGINT NOT NULL AUTO_INCREMENT,
  account_brand_id     BIGINT NULL AUTO_INCREMENT,
  account_id           BIGINT,
  brand_id             BIGINT,
  status               TINYINT,
  created_dtm          TIMESTAMP,
  modified_dtm         TIMESTAMP,
  modified_by          BIGINT,
  log_created_dtm      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (account_brand_log_id)
)
ENGINE = InnoDB;

USE account;

DELIMITER $$
USE account$$
CREATE TRIGGER account.t_au_account_attribute 
AFTER UPDATE on account.account_attribute 
FOR EACH ROW 
BEGIN
INSERT INTO account.account_attribute_log
( 
  account_attribute_id
  ,account_id
  ,attribute_id
  ,attribute_value
  ,account_attribute_start_date
  ,account_attribute_end_date
  ,account_attribute_status
  ,modified_by
  ,modified_dtm
  ,created_dtm
)
VALUES
(
  old.account_attribute_id
  ,old.account_id
  ,old.attribute_id
  ,old.attribute_value 
  ,old.account_attribute_start_date
  ,old.account_attribute_end_date 
  ,old.account_attribute_status
  ,old.modified_by
  ,old.modified_dtm
  ,old.created_dtm 
);
END;$$

DELIMITER ;

DELIMITER $$
USE account$$
CREATE TRIGGER account.t_au_account_cc 
AFTER UPDATE on account.account_cc 
FOR EACH ROW BEGIN
INSERT INTO account.account_cc_log
(
  account_cc_id
  ,account_id
  ,user_cc_id
  ,account_cc_status 
  ,modified_by
  ,modified_dtm 
  ,created_dtm
)
VALUES
(
  old.account_cc_id
  ,old.account_id
  ,old.user_cc_id
  ,old.account_cc_status 
  ,old.modified_by
  ,old.modified_dtm 
  ,old.created_dtm 
);
END;$$

DELIMITER ;

DELIMITER $$
USE account$$
CREATE TRIGGER account.t_au_web_account 
AFTER UPDATE on account.web_account 
FOR EACH ROW 
BEGIN
INSERT INTO invoice.web_account_log
(
  account_id
  ,account_status
  ,account_name
  ,account_email_addr 
  ,account_web_domain
  ,modified_by
  ,modified_dtm
  ,created_dtm
  ,external_seller_id
  ,account_type_mask
  ,parent_id
  ,duns
  ,vid
  ,description 
)
VALUES
(
  old.account_id
  ,old.account_status
  ,old.account_name
  ,old.account_email_addr 
  ,old.account_web_domain
  ,old.modified_by 
  ,old.modified_dtm
  ,old.created_dtm
  ,old.external_seller_id
  ,old.account_type_mask
  ,old.parent_id
  ,old.duns
  ,old.vid
  ,old.description
);
END;$$


DELIMITER ;

DELIMITER $$
USE account$$
CREATE TRIGGER account.t_au_web_account 
AFTER UPDATE on account.web_account 
FOR EACH ROW 
BEGIN
INSERT INTO invoice.web_account_log
(
  account_id
  ,account_status
  ,account_name
  ,account_email_addr 
  ,account_web_domain
  ,modified_by 
  ,modified_dtm
  ,created_dtm
  ,external_seller_id
  ,account_type_mask
  ,parent_id
  ,duns
  ,vid
  ,description
)
VALUES
(
  old.account_id
  ,old.account_status
  ,old.account_name
  ,old.account_email_addr 
  ,old.account_web_domain
  ,old.modified_by 
  ,old.modified_dtm
  ,old.created_dtm
  ,old.external_seller_id
  ,old.account_type_mask
  ,old.parent_id
  ,old.duns
  ,old.vid
  ,old.description
);
END;$$

DELIMITER ;

DELIMITER $$
USE account$$
CREATE TRIGGER account.t_au_web_account 
AFTER UPDATE on account.web_account 
FOR EACH ROW 
BEGIN
INSERT INTO invoice.web_account_log
( 
  account_id
  ,account_status
  ,account_name
  ,account_email_addr 
  ,account_web_domain
  ,modified_by 
  ,modified_dtm
  ,created_dtm
  ,external_seller_id
  ,account_type_mask
  ,parent_id
  ,duns
  ,vid
  ,description
)
VALUES
(
  old.account_id
  ,old.account_status
  ,old.account_name
  ,old.account_email_addr 
  ,old.account_web_domain
  ,old.modified_by 
  ,old.modified_dtm
  ,old.created_dtm
  ,old.external_seller_id
  ,old.account_type_mask
  ,old.parent_id
  ,old.duns
  ,old.vid
  ,old.description
);
END;$$

DELIMITER ;

DELIMITER $$
USE account$$
CREATE TRIGGER account.t_au_web_account 
AFTER UPDATE on account.web_account 
FOR EACH ROW 
BEGIN
INSERT INTO invoice.web_account_log
( 
  account_id
  ,account_status
  ,account_name
  ,account_email_addr 
  ,account_web_domain
  ,modified_by 
  ,modified_dtm
  ,created_dtm
  ,external_seller_id
  ,account_type_mask
  ,parent_id
  ,duns
  ,vid
  ,description
)
VALUES
(
  old.account_id
  ,old.account_status
  ,old.account_name
  ,old.account_email_addr 
  ,old.account_web_domain
  ,old.modified_by 
  ,old.modified_dtm
  ,old.created_dtm
  ,old.external_seller_id
  ,old.account_type_mask
  ,old.parent_id
  ,old.duns
  ,old.vid
  ,old.description
);
END;$$

DELIMITER ;

DELIMITER $$
USE account$$
CREATE TRIGGER account.t_au_shard_type 
AFTER UPDATE ON account.shard_type 
FOR EACH ROW BEGIN
INSERT INTO account.shard_type_log 
(
  shard_type_id
  ,shard_type_name
  ,shard_type_description
  ,shard_type_status
  ,modified_by
  ,modified_dtm
  ,created_dtm
) 
VALUES 
(
  old.shard_type_id
  ,old.shard_type_name
  ,old.shard_type_description
  ,old.shard_type_status
  ,old.modified_by
  ,old.modified_dtm
  ,old.created_dtm
);
END;$$

DELIMITER ;

DELIMITER $$
USE account$$
CREATE TRIGGER account.t_au_shard 
AFTER UPDATE ON account.shard 
FOR EACH ROW BEGIN
INSERT INTO account.shard_log   
(
  shard_id
  ,shard_index
  ,shard_name
  ,shard_description
  ,db_port
  ,db_host
  ,shard_type_id
  ,shard_status
  ,modified_by
  ,modified_dtm
  ,created_dtm
  ,primary_indicator
)  
VALUES  
(
  old.shard_id
  ,old.shard_index
  ,old.shard_name
  ,old.shard_description
  ,old.db_port
  ,old.db_host
  ,old.shard_type_id
  ,old.shard_status
  ,old.modified_by
  ,old.modified_dtm
  ,old.created_dtm
  ,old.primary_indicator
); 

END;$$

DELIMITER ;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
