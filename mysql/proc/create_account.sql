
-- call account.create_account (@err, 123, 'account_name_in1345', 'account_web_domain_in23', 'account_email_addr_in12', 1, 1,123456789,'125','seller-description_in', @aid,1);

DROP PROCEDURE IF EXISTS account.create_account;

DELIMITER $$
CREATE PROCEDURE account.create_account(OUT error_code INT
                                        ,IN app_user_id_in BIGINT
                                        ,IN account_name_in VARCHAR(45)
                                        ,IN account_web_domain_in VARCHAR(200)
                                        ,IN account_email_addr_in VARCHAR(100)
                                        ,IN account_status_in MEDIUMINT
                                        ,IN fulfillment_type_mask_in MEDIUMINT
                                        ,IN remit_to_duns_in BIGINT
                                        ,IN vid_in CHAR(3)
                                        ,IN description_in VARCHAR(2500)
                                        ,OUT account_id_out BIGINT
                                        ,IN account_type_mask_in MEDIUMINT
                                        )
BEGIN

MAIN:BEGIN  

DECLARE v_catalog_shard_index TINYINT(4) DEFAULT 0;
DECLARE v_oms_shard_index TINYINT(4) DEFAULT 0;

-- Store creation variables
DECLARE v_error_code INT;
DECLARE v_placeholder BIGINT;
DECLARE v_account_type_bit_content MEDIUMINT;
DECLARE v_max_account_type_bit MEDIUMINT;

SELECT BIT_OR(account_type_bit)
  INTO v_account_type_bit_content
  FROM account.account_type_lookup
 WHERE account_type_code IN('CP', 'ICE', 'ECE');

SELECT MAX(account_type_bit)
  INTO v_max_account_type_bit
  FROM account.account_type_lookup;

-- Check on account_mask validity
-- pretty weird way of check constraint implementation
-- account_type_mask is positive,power of 2 and also less than the bit provided in account_type_lookup

IF (fulfillment_type_mask_in <= 0) OR (account_type_mask_in <=0) OR ((account_type_mask_in&(account_type_mask_in-1))<>0)
OR (account_type_mask_in > v_max_account_type_bit)
THEN
SET error_code=-3;
LEAVE MAIN;
END IF; 

SET error_code=-2; 

SELECT shard_index INTO v_catalog_shard_index
  FROM account.shard s,account.shard_type st
 WHERE st.shard_type_name='CATAlOG_SHARD'
   AND s.shard_type_id=st.shard_type_id
   AND s.shard_status=1
 ORDER BY RAND(shard_id + UNIX_TIMESTAMP()) 
 LIMIT 1;

SELECT shard_index INTO v_oms_shard_index
  FROM account.shard s,account.shard_type st
 WHERE st.shard_type_name='OMS_SHARD'
   AND s.shard_type_id=st.shard_type_id
   AND s.shard_status=1
 ORDER BY RAND(shard_id + UNIX_TIMESTAMP()) 
 LIMIT 1;

SET error_code=-2;

INSERT INTO account.account (
  account_id, 
  account_name, 
  account_email_addr, 
  account_status, 
  account_web_domain,
  created_dtm,
  modified_id,
  account_type_mask
)
VALUES 
(
  NULL, 
  account_name_in, 
  account_email_addr_in, 
  account_status_in, 
  account_web_domain_in, 
  CURRENT_TIMESTAMP(),
  app_user_id_in,
  account_type_mask_in
);
       
SET account_id_out = LAST_INSERT_ID();
  
IF (account_type_mask_in&v_account_type_bit_content) =0  THEN
  
INSERT INTO account.vendor_account (
  account_id, 
  fulfillment_type_mask,
  vid,
  description,
  channel_mask,
  modified_id,
  created_dtm,
  catalog_shard_index,
  oms_shard_index,
  remit_to_duns
)
VALUES 
(
  account_id_out, 
  fulfillment_type_mask_in,
  vid_in,
  description_in,
  1,
  app_user_id_in,
  CURRENT_TIMESTAMP(),
  v_catalog_shard_index,
  v_oms_shard_index,
  remit_to_duns_in
);
       
 END IF;       

SET error_code=0;

END MAIN;
 
END$$
DELIMITER ;
