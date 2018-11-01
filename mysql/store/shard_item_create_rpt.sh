#! /bin/bash
st=$(date +%s)

#############################################
##       Item Create Report Script         ##
#############################################

# program name
prog_name=$(basename $0)
  
# paths
# tmp_dir="/var/batch/PROD_SUPPORT/bin/tmp"
tmp_dir="/home/szaytsev/test/reports/tmp"
  
# dB host names
# acct_db_host="db_01"
# acct_db_host="db_dw"
acct_db_host="test-db3"
  
#shard type name
shard_type_name="CATALOG_SHARD"
  
#check if date is passed in $1, else use yesterday as report date
if [ test -s $1 ]; then
  reportDate=$(date -d "yesterday" +%Y-%m-%d)
else
  reportDate=$1
fi

# initialize files
cat /dev/null > "$tmp_dir/item_create_rpt.msg"
cat /dev/null > "$tmp_dir/item_create.csv"
cat /dev/null > "$tmp_dir/TW_item_create.csv"

#############################################  
## usage, this is not printed as of now :) ##
#############################################
function usage() {
cat >& 2 << __USAGE__
${prog_name}: Usage: ${prog_name} Reporting Date [optional, yyyy-mm-dd]
__USAGE__
} 
  
# mysql command.
# !!! DO NOT GIVE -v OPTION, SCRIPT WILL NOT WORK !!!
MYSQL_CMD="/usr/bin/mysql -user -password"
  
######################################################################
## call mysql and get the shards for the shard_type from item table ##
######################################################################

function getShards() {
   
  if [ "$1" == "VD" ]; then
    MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY="
     -- get shards for the shard_type
     SELECT s.shard_index,
            s.db_host,
            s.db_port
       FROM account.shard      s,
            account.shard_type st
      WHERE st.shard_type_name = UPPER(\"${shard_type_name}\")
        AND s.shard_type_bit_value & st.shard_type_bit_value = st.shard_type_bit_value 
        AND s.shard_status = 1;
    "
    # | shard_index | db_host      | db_port |
    # |           0 | 172.22.4.162 | 3306    |
    
    ${MYSQL_CMD} -h${acct_db_host} -e "${MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY}" | grep -v "shard_index" | \
    sed 's/[ \t]/|/g' > $tmp_dir/shards_for_${shard_type_name}_VD.txt 
    # 0|172.22.4.162|3306

    if [ "$?" != "0" ]; then
      echo "Getting Shards for ${shard_type_name} failed..." 1>&2
      # exit 1
    else
      echo "SHARD_HOSTS=$(cat $tmp_dir/shards_for_${shard_type_name}_VD.txt)"
    fi
  fi

  if [ "$1" == "TW" ]; then
    MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY="
      -- get shards for the shard_type
      SELECT s.shard_index,
             s.db_host,
             s.db_port
        FROM account.shard          s,
             account.shard_type     st,
             account.vendor_account va
       WHERE UPPER(st.shard_type_name) = UPPER(\"${shard_type_name}\")
         AND s.shard_type_bit_value & st.shard_type_bit_value = st.shard_type_bit_value 
         AND s.shard_status = 1 
         AND s.shard_index  = va.catalog_shard_index
         AND va.account_id  = 0;
    "
    # | shard_index | db_host      | db_port |
    # |           0 | 172.22.4.162 | 3306    |
   
    ${MYSQL_CMD} -h${acct_db_host} -e "${MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY}" | grep -v "shard_index" | \
    sed 's/[ \t]/|/g' > $tmp_dir/shards_for_${shard_type_name}_TW.txt
    # 0|172.22.4.162|3306

    if [ "$?" != "0" ]; then
      echo "Getting Shards for ${shard_type_name} failed..." 1>&2
      # exit 1
    else
      echo "SHARD_HOSTS=$(cat $tmp_dir/shards_for_${shard_type_name}_TW.txt)"
    fi
  fi
} 

######################################################################  
##      call mysql and get the new account_ids from item table      ##
######################################################################

function getNewAccountIds() {
   
  shard_index="$1"
  shard_host="$2" 
  shard_port="$3" 
  
  MYSQL_NEW_ACCOUNT_IDS_QUERY="
    -- get account_ids for new products
    SELECT GROUP_CONCAT(DISTINCT i.account_id) AS account_id_list
      FROM catalog.item  i
     WHERE i.created_dtm BETWEEN \"${reportDate}\" AND ADDDATE(\"${reportDate}\", INTERVAL 1 DAY) 
       AND i.account_id <> 0;    -- VD
   "
   # 10010874,10086101,10069972
  
   NEW_ACCOUNT_IDS=$(${MYSQL_CMD} -h${shard_host} -e "${MYSQL_NEW_ACCOUNT_IDS_QUERY}" | grep -v "account_id_list")
  
  if [ test "$?" != "0" ]; then
    echo "Getting Account ids failed..." 1>&2
    # exit 1
  else
    echo "NEW_ACCOUNT_IDS=${NEW_ACCOUNT_IDS}"
  fi
} 
  
######################################################################  
##     get account account id and name query as set of unions       ##
######################################################################

function getAccountNameQuery() {
  
  MYSQL_GET_ACCOUNT_NAMES="
  -- get account id and name
  SELECT a.account_id, 
         CONCAT('\'',a.account_name,'\'')
    FROM account.account  a
   WHERE a.account_id IN (${NEW_ACCOUNT_IDS})   -- TW
   ;    
   "
   # |   10010874 | 'NEWPORT LAYTON HOME FASHIONS'   |
   # |   10069972 | 'LANDS END'                      |
   # |   10086101 | 'CREATIVE SOLUTIONS LLC'         |

   NEW_ACCOUNT_NAMES_QUERY=$(${MYSQL_CMD} -h${acct_db_host} -e "${MYSQL_GET_ACCOUNT_NAMES}" | grep -v "account_id" |
                             awk 'BEGIN {FS="\t"};
                                  {print "SELECT " $1" AS account_id, " $2" AS account_name UNION"}
                                  END {print "SELECT "$1" AS account_id, " $2" AS account_name"}')
  # SELECT 10010874 AS account_id, 'NEWPORT LAYTON HOME FASHIONS' AS account_name UNION
  # SELECT 10069972 AS account_id, 'LANDS END' AS account_name UNION
  # SELECT 10086101 AS account_id, 'CREATIVE SOLUTIONS LLC' AS account_name
  
  if [ test "$?" != "0" ]; then
    echo "Getting VD Account names failed..." 1>&2
    exit 1;
  else
    echo "NEW_ACCOUNT_NAMES_QUERY=${NEW_ACCOUNT_NAMES_QUERY}"
  fi
} 

######################################################################  
## call item report, insert the account name union query in between ##
######################################################################

function getNewItemsRpt() {
  
  shard_index="$1"
  shard_host="$2"
  shard_port="$3"
   
  echo " "
  echo "Generating report for ${shard_host} shard..."
  getNewAccountIds "${shard_index}" "${shard_host}" "${shard_port}";
  if [ "${NEW_ACCOUNT_IDS}" == "NULL" ]; then
    return 2
  fi
   
  # call getAccountNameQuery to get account names
  getAccountNameQuery;
   
  MYSQL_NEW_ITEMS_RPT_QUERY="
  SET @cnt = 0;
  
  SELECT (@cnt := @cnt + 1) AS line_num,
          t.*
    FROM 
     (SELECT STRAIGHT_JOIN DISTINCT IFNULL(t.account_name, '') AS account_name,
             IFNULL(s.site_name,  '')   AS site_name,
             IFNULL(temp.item_id, '')   AS item_id,
             MAX(CASE WHEN si.site_id = ivp.store_id THEN ivp.order_duns_number
                      WHEN (si.site_id = 3 AND ivp.store_id = 1) OR                         -- G1 USE Shop_01 UNS
                           (si.site_id > 3 AND ivp.store_id = 2) THEN ivp.order_duns_number -- OTHERS USE Shop_02 DUNS
                      ELSE NULL 
                 END
                )                                     AS order_duns_number,
             IFNULL(temp.websku,'')                   AS websku,
             IFNULL(CONCAT('\'',temp.pid,'\''),  '')  AS pid,
             IFNULL(irt.item_relation_type_name, '')  AS item_type,
             IFNULL(temp.base1_pid,    '')            AS dummy_pid,
             IFNULL(temp.base1_websku, '')            AS dummy_websku,
             IFNULL(CONCAT('\'',ci.upc,'\''), '')     AS upc,
             IFNULL(ci.name, '')                      AS item_title,
             IFNULL(cic.content_item_class_display_path, '') AS content_item_class_display_path,
             IFNULL(SUBSTR(cic.content_item_class_display_path,
                    1, 
                    LOCATE('|',cic.content_item_class_display_path)-1), '') AS content_item_class_top,
             IFNULL(lsis.lookup_description, '')      AS seller_item_status,
             IFNULL(lcis.lookup_description, '')      AS catalog_status,
             IFNULL(temp.created_dtm, '')             AS created_dtm,
             IFNULL(temp.modified_dtm, '')            AS modified_dtm
       FROM
         (${NEW_ACCOUNT_NAMES_QUERY}
         )  t,
         (SELECT IF(!(@iri = p.item_relation_id),
                    @r := 1,
                    @r := @r+1
                   )               AS rank,
                    -- Populating base pid for child items
                   IF(!(@iri = p.item_relation_id),
                      @bp := NULL,
                      @bp
                     )             AS base1_pid,
                   -- Populating base websku for child items 
                   IF(!(@iri = p.item_relation_id),
                      @bs := NULL,
                      @bs
                     )             AS base1_websku, 
                   -- Populating base item_id for child items and item_id for single items
                   IF(!(@iri = p.item_relation_id),
                      @bi := NULL,
                      (IF(p.relation_type_mask > 1,
                          @bi,
                          p.item_id
                         )
                      )
                     )             AS base_item_id, 
                   -- Populating base relation_type_mask for child items and relation_type_mask for single items
                   IF(!(@iri=p.item_relation_id),
                      @bm := NULL,
                      (IF(p.relation_type_mask > 1,
                          @bm,
                          p.relation_type_mask
                         )
                       )
                     ) AS base_mask,
                   -- Session variables
                   @iri := p.item_relation_id,
                   IFNULL(@bp, 
                          @bp := p.base_pid),
                   IFNULL(@bs, 
                          @bs := p.base_websku),
                   IFNULL(@bi, 
                          @bi := p.base_item_id),
                   IFNULL(@bm, 
                          @bm := p.relation_type_mask),
                   -- Populating status for active and inactive items               
                   IF(p.relation_type_mask > 1,
                      p.item_relation_status,
                      p.seller_item_status
                     )                           AS item_relation_status,
                   p.item_relation_id,
                   IFNULL(p.dummy_item_flag, 0)  AS dummy_item_flag,
                   p.item_id,
                   p.pid,
                   p.websku,
                   p.account_id,
                   p.account_type,
                   p.relation_type_mask,
                   p.fulfillment_type,
                   p.content_item_class_id,
                   p.content_item_id,
                   p.seller_item_status,
                   p.catalog_status, 
                   p.created_dtm,
                   p.modified_dtm 
            
          FROM 
           (SELECT @r   := 0,
                   @iri := NULL,
                   @bp  := NULL,
                   @bs  := NULL,
                   @bi  := NULL,
                   @bm  := NULL
           ) ses,
           (SELECT * 
              FROM 
                (SELECT i.item_id,
                        i.websku, 
                        i.pid,
                        i.dummy_item_flag,
                        IF(i.dummy_item_flag=1,i.pid,NULL) AS base_pid,
                        IF(i.dummy_item_flag=1,i.websku,NULL) AS base_websku,
                        -- Populating the item relation id,
                        IF((i.relation_type_mask=1 AND ird.status=0),NULL,IFNULL(ird.item_relation_id,ir.item_relation_id)) AS item_relation_id,
                        -- Populating parent and child item status
                        IFNULL(IF((i.dummy_item_flag=1 AND ird.status=0),ir.status,ird.status),ir.status) AS item_relation_status, 
                        ir.base_item_id,
                        i.account_id,
                        i.account_type,
                        i.relation_type_mask,
                        i.fulfillment_type,
                        i.content_item_class_id,
                        i.content_item_id,
                        i.seller_item_status,
                        i.catalog_status, 
                        i.created_dtm,
                        i.modified_dtm
                   FROM catalog.item i
                    LEFT OUTER JOIN catalog.item_relation_detail ird 
                      ON i.item_id = ird.item_id
                    LEFT OUTER JOIN catalog.item_relation        ir
                      ON i.item_id = ir.base_item_id
                 ) inner_most  
               ORDER BY inner_most.item_relation_id, inner_most.dummy_item_flag DESC  
             ) p
         ) temp
         LEFT OUTER JOIN catalog.item_vendor_package ivp
           ON (ivp.item_id = temp.item_id 
             AND ivp.status = 1 ),
         static_content.lookup      lsis,
         static_content.lookup      lcis,
         semistatic_content.content_item_class cic,
         catalog.content_item       ci,
         static_content.site        s,
         catalog.item_site          si,
         static_content.item_relation_type irt
   WHERE t.account_id = temp.account_id
         AND temp.account_id <> 0
         AND temp.content_item_class_id = cic.content_item_class_id
         AND temp.content_item_id = ci.content_item_id
         AND temp.dummy_item_flag <> 1
         AND si.site_id = s.site_id
         AND temp.base_item_id=si.item_id
         AND temp.item_relation_status <> 0 -- inactive item filter
         AND si.status = 1
         AND temp.created_dtm BETWEEN \"${reportDate}\" AND ADDDATE(\"${reportDate}\", INTERVAL 1 DAY)
         AND temp.seller_item_status = lsis.lookup_value
         AND temp.catalog_status = lcis.lookup_value
         AND lsis.lookup_type_id = 19 -- seller_status
         AND lcis.lookup_type_id = 18 -- catalog_status
         AND irt.bit_value & temp.base_mask = temp.base_mask
        GROUP BY temp.account_id, s.site_id, temp.item_id
   ORDER BY 1, 2, 3) T;
   "
  
  ${MYSQL_CMD} -h${shard_host} -P${shard_port} -e "${MYSQL_NEW_ITEMS_RPT_QUERY}" | sed 's/"/""/g;s/\t/","/g;s/^/"/;s/$/"/;s/\n//g' > $tmp_dir/item_create_temp_${shard_index}.csv
  if test "$?" != "0"
    then
      echo "Getting New VD Items Report failed for ${shard_host} shard..." 1>&2
      exit 1
    else
     echo "VD Report generation success for ${shard_host} shard." 1>&2
  fi
} 
  
##################################
##    fetching new TW items     ##
##################################

function getNewTWItemsRpt() {
  
  shard_index="$1"
  shard_host="$2"
  shard_port="$3"
  
  MYSQL_NEW_TW_ITEMS_RPT_QUERY="
   SELECT 'SHC'                                      AS account_name,
          IFNULL(i.item_id, '')                      AS item_id,
          IFNULL(CONCAT('\'',ci.upc,'\''), '')       AS upc,
          IFNULL(ci.name, '')                        AS item_title,
          IFNULL(sh.store_hierarchy_display_path,'') AS hierarchy,
          IFNULL(SUBSTRING_INDEX(sh.store_hierarchy_display_path,'|',1),'') AS division_name,
          IFNULL(i.shc_division_nbr,'')              AS division_nbr,
          IFNULL(lsis.lookup_description, '')        AS seller_item_status,
          IFNULL(lcis.lookup_description, '')        AS catalog_status,
          IFNULL(les.lookup_description,  '')        AS enrichment_status,
          IFNULL(i.created_dtm,  '')                 AS created_dtm,
          IFNULL(i.modified_dtm, '')                 AS modified_dtm
     FROM catalog.item                        i 
       INNER JOIN catalog.content_item        ci 
         ON i.content_item_id = ci.content_item_id
           AND ci.status  = 1
       INNER JOIN catalog.item_vendor_package ivp 
         ON i.item_id = ivp.item_id 
           AND ivp.status = 1
       LEFT OUTER JOIN semistatic_content.content_item_class cic 
         ON i.content_item_class_id = cic.content_item_class_id
           AND cic.status = 1
       LEFT OUTER JOIN catalog.item_site      si
         ON i.item_id = si.item_id 
           AND si.status = 1
       LEFT OUTER JOIN static_content.site    s
         ON s.site_id = si.site_id
       LEFT OUTER JOIN static_content.lookup  lsis 
         ON lsis.lookup_type_id = 19 
           AND i.seller_item_status = lsis.lookup_value   -- SELLER_STATUS
       LEFT OUTER JOIN static_content.lookup  lcis
         ON lcis.lookup_type_id = 18 
           AND i.catalog_status = lcis.lookup_value 
       LEFT OUTER JOIN static_content.lookup  les 
         ON les.lookup_type_id = 20 
           AND ci.enrichment_status = les.lookup_value 
       LEFT OUTER JOIN semistatic_content.store_hierarchy   sh 
         ON sh.store_hierarchy_id = i.shc_hierarchy_id
           AND sh.status   = 1
           AND sh.store_id = 1
    WHERE i.account_id       = 0
      AND i.account_type     = 1
      AND i.fulfillment_type = 3
      AND i.created_dtm BETWEEN \"${reportDate}\" AND ADDDATE(\"${reportDate}\", INTERVAL 1 DAY)
      GROUP BY si.site_id, i.item_id
   ORDER BY 2, 3;"
   
  ${MYSQL_CMD} -h${shard_host} -P${shard_port} -e "${MYSQL_NEW_TW_ITEMS_RPT_QUERY}" | sed 's/"/""/g;s/\t/","/g;s/^/"/;s/$/"/;s/\n//g' > $tmp_dir/TW_item_create.csv
  if [ test "$?" != "0" ]; then
    echo "Getting New SHC Shippable Items Report failed..." 1>&2
    exit 1
  else
    echo "NEW_TW_ITEM_QUERY=${MYSQL_NEW_TW_ITEMS_RPT_QUERY}"
  fi   
}  

########################################
##    calculate time of execution     ##
########################################
  
function printExecTime() {
  et=$(date +%s)
  mins=$(( ($et-$st) / 60 ))
  secs=$(( ($et-$st) % 60 ))

  if [ test $1 == "VD" ]; then
    echo " " >> "$tmp_dir/item_create_rpt.msg"
    Time="Execution Time: "$mins" mins, "$secs" secs"
    echo $Time >> "$tmp_dir/item_create_rpt.msg"
    cat "$tmp_dir/item_create_rpt.msg";
  else  
    echo " " >> "$tmp_dir/item_create_rpt.msg"
    Time="Execution Time: "$mins" mins, "$secs" secs"
    echo $Time >> "$tmp_dir/item_create_rpt.msg"
    cat "$tmp_dir/item_create_rpt.msg";
  fi

} 
  
# print messages to the msg file
  
echo "Getting Report for ${reportDate}..."
echo "Item Creation Reports" >> "$tmp_dir/item_create_rpt.msg"
echo "-------------------------">> "$tmp_dir/item_create_rpt.msg"
echo "Reports for ${reportDate} is attached." >> "$tmp_dir/item_create_rpt.msg"
echo " " >> "$tmp_dir/item_create_rpt.msg"

#############################################
## call the functions one by one VD report ##
#############################################  
  
#getting shards for VD items
getShards VD;
  
if [ ! -s $tmp_dir/shards_for_${shard_type_name}_VD.txt ]; then
  echo "No shards under ${shard_type_name} to process report..." 1>&2
  exit 1
else 
  shard_count="$(cat $tmp_dir/shards_for_${shard_type_name}_VD.txt | wc -l)"
  count=0
fi
  
#Pulling report for VD items from respective shard

cat $tmp_dir/shards_for_${shard_type_name}_VD.txt | \
while read line
do
  shard_index=$(echo ${line} | cut -d '|' -f 1 )
  shard_host=$(echo ${line}| cut -d '|' -f 2)
  shard_port=$(echo ${line}| cut -d '|' -f 3)
  
  getNewItemsRpt "${shard_index}" "${shard_host}" "${shard_port}";
  fetch_status="$(echo $?)"

  if [ "$fetch_status" == "2" ]; then 
    count=$((count + 1))
    if [ "$count" == "$shard_count" ]; then
      echo "No data found..."
    fi
  elif [ "$fetch_status" == "0" ]; then
    if [ -s $tmp_dir/item_create.csv ]; then
       tail -n +2 $tmp_dir/item_create_temp_${shard_index}.csv >> $tmp_dir/item_create.csv
    else
      cat $tmp_dir/item_create_temp_${shard_index}.csv > $tmp_dir/item_create.csv
    fi
  fi
done
  
if [ test -s $tmp_dir/item_create.csv ]; then
  echo "There are $(( `cat $tmp_dir/item_create.csv | cut -d, -f4 | sort -u | wc -l | awk '{print $1}'` - 1)) new VD item(s) created on ${reportDate}." >> "$tmp_dir/item_create_rpt.msg"
  printExecTime VD;
  # exit 0
else
  echo "VD Report generation failed..." 1>&2
  echo "There are no new VD item(s) created on ${reportDate}." >> "$tmp_dir/item_create_rpt.msg"
  printExecTime VD;     
  #  exit 1
fi
  
# print messages to the msg file
  
echo " " >> "$tmp_dir/item_create_rpt.msg"

#############################################
## call the functions one by one TW report ##
#############################################

#getting shards for TW items
getShards TW;
  
if [ ! -s $tmp_dir/shards_for_${shard_type_name}_TW.txt ]; then
  echo "No shards under ${shard_type_name} to process report..." 1>&2
  exit 1
fi

#Pulling report for TW items from respective shard

cat $tmp_dir/shards_for_${shard_type_name}_TW.txt | \
while read line
do
  shard_index=$(echo ${line} | cut -d '|' -f 1 )
  shard_host=$(echo ${line}| cut -d '|' -f 2)
  shard_port=$(echo ${line}| cut -d '|' -f 3)
      
  getNewTWItemsRpt "${shard_index}" "${shard_host}" "${shard_port}";
  if [ test -s $tmp_dir/TW_item_create.csv ]; then
    echo "There are $(( `cat $tmp_dir/TW_item_create.csv | cut -d, -f3 | sort -u | wc -l | awk '{print $1}'` - 1)) new SHC Shippable item(s) created on ${reportDate}." >> "$tmp_dir/item_create_rpt.msg"
    printExecTime TW;
    exit 0
  else
    echo "There are no SHC Shippable item(s) created on ${reportDate}." >> "$tmp_dir/item_create_rpt.msg"
    printExecTime TW;
    exit 0
  fi
done

run_status="$(echo $?)"

# Removing temporary files
rm $tmp_dir/shards_for_*.txt $tmp_dir/item_create_temp*.csv

if [ "$run_status" == "0" ] && [ "$?" == "0" ]; then 
  exit 0
else 
  echo "Unknown Error." 1>&2
  exit 2
fi

#############################################
##              End of Script              ##
#############################################
