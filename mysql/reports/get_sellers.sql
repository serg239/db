DELIMITER $$

USE 'report'$$

DROP PROCEDURE IF EXISTS get_sellers$$

CREATE PROCEDURE get_sellers
(
  OUT error_code  INT,
   IN from_date   DATE,
   IN to_date     DATE
)
/*
  Report Name:
    Seller Report.
  Input:
    from_date - the start date of the period 
    to_date   - the end date of the period 
  Output:
    error_code - Error Code: 0 - OK;
                            -2 - error.
  Usage:
    CALL report.get_sellers(@err, '2010-08-01', '2010-09-15');
  Result:
    +--------------------+----------------------+-------------------+
    | seller_duns_number | seller_name          | seller_start_date |
    +--------------------+----------------------+-------------------+
    | 000301812          | Ates LMP             | 04/21/2010        |
    | 000316075          | Charly               | 06/28/2010        |
    | 000320721          | Deepthi Harikrishnan | 08/10/2010        |
    | 000329722          | Def Leppard          | 08/25/2010        |
    | 000316752          | Don Kihot            | 06/30/2010        |
    | 000302075          | FBS 04 28            | 04/23/2010        |
    | 000323766          | FBS PATCH 8/17/2010  | 08/16/2010        |
    | 000300673          | FBSqe                | 04/15/2010        |
    +--------------------+----------------------+-------------------+
  Notes:
    1. Possible checks:
    JOIN account.account_status       ast
      ON (act.account_status = ast.account_status
         AND LOWER(ast.description) = 'active')
    JOIN account.account_store        acs
      ON (acs.account_id = act.account_id
        AND acs.account_store_status = 1)     -- const now?
    JOIN account.store                sto  
      ON acs.store_id = sto.store_id
    JOIN account.store_type           stt
      ON (sto.store_type_id = stt.store_type_id
        AND stt.store_type_name = 'WAREHOUSE')
*/
BEGIN

  DECLARE t_from_date DATE DEFAULT IFNULL(from_date, SUBDATE(CURRENT_DATE(), INTERVAL 1 DAY));
  DECLARE t_to_date   DATE DEFAULT IFNULL(to_date, CURRENT_DATE());

  SET error_code = -2;

  SET @sql_stmt = CONCAT('
    SELECT act.duns                                  AS seller_duns_number, 
           act.account_name                          AS seller_name, 
           DATE_FORMAT(act.created_dtm, "%m/%d/%Y")  AS seller_start_date
      FROM account.web_account            act
     WHERE act.duns IS NOT NULL
       AND act.created_dtm BETWEEN ''', t_from_date, ''' AND ''', t_to_date, '''
     ORDER BY act.account_name
  ');

  -- SELECT @sql_stmt;

  PREPARE query FROM @sql_stmt;
  EXECUTE query;
  DEALLOCATE PREPARE query;

  SET error_code = 0;

END$$

DELIMITER ;
