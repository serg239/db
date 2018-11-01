#Initializing variables
prgName=shop_report
mkdir -p "/tmp/${prgName}"
tmpdir="/tmp/${prgName}"
reportDate="$(date -d 'today' +%b" "%d)"

# interval of report
interval=7
#BCC="support@mycompany.com"

TOEMAIL="abc@mycompany.com,def@mycompany.com"

emailSub="Shop-Data-Report: ${reportDate} "

# initialize files
cat /dev/null > "$tmpdir/${prgName}.msg"
st=$(date +%s)

# dB host names
CatalogDBhost="db_c1.s.com"

# mysql command.
MYSQL_CMD="/usr/bin/mysql -user -password"

MY_SQL_CALL="SET SQL_MODE = 'TRADITIONAL';
SELECT ei.external_item_id,
       CONCAT('\'',ei.product_id,'\'') AS product_id,
       CONCAT('\'',ei.upc,'\'')        AS upc,
       ei.title,
       CONCAT('\'',ei.manufacturer_part_number,'\'') AS manufacturer_part_number,
       ei.manufacturer_name,
       ei.lastdeliverydate,
       ei.modified_dtm,
       ei.created_dtm,
       ev.value_name                   AS 'Shop Data Quality Score',
       i.item_id                       AS 'Item ID',
       cic.content_item_class_display_path AS 'Item Class',
       i.modified_id                   AS 'Merchant',
       i.ksn_id                        AS 'KSN',
       CONCAT('\'',i.pid ,'\'')        AS 'PID',
       CONCAT('\'',i.websku ,'\'')     AS 'Websku',
       i.ima_item_id                   AS 'IMA Item ID',
       IF(i.ima_attribute_values LIKE '%mfgname%',
          (TRIM(' ' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(i.ima_attribute_values,'~|~mfgname==',-1),'~|~',1))),
          NULL
         ) AS 'IMA Manufacturer Name',
       IFNULL(CASE i.allocation_mask WHEN 1 THEN 'Site_01' 
                                     WHEN 2 THEN 'Site_02'
                                     WHEN 3 THEN 'Both'
              END, 
              ''
         )                             AS 'Online Allocation',
       i.core_item_number              AS 'Core Item ID',
       IFNULL(CASE i.owner_code WHEN 'S' THEN 'Site_02' 
                                WHEN 'K' THEN 'Site_01' 
                                WHEN 'B' THEN 'Both' 
              END, 
              ''
             )                         AS 'Site',
        SUBSTRING_INDEX(sh_k.store_hierarchy_display_path , '|', 1)                           AS 'Site_01 Division',
        SUBSTRING_INDEX(SUBSTRING_INDEX(sh_k.store_hierarchy_display_path , '|', 3), '|', -1) AS 'Site_01 Category',
        SUBSTRING_INDEX(sh_k.store_hierarchy_display_path , '|', -1)                          AS 'Site_01 Subcategory',
        SUBSTRING_INDEX(sh_s.store_hierarchy_display_path , '|', 1)                           AS 'Site_02 Vertical',
        SUBSTRING_INDEX(SUBSTRING_INDEX(sh_s.store_hierarchy_display_path , '|', 2), '|', -1) AS 'Site_02 Subline',
        SUBSTRING_INDEX(SUBSTRING_INDEX(sh_s.store_hierarchy_display_path , '|', 3), '|', -1) AS 'Site_02 Subline Variable',      
        IF(i.ima_attribute_values LIKE '%brand%',
           (TRIM(' ' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(i.ima_attribute_values,'~|~brand==',-1),'~|~',1))),
           NULL
          )                       AS 'IMA Brand',   
        b.brand_name              AS 'Brand',   
        ivp.vendor_stk_number,  
        CONCAT('\'',ci.manufacturer_model_num ,'\'') AS 'Manufacturer Model Number',
        CONCAT('\'',ci.upc,'\'')  AS 'UPC',
        CASE i.catalog_status WHEN 0 THEN 'Rejected'
                              WHEN 1 THEN 'Saved'
                              WHEN 2 THEN 'Published'
                              WHEN 3 THEN 'Ima_pending'
                              WHEN 4 THEN 'New'
                              WHEN 5 THEN 'Excluded'
        END                    'Offer Status',
# ci.status AS 'Content Status',
        IF(ci.enrichment_status = 2,
           'Enriched',
           'Need Enrichment'
          )                    'Content Status',
        IF(i.ima_attribute_values LIKE '%title%',
           (TRIM(' ' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(i.ima_attribute_values,'title==',-1),'~|~',1))),
           NULL
          )                    AS 'IMA Title',
        ci.name AS 'Product Tittle',
        IF(i.item_id IS NOT NULL, 'Yes', 'No') AS 'A-B Match'
  FROM external_content.external_item                              ei
    LEFT OUTER JOIN external_content.external_item_attribute_value eiav
      ON ei.external_item_id = eiav.external_item_id
    JOIN external_content.external_attribute                       ea
      ON (eiav.external_attribute_id = ea.external_attribute_id
        AND ea.attribute_name = 'Shop Data Quality Score'
        AND ea.status = 1)
    JOIN external_content.external_value                           ev
      ON (eiav.external_value_id = ev.external_value_id
        AND ev.status = 1)
    JOIN external_content.external_account                         eac
      ON (ei.external_account_id = eac.external_account_id
        AND eac.account_name = 'Shop'
        AND eac.status = 1)
    LEFT JOIN catalog.content_item_external_item_mapping           cieim 
      ON cieim.external_item_id = ei.external_item_id
    LEFT JOIN catalog.content_item ci 
      ON cieim.content_item_id = ci.content_item_id
    LEFT JOIN catalog.item                                         i 
      ON i.content_item_id = ci.content_item_id
    LEFT JOIN semistatic_content.content_item_class                cic 
      ON i.content_item_class_id = cic.content_item_class_id
    LEFT JOIN  catalog.item_vendor_package                         ivp 
      ON ivp.item_id = i.item_id
    LEFT JOIN semistatic_content.store_hierarchy                   sh_k 
      ON sh_k.store_hierarchy_id = i.shc_hierarchy_id 
        AND sh_k.store_id = 1
    LEFT JOIN semistatic_content.store_hierarchy                   sh_s 
      ON sh_s.store_hierarchy_id = i.core_hierarchy_id 
        AND sh_s.store_id = 2
    LEFT JOIN semistatic_content.brand                             b 
      ON b.brand_id = ci.brand_id 
 WHERE ei.status   = 1
   AND eiav.status = 1
   AND ei.modified_dtm < TIMESTAMP(DATE(NOW()))
   AND ei.modified_dtm >= DATE_SUB(TIMESTAMP(DATE(NOW())), INTERVAL ${interval} DAY);"

${MYSQL_CMD} -h${CatalogDBhost} -P 3306 -e "${MY_SQL_CALL}" > ${tmpdir}/${prgName}.xls

if test "$?" != "0"
 then
   echo -e "Shop Query has failed....\n"
   exit 1
else
   echo -e "Shop Query has completed successfully....\n"
fi

zip -j "${tmpdir}/${prgName}.zip" "${tmpdir}/${prgName}.xls";

if test "$?" != "0"
  then
    echo -e "Shop Report has failed....\n"
    exit 1
 else
   echo -e "Shop Report has been generated successfully....\n"
   echo -e Please find attached the Shop report between $(date -d "${interval} days ago" +%Y-%m-%d) and $(date -d '1 days ago' +%Y-%m-%d) dates. >> "$tmpdir/${prgName}.msg"
   echo -e "\n" >> "$tmpdir/${prgName}.msg"
fi

et=$(date +%s)

mins=$(( ($et-$st) / 60 ))
secs=$(( ($et-$st) % 60 ))

Time="$mins mins, $secs secs"

echo "Execution Time : $Time" >> "$tmpdir/${prgName}.msg"

mutt -s "${emailSub}"  "${TOEMAIL}" -b "${BCC}" -a ${tmpdir}/${prgName}.zip < "$tmpdir/${prgName}.msg"
