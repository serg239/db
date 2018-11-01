USE 'report';

DROP PROCEDURE IF EXISTS get_sales_and_returns_summary_report; 

DELIMITER $$

CREATE PROCEDURE get_sales_and_returns_summary_report
(
  OUT error_code   INT, 
   IN start_date   DATE,
   IN end_date     DATE,
   IN account_id   BIGINT 
)
/*
  Description:
     FBS Sales and Return Summary report.
  Input:
    start_date
    end_date
    account_id
  Output:
    duns_number           -- Seller DUNS#;
    account_name          -- Seller name;
    external_product_id   -- Seller's Item ID;
    item_number           -- SHC Item ID;
    name                  -- Item name;
    po_date               -- Order date (date of the order against which the return was made);
    selling_price         -- Selling price (selling price of the item at the time the order was placed);
    return_date           -- Action Date (date when the items were shipped or returned)
    quantity_shipped      -- Quantity shipped (quantity shipped by DART to the customer; 
                             this is from the order against which the return was made)
                             COUNT when fulfillment_status_id is = 2
    quantity_returned     -- Quantity returned (quantity returned by the customer to DART between 
                             start and end date. 
                             NOTE: Items returned to store and are not forwarded to DART will 
                             not be tracked in this report)
                             -- COUNT where pol.return_id IS NOT NULL
  Usage:
    CALL report.get_sales_and_returns_summary_report (@err, '2009-01-01', '2010-09-28', NULL);
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+---------------------+---------------+-------------+------------------+-------------------+
    | duns_number | account_name        | external_product_id | item_number | name                                      | po_date             | selling_price | return_date | quantity_shipped | quantity_returned |
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+---------------------+---------------+-------------+------------------+-------------------+
    | 000159038   | gjhj                | 111111              | 94004       | Lasko 9 in. Red Pen holder1               | 2009-10-22 00:00:00 |          1299 | 2009-12-21  |               25 |                 0 |
    | 000159038   | gjhj                | 111111              | 10442       | Lasko 9 in. Red Pen holder1               | 2010-02-15 00:00:00 |          9000 | 2010-02-16  |                1 |                 0 |
    | 000159038   | gjhj                | 111111              | 94004       | Lasko 9 in. Red Pen holder1               | 2009-10-22 00:00:00 |          1299 | 2010-03-26  |               20 |                 0 |
    | 000159038   | gjhj                | 111111              | 94004       | Lasko 9 in. Red Pen holder1               | 2009-10-22 00:00:00 |          1299 | 2010-03-29  |               20 |                 0 |
    | 000159038   | gjhj                | 111111              | 94004       | Lasko 9 in. Red Pen holder1               | 2009-10-22 00:00:00 |          1299 | 2010-03-29  |               20 |                 0 |
    | 000159038   | gjhj                | 111111              | 94004       | Lasko 9 in. Red Pen holder1               | 2009-10-22 00:00:00 |          1299 | 2010-03-30  |               20 |                 0 |
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+---------------------+---------------+-------------+------------------+-------------------+
    | 000245613   | fbs_test@yahoo.com  | A1004               | 94004       | NeoFit Case: Yellown - DSi & DS Lite      | 2010-06-30 00:00:00 |          2599 | 2010-06-30  |               50 |                 0 |
    | 000245613   | fbs_test@yahoo.com  | PO                  | 94004       | PUBLISH                                   | 2010-06-30 00:00:00 |          2599 | 2010-06-30  |               55 |                 0 |
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+---------------------+---------------+-------------+------------------+-------------------+
    | 000323766   | FBS PATCH 8/17/2010 | X0002               | 94004       | Clive Christian X Perfume Spray for Women | 2010-07-20 00:00:00 |          2599 | 2010-08-17  |               50 |                 0 |
    | 000323766   | FBS PATCH 8/17/2010 | X0002               | 94004       | Clive Christian X Perfume Spray for Women | 2010-07-20 00:00:00 |          2599 | 2010-08-17  |               55 |                 0 |
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+---------------------+---------------+-------------+------------------+-------------------+
    | 000329722   | Def Leppard         | X0006               | 94004       | Clive Christian X Perfume Spray for Women | 2010-07-20 00:00:00 |          2599 | 2010-08-25  |               50 |                 0 |
    | 000329722   | Def Leppard         | X0006               | 94004       | Clive Christian X Perfume Spray for Women | 2010-07-20 00:00:00 |          2599 | 2010-08-25  |               55 |                 0 |
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+---------------------+---------------+-------------+------------------+-------------------+
    12 rows in set (0.02 sec)
    
  History:
    JIRA: MMP-5287
    CALL report.get_sales_and_returns_summary_report (@err, '2009-01-01', '2010-09-28', NULL);    
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+-----------+------------+-----------+------------+---------------+------------------+-------------+-------------------+
    | duns_number | account_name        | external_product_id | item_number | item_name                                 | po_number | po_date    | po_status | sales_date | selling_price | quantity_shipped | return_date | quantity_returned |
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+-----------+------------+-----------+------------+---------------+------------------+-------------+-------------------+
    | 000159038   | gjhj                | 111111              | 10442       | Lasko 9 in. Red Pen holder1               |   2240106 | 02/15/2010 | Open      | 12/31/2009 |          9000 |                1 | 02/16/2010  |                 1 |
    | 000159038   | gjhj                | 111111              | 94004       | Lasko 9 in. Red Pen holder1               |    975870 | 10/22/2009 | Open      | 11/05/2009 |          1299 |                5 | 12/21/2009  |                 1 |
    | 000159038   | gjhj                | 111111              | 94004       | Lasko 9 in. Red Pen holder1               |     12474 | 10/22/2009 | Open      | 11/05/2009 |          1299 |               40 | N/A         |                 8 |
    | 000245613   | fbs_test@yahoo.com  | PO                  | 94004       | PUBLISH                                   |   6301150 | 06/30/2010 | Open      | 07/30/2010 |          2599 |                6 | 06/30/2010  |                 5 |
    | 000245613   | fbs_test@yahoo.com  | A1004               | 94004       | NeoFit Case: Yellown - DSi & DS Lite      |   6301150 | 06/30/2010 | Open      | 07/30/2010 |          2599 |                6 | 06/30/2010  |                 5 |
    | 000323766   | FBS PATCH 8/17/2010 | X0002               | 94004       | Clive Christian X Perfume Spray for Women |   8171014 | 07/20/2010 | Open      | 07/30/2010 |          2599 |               12 | 08/17/2010  |                10 |
    | 000329722   | Def Leppard         | X0006               | 94004       | Clive Christian X Perfume Spray for Women |   8251233 | 07/20/2010 | Open      | 09/30/2010 |          2599 |               12 | 08/25/2010  |                10 |
    +-------------+---------------------+---------------------+-------------+-------------------------------------------+-----------+------------+-----------+------------+---------------+------------------+-------------+-------------------+
    7 rows in set (0.02 sec)

    OLD API:
    ========
    duns_number           -- Seller DUNS#;
    account_name          -- Seller name;
    external_product_id   -- Seller's Item ID;
    item_number           -- SHC Item ID;
    name                  -- Item name;
    po_date               -- Order date (date of the order against which the return was made);
    selling_price         -- Selling price (selling price of the item at the time the order was placed);
    return_date           -- Action Date (date when the items were shipped or returned)
    quantity_shipped      -- Quantity shipped (quantity shipped by DART to the customer; 
                             this is from the order against which the return was made)
                             COUNT when fulfillment_status_id is = 2
    quantity_returned     -- Quantity returned (quantity returned by the customer to DART between 
                             start and end date. 
                             NOTE: Items returned to store and are not forwarded to DART will 
                             not be tracked in this report)
                             -- COUNT where pol.return_id IS NOT NULL

    NEW API:
    ========
    duns_number  
    account_name
    external_product_id
    item_number
    item_name
    po_number             -- New: Purchase Order Number
    po_date
    po_status             -- New: Purchase Order Status
    sales_date            -- New: Sales date 
    selling_price
    return_date           -- Attn: This is RETURN DATE ONLY, NOT SHIPPMENT DATE!!! 
    quantity_shipped
    quantity_returned
    
  Notes:
      +---------------------------------------------------------+
      |                                                         |
      v wa.account_id    po.program_type_mask  = 4 (FBS)        | pol.fulfillment_status_id = 2 (Fulfilled)
  +---------------+      +-----------------+            +---------------------+  
  |  web_account  |<-----| purchase_order  |<-----------| purchase_order_line |
  +---------------+      +-----------------+            +---------------------+
      ^                          ^         store_id             |             product_id
      |                          |         site_id              |             part_id
      |                  +-----------------+                    |             invoice_id
      |                  | com_line_detail |                    |
      |                  +-----------------+                    |
      |                                                         v
      |                                                 +---------------+  end_date > r.return_date >= start_date
      +-------------------------------------------------|    return     | 
                                                        +---------------+
                                                      
*/
BEGIN

  DECLARE v_end_date DATE DEFAULT ADDDATE(end_date, INTERVAL 1 DAY);

  SET error_code = -2;
  SET @sql_stmt= NULL;

  SET @sql_stmt = 
    'SELECT q.duns_number,            -- Seller DUNS#
            q.account_name,           -- Seller name
            q.external_product_id,    -- Sellers Item ID
            q.item_number,            -- SHC Item ID
            q.name                                   AS item_name,        -- Item name
            q.po_number,
            DATE_FORMAT(q.po_date, "%m/%d/%Y")       AS po_date,          -- Order date (date of the order against which the return was made)
            CASE q.po_status WHEN 1 THEN "Open"
                             WHEN 2 THEN "Invoice"
                             WHEN 3 THEN "Pending"
            END                                      AS po_status,        -- Order Status
            DATE_FORMAT(q.sales_date, "%m/%d/%Y")    AS sales_date,       -- Sales date
            q.selling_price,                                              -- Selling price (selling price of the item at the time the order was placed)
            IFNULL(q.return_date, "N/A")             AS return_date,      -- Return Date
            SUM(IFNULL(q.quantity_shipped, 0))       AS quantity_shipped, -- Quantity shipped
            SUM(IFNULL(q.quantity_returned, 0))      AS quantity_returned -- Quantity returned
      FROM
        (SELECT po.duns_number,
                wa.account_name,
                cld.external_product_id,
                pol.item_number,
                cld.name,
                po.po_number,
                po.po_date,
                po.po_status_id AS po_status,
                po.sales_date,
                pol.selling_price,
                CASE r.return_date WHEN NULL THEN "N/A"
                                   ELSE DATE_FORMAT(r.return_date, "%m/%d/%Y") 
                END                              AS return_date,      -- Return Date
                COUNT(pol.fulfillment_status_id) AS quantity_shipped,
                COUNT(pol.return_id)             AS quantity_returned
          FROM account.web_account         wa
            JOIN order.purchase_order      po
              ON po.account_id          = wa.account_id
                AND wa.account_type_mask = 4';           -- FBS only

  IF account_id IS NOT NULL THEN
    SET @sql_stmt = CONCAT(@sql_stmt, 
      ' AND wa.account_id = ', account_id);
  END IF;

  SET @sql_stmt = CONCAT(@sql_stmt, '
               JOIN order.purchase_order_line pol
                 ON pol.purchase_order_id = po.purchase_order_id
                   AND pol.fulfillment_status_id = 2      -- Fulfilled
                   AND pol.account_id = wa.account_id
               JOIN order.com_line_detail     cld
                 ON pol.purchase_order_id = cld.purchase_order_id
                   AND pol.com_line_number   = cld.com_line_number
               LEFT OUTER JOIN order.return         r
                 ON pol.return_id = r.return_id
                   AND r.return_date  >= ''', start_date, '''
                   AND r.return_date   < ''', end_date, '''
                   AND r.account_id    = wa.account_id
             WHERE po.program_type_mask  = 4            -- FBS
           GROUP BY po.duns_number, wa.account_name, cld.external_product_id, pol.item_number, 
                    cld.name, po.po_number, po.po_date, po.po_status_id, po.sales_date,
                    pol.selling_price, pol.fulfillment_status_id
          ) q
         GROUP BY q.duns_number, q.account_name, q.external_product_id, q.item_number, q.name, 
                  q.po_date, q.po_status, q.sales_date, q.selling_price, q.return_date
         ORDER BY q.duns_number, q.item_number
 ');

  -- SELECT @sql_stmt;

  PREPARE query FROM @sql_stmt;
  EXECUTE query;
  DEALLOCATE PREPARE query;

  SET error_code = 0;

END$$

DELIMITER ;
