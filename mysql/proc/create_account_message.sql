
-- call account.create_account_message (@err, -1, 1, 'hello', 'hello account', 1, 1, @amid);

DROP PROCEDURE IF EXISTS account.create_account_message;

DELIMITER $$
CREATE PROCEDURE account.create_account_message(OUT error_code INT, 
                                                IN user_id_in BIGINT,
                                                IN account_id_in BIGINT,
                                                IN account_message_subject_in VARCHAR(200),
                                                IN account_message_body_in TEXT,
                                                IN account_message_type_in MEDIUMINT(9), 
                                                IN account_message_status_in MEDIUMINT(9),
                                                OUT account_message_id_out BIGINT)
BEGIN

SET error_code = -2;
 
INSERT INTO account.account_message (
  account_message_id, 
  account_id, 
  account_message_subject, 
  account_message_body, 
  account_message_type,
  account_message_status,
  modified_id,  
  created_id, 
  created_dtm
)
VALUES (
  NULL, 
  account_id_in, 
  account_message_subject_in, 
  account_message_body_in, 
  account_message_type_in,
  account_message_status_in, 
  user_id_in, 
  user_id_in,
  CURRENT_TIMESTAMP()
);

SET account_message_id_out = LAST_INSERT_ID();
 
SET error_code=0;

END$$
DELIMITER ;
