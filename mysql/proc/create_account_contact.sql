
-- call account.create_account_contact
-- (@err,0,2,'fname','lname','email@email.com','555-555-5555','415',1,@cid,'650650650','123-123-123');

DROP PROCEDURE IF EXISTS account.create_account_contact;

DELIMITER $$
CREATE PROCEDURE account.create_account_contact(OUT error_code INT,
                                                IN app_user_id_in BIGINT,
                                                IN account_id_in BIGINT, 
                                                IN first_name_in VARCHAR(45), 
                                                IN last_name_in VARCHAR(45), 
                                                IN email_address_in VARCHAR(100), 
                                                IN phone_in  VARCHAR(20), 
                                                IN phone_ext_in VARCHAR(10), 
                                                IN account_contact_type_id_in MEDIUMINT, 
                                                OUT account_contact_id_out BIGINT,
                                                IN alternate_phone_in VARCHAR(20),
                                                IN fax_in VARCHAR(20))
BEGIN

SET error_code=-2; 

INSERT INTO account.account_contact (
  account_contact_id, 
  account_id, 
  first_name, 
  last_name, 
  email_address, 
  phone, 
  phone_ext,
  alternate_phone,
  fax,
  account_contact_type_id, 
  STATUS, 
  modified_id, 
  created_dtm
)
VALUES (
  NULL, 
  account_id_in, 
  first_name_in, 
  last_name_in, 
  email_address_in, 
  phone_in, 
  phone_ext_in,
  alternate_phone_in,
  fax_in,
  account_contact_type_id_in, 
  1, 
  app_user_id_in, 
  CURRENT_TIMESTAMP()
);

SET account_contact_id_out = LAST_INSERT_ID();

SET error_code=0;
 
END$$
DELIMITER ;