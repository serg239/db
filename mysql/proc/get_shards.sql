
-- call account.get_shards (@err);

DROP PROCEDURE IF EXISTS account.get_shards;

DELIMITER $$
CREATE PROCEDURE account.get_shards (OUT error_code INT) 
BEGIN

SET error_code=-1;

SELECT s.shard_id
      ,s.shard_index
      ,s.shard_name
      ,st.shard_type_name
      ,s.db_port
      ,s.db_host
      ,s.shard_status
  FROM account.shard        s
    JOIN account.shard_type st
      ON st.shard_type_id = s.shard_type_id;

SET error_code=0;

END$$
DELIMITER ;
