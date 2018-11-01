
-- call account.create_account_address(
-- @err,0,2,'in_address_name','in_street_1','in_street_2','in_street_3','in_city','in_postal_code',
-- 'in_state_province','in_country','WH','415-555-5555','123','415-555-5550', '1@somemail.com','in_adress_first_name',
-- 'in_address_last_name','in_address_business_name',@oaid,@oaaid,32.95,83.56);

DROP PROCEDURE IF EXISTS account.create_account_address;

DELIMITER $$

CREATE PROCEDURE account.create_account_address
(
   OUT error_code INT,
    IN in_app_user_id BIGINT,
    IN in_account_id BIGINT,
    IN in_address_name VARCHAR(100),
    IN in_street_1 VARCHAR(100),
    IN in_street_2 VARCHAR(100),
    IN in_street_3 VARCHAR(100),
    IN in_city VARCHAR(100),
    IN in_postal_code VARCHAR(45),
    IN in_state_province VARCHAR(100),
    IN in_country VARCHAR(100),
    IN in_address_type_cd VARCHAR(3),
    IN in_address_phone VARCHAR(20),
    IN in_address_phone_ext VARCHAR(10),
    IN in_account_address_fax VARCHAR(20),
    IN in_account_address_email VARCHAR(100),
    IN in_adress_first_name VARCHAR(45),
    IN in_address_last_name VARCHAR(45),
    IN in_address_business_name VARCHAR(100),
   OUT out_address_id INT,
   OUT out_account_address_id INT,
    IN in_longitude DECIMAL(10,6),
    IN in_latitude DECIMAL(10,6)
)
  BEGIN
   
  SET error_code=-2; 
   
  INSERT INTO account.address (
    address_name,
    street_1,
    street_2,
    street_3,
    city,
    postal_code,
    state_province,
    country,
    address_status,
    modified_id,
    created_dtm,
    longitude,
    latitude
  )
  VALUES (
    in_address_name,
    in_street_1,
    in_street_2,
    in_street_3,
    in_city,
    in_postal_code,
    in_state_province,
    in_country,
    1,
    in_app_user_id,
    CURRENT_TIMESTAMP(),
    in_longitude,
    in_latitude
  );

  SET out_address_id = LAST_INSERT_ID();

  INSERT INTO account.account_address (
    account_id,
    address_id,
    account_address_type_cd,
    account_address_phone,
    account_address_phone_ext,
    account_address_fax,
    account_address_email,
    account_address_first_name,
    account_address_last_name,
    account_address_business_name,
    account_address_status,
    modified_id,
    created_dtm
  )
  VALUES (
    in_account_id,
    out_address_id,
    in_address_type_cd,
    in_address_phone,
    in_address_phone_ext,
    in_account_address_fax,
    in_account_address_email,
    in_adress_first_name,
    in_address_last_name,
    in_address_business_name,
    1,
    in_app_user_id,
    CURRENT_TIMESTAMP()
  );

  SET out_account_address_id = LAST_INSERT_ID();

  SET error_code = 0; 

  END$$

DELIMITER ;