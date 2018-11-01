#! /bin/bash

st=$(date +%s)

# program name
prog_name=$(basename $0)

# path
tmp_dir="/var/batch/PROD_SUPPORT/bin/tmp"

# ACCOUNT DB host names
acct_db_host="db1"

# Shard type name
shard_type_name="catalog_shard"

#check if date is passed in $1, else use yesterday as report date
if [test -s $1]; then
  reportDate=$(date -d "yesterday" +%Y-%m-%d)
else
  reportDate=$1
fi

# initialize files
cat /dev/null > "$tmp_dir/item_publish_rpt.msg"
cat /dev/null > "$tmp_dir/item_publish.csv"
cat /dev/null > "$tmp_dir/TW_item_publish.csv"

# usage, this is not printed as of now :)

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
       WHERE UPPER(st.shard_type_name) = UPPER(\"${shard_type_name}\")
         AND s.shard_type_bit_value & st.shard_type_bit_value = st.shard_type_bit_value 
         AND s.shard_status = 1;
    "
       
    ${MYSQL_CMD} -h${acct_db_host} -e "${MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY}" | grep -v "shard_index" | \
      sed 's/[ \t]/|/g' > $tmp_dir/shards_for_${shard_type_name}_VD.txt 

    if [ "$?" != "0" ]; then
      echo "Getting Shards for ${shard_type_name} failed..." 1>&2
      # exit 1
    else
      echo "SHARD_HOSTS=$(cat $tmp_dir/shards_for_${shard_type_name}_VD.txt)"
    fi
  fi  # VD
     
  if [ "$1" == "TW" ]; then
    MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY="
      -- get shards for the shard_type
      SELECT s.shard_index,
             s.db_host,
             s.db_port
        FROM account.shard           s,
             account.shard_type      st,
             account.vendor_account  va
        WHERE UPPER(st.shard_type_name) = UPPER(\"${shard_type_name}\")
          AND s.shard_type_bit_value & st.shard_type_bit_value = st.shard_type_bit_value 
          AND s.shard_status = 1 
          AND s.shard_index  = va.catalog_shard_index
          AND va.account_id  = 0;   -- TW
    "
       
    ${MYSQL_CMD} -h${acct_db_host} -e "${MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY}" | grep -v "shard_index" | \
     sed 's/[ \t]/|/g' > $tmp_dir/shards_for_${shard_type_name}_TW.txt 
       
    if [ "$?" != "0" ]; then
      echo "Getting Shards for ${shard_type_name} failed..." 1>&2
      # exit 1
    else
      echo "SHARD_HOSTS=$(cat $tmp_dir/shards_for_${shard_type_name}_TW.txt)"
    fi
  fi  # TW
} 

######################################################################  
##      call mysql and get the new account_ids from item table      ##
######################################################################

function getNewAccountIds() {

  shard_index="$1"
  shard_host="$2" 
  shard_port="$3" 
   
  MYSQL_NEW_ACCOUNT_IDS_QUERY = "
    -- get account_ids for NEW products
    SELECT GROUP_CONCAT(DISTINCT il.account_id) AS account_id_list
      FROM catalog.item_log  il
     WHERE il.log_created_dtm BETWEEN \"${reportDate}\" AND ADDDATE(\"${reportDate}\", INTERVAL 1 DAY)
       AND il.catalog_status = 1    -- saved
       AND il.account_id    <> 0;   -- VD
   "

   NEW_ACCOUNT_IDS = $(${MYSQL_CMD} -h${shard_host} -e "${MYSQL_NEW_ACCOUNT_IDS_QUERY}" | grep -v "account_id_list")

   if [test "$?" != "0"]; then
     echo "Getting Account ids failed..." 1>&2
     # exit 1
   else
     echo "NEW_ACCOUNT_IDS=${NEW_ACCOUNT_IDS}"
   fi
}

######################################################################  
##         get account id and name query as set of unions           ##
######################################################################

function getAccountNameQuery() {

  MYSQL_GET_ACCOUNT_NAMES = "
  -- get account id and name
  SELECT a.account_id, 
         CONCAT('\'',a.account_name,'\'')
    FROM account.account  a
   WHERE a.account_id IN (${NEW_ACCOUNT_IDS});
   "

   NEW_ACCOUNT_NAMES_QUERY=$(${MYSQL_CMD} -h${acct_db_host} -e "${MYSQL_GET_ACCOUNT_NAMES}" | grep -v "account_id" |
                             awk 'BEGIN {FS="\t"};
                                 {print "SELECT " $1" AS account_id, " $2" AS account_name UNION"}
                                 END {print "SELECT "$1" AS account_id, " $2" AS account_name"}')
   if [test "$?" != "0"]; then
     echo "Getting Account names failed..." 1>&2
     # exit 1;
   else
     echo "NEW_ACCOUNT_NAMES_QUERY=${NEW_ACCOUNT_NAMES_QUERY}"
   fi
}

##############################################################################  
## call publish item report, insert the account name union query in between ##
##############################################################################

function getPublishItemsRpt() {

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
  # -> ${NEW_ACCOUNT_NAMES_QUERY} -> a.account_id, CONCAT('\'',a.account_name,'\'')
  getAccountNameQuery;
   
  MYSQL_PUB_ITEMS_RPT_QUERY = "
    SET @cnt = 0;

    SELECT (@cnt := @cnt + 1)  AS line_num,
           t.*
      FROM 
        (SELECT STRAIGHT_JOIN DISTINCT IFNULL(t.account_name, '') AS account_name,
                IFNULL(temp.item_id, '')                          AS item_id,
                IFNULL(temp.websku,  '')                          AS websku,
                IFNULL(CONCAT('\'',temp.pid,'\''), '')            AS pid,
                IFNULL(irt.item_relation_type_name, '')           AS item_type,
                IFNULL(temp.base1_pid, '')                        AS dummy_pid,
                IFNULL(temp.base1_websku, '')                     AS dummy_websku,
                IFNULL(CONCAT('\'',ci.upc,'\''), '')              AS upc,
                IFNULL(ci.name, '')                               AS item_title,
                IFNULL(cic.content_item_class_display_path, '')   AS content_item_class_display_path,
                IFNULL(SUBSTR(cic.content_item_class_display_path,
                       1,  
                       LOCATE('|',cic.content_item_class_display_path)-1), '') AS content_item_class_top,
                IFNULL(lsis.lookup_description, '')               AS seller_item_status,
                IFNULL(lcis.lookup_description, '')               AS catalog_status,
                IFNULL(temp.created_dtm,  '')                     AS created_dtm,
                IFNULL(temp.modified_dtm, '')                     AS modified_dtm
           FROM 
             (${NEW_ACCOUNT_NAMES_QUERY}
             )  t
             INNER JOIN         
               (SELECT IF(!(@iri = p.item_relation_id), 
                          @r := 1, 
                          @r := @r + 1
                         )                       AS rank,
                       -- Populating base pid for child items
                       IF(!(@iri = p.item_relation_id), 
                          @bp := NULL, 
                          @bp
                         )                       AS base1_pid,
                       -- Populating base websku for child items 
                       IF(!(@iri = p.item_relation_id),
                          @bs := NULL,
                          @bs
                         )                       AS base1_websku, 
                       -- Populating base item_id for child items and item_id for single items
                       IF(!(@iri = p.item_relation_id),
                          @bi := NULL,
                          (IF(p.relation_type_mask > 1,
                              @bi,
                              p.item_id
                             )
                          )
                         )                       AS base_item_id, 
                       -- Populating base relation_type_mask for child items and relation_type_mask for single items
                       IF(!(@iri = p.item_relation_id),
                          @bm := NULL,
                          (IF(p.relation_type_mask > 1,
                              @bm,
                              p.relation_type_mask
                             )
                           )
                         )                       AS base_mask, 
                       -- Session variables
                       @iri := p.item_relation_id,
                       IFNULL(@bp, @bp := p.base_pid),
                       IFNULL(@bs, @bs := p.base_websku),
                       IFNULL(@bi, @bi := p.base_item_id),
                       IFNULL(@bm, @bm := p.relation_type_mask),
                       -- Populating status for active and inactive items               
                       IF(p.relation_type_mask > 1,
                          p.item_relation_status,
                          p.seller_item_status
                         )                       AS item_relation_status,
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
                       p.catalog_status 
                       p.created_dtm,
                       p.modified_dtm 
                  FROM 
                    (SELECT @r  := 0,
                            @iri:= NULL,
                            @bp := NULL,
                            @bs := NULL,
                            @bi := NULL,
                            @bm := NULL
                    )  ses,
                    (SELECT i.item_id,
                            i.websku,
                            i.pid,
                            i.dummy_item_flag,
                            IF(i.dummy_item_flag = 1,
                               i.pid,
                               NULL
                              )             AS base_pid,
                            IF(i.dummy_item_flag = 1,
                               i.websku,
                               NULL
                              )             AS base_websku,
                            IF((i.relation_type_mask = 1 AND ird.status = 0),
                               NULL,
                               IFNULL(ird.item_relation_id, ir.item_relation_id)
                              )             AS item_relation_id,
                            -- Populating parent and child item status
                            IFNULL(IF((i.dummy_item_flag = 1 AND ird.status = 0),
                                      ir.status, 
                                      ird.status
                                     ),
                                   ir.status
                                  )          AS item_relation_status,
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
                       FROM catalog.item                               i
                         LEFT OUTER JOIN catalog.item_relation_detail  ird 
                           ON i.item_id = ird.item_id
                         LEFT OUTER JOIN catalog.item_relation         ir
                           ON i.item_id = ir.base_item_id
                      ORDER BY item_relation_id, i.dummy_item_flag DESC
                    )  p
                  )  temp
                ON t.account_id = temp.account_id
                  AND temp.account_id <> 0        -- VD
               INNER JOIN 
                 (SELECT DISTINCT il.item_id
                    FROM catalog.item_log il
                   WHERE il.log_created_dtm BETWEEN \"${reportDate}\"  AND ADDDATE(\"${reportDate}\" , INTERVAL 1 DAY)
                     AND il.catalog_status = 1 -- for saved
                 )
             ) it 
              ON temp.item_id = it.item_id
        INNER JOIN static_content.lookup                 lsis
          ON temp.seller_item_status = lsis.lookup_value
            AND lsis.lookup_type_id  = 19         -- seller_status
            AND lsis.lookup_value    = 1          -- active
        INNER JOIN static_content.lookup                 lcis
          ON temp.catalog_status    = lcis.lookup_value
            AND lcis.lookup_type_id = 18          -- catalog_status
            AND lcis.lookup_value   = 2           -- published 
        INNER JOIN semistatic_content.content_item_class cic
          ON temp.content_item_class_id = cic.content_item_class_id
        INNER JOIN catalog.content_item                  ci
          ON temp.content_item_id       = ci.content_item_id
        INNER JOIN static_content.item_relation_type     irt
          ON temp.base_mask = irt.bit_value & temp.base_mask
   WHERE temp.item_relation_status <> 0             -- inactive item filter
   ORDER BY 1, 2, 3
    ) t;
   "

  ${MYSQL_CMD} -h${shard_host} -P${shard_port} -e "${MYSQL_PUB_ITEMS_RPT_QUERY}" | 
   sed 's/"/""/g;s/\t/","/g;s/^/"/;s/$/"/;s/\n//g' > $tmp_dir/item_publish_temp_${shard_index}.csv
  if [test "$?" != "0"]; then
    echo "Getting New Items Report failed..." 1>&2
    # exit 1
  else
    echo "RPT_QUERY=${MYSQL_PUB_ITEMS_RPT_QUERY}"
    echo "Report generation success."
  fi
}

########################################
##    fetching TW published items     ##
########################################

function getTWPublish_Report(){

  shard_index="$1"
  shard_host="$2"
  shard_port="$3"
  
  MYSQL_PUB_TW_ITEMS_RPT_QUERY = "
   SELECT STRAIGHT_JOIN DISTINCT 'SHC'            AS account_name,
          IFNULL(temp.item_id, '')                AS item_id,
          IFNULL(temp.websku,  '')                AS websku,
          IFNULL(CONCAT('\'',temp.pid,'\''),  '') AS pid,
          IFNULL(irt.item_relation_type_name, '') AS item_type,
          IFNULL(temp.base1_pid, '')              AS dummy_pid,
          IFNULL(temp.base1_websku, '')           AS dummy_websku,
          IFNULL(CONCAT('\'',ci.upc,'\''), '')    AS upc,
          IFNULL(ci.name, '')                     AS item_title,
          IFNULL(cic.content_item_class_display_path,'') AS content_item_class_display_path,
          IFNULL(SUBSTR(cic.content_item_class_display_path,
                 1, 
                 LOCATE('|',cic.content_item_class_display_path)-1), '')     AS content_item_class_top,
          IFNULL(sh.store_hierarchy_display_path, '')                        AS hierarchy,
          IFNULL(SUBSTRING_INDEX(sh.store_hierarchy_display_path,'|',1), '') AS division_name,
          IFNULL(temp.shc_division_nbr,   '')    AS division_nbr,
          IFNULL(lsis.lookup_description, '')    AS seller_item_status,
          IFNULL(lcis.lookup_description, '')    AS catalog_status,
          IFNULL(CASE ci.enrichment_status WHEN 2 THEN 'Enriched' 
                                           WHEN 1 THEN 'Needs Enrichment' 
                 END, 
                 ''
                )                                AS enrichment_status,
          IFNULL(temp.created_dtm,  '')          AS created_dtm,
          IFNULL(temp.modified_dtm, '')          AS modified_dtm
     FROM 
       (SELECT DISTINCT il.item_id
          FROM catalog.item_log  il
         WHERE il.log_created_dtm BETWEEN \"${reportDate}\" AND ADDDATE(\"${reportDate}\" , INTERVAL 1 DAY)
           AND il.catalog_status IN (1, 4, 5)      -- for saved, new and excluded CATALOG status
       ) it
       INNER JOIN 
       (SELECT IF(!(@iri = p.item_relation_id),
                  @r := 1,
                  @r := @r + 1) AS rank,
               -- Populating BASE PID for child items
               IF(!(@iri = p.item_relation_id),
                  @bp := NULL,
                  @bp
                 )              AS base1_pid,
               -- Populating BASE WEBSKU for child items 
               IF(!(@iri = p.item_relation_id),
                  @bs := NULL,
                  @bs
                 )              AS base1_websku, 
               -- Populating BASE ITEM_ID for child items and item_id for single items
               IF(!(@iri = p.item_relation_id),
                  @bi := NULL,
                  (IF(p.relation_type_mask > 1,
                      @bi,
                      p.item_id
                     )
                   )
                 )             AS base_item_id, 
               -- Populating BASE RELATION_TYPE_MASK for child items and relation_type_mask for single items
               IF(!(@iri = p.item_relation_id),
                  @bm := NULL,
                  (IF(p.relation_type_mask > 1,
                      @bm,
                      p.relation_type_mask
                     )
                   )
                 )             AS base_mask, 
               -- Session variables
               @iri := p.item_relation_id,
               IFNULL(@bp, @bp := p.base_pid),
               IFNULL(@bs, @bs := p.base_websku),
               IFNULL(@bi, @bi := p.base_item_id),
               IFNULL(@bm, @bm := p.relation_type_mask),
               -- Populating STATUS for active and inactive items               
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
               p.modified_dtm, 
               p.shc_division_nbr,
               p.shc_hierarchy_id
          FROM 
            (SELECT @r   :=0,
                    @iri := NULL,
                    @bp  := NULL,
                    @bs  := NULL,
                    @bi  := NULL,
                    @bm  := NULL
            )  ses,
            (SELECT i.item_id,
                    i.websku, 
                    i.pid,
                    i.dummy_item_flag,
                    IF(i.dummy_item_flag = 1,
                       i.pid,
                       NULL
                      )                  AS base_pid,
                    IF(i.dummy_item_flag = 1,
                       i.websku,
                       NULL
                      )                  AS base_websku,
                    -- Populating the item relation id
                    IF((i.relation_type_mask = 1 AND ird.status=0),
                        NULL,
                        IFNULL(ird.item_relation_id,
                               ir.item_relation_id
                               )
                      )                  AS item_relation_id
                    -- Populating parent and child item status
                    IFNULL(IF((i.dummy_item_flag = 1 AND ird.status = 0),
                               ir.status,
                               ird.status
                             ),
                             ir.status
                          )              AS item_relation_status
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
                    i.modified_dtm,
                    i.shc_division_nbr,
                    i.shc_hierarchy_id
               FROM catalog.item                              i
                 LEFT OUTER JOIN catalog.item_relation_detail ird 
                   ON i.item_id = ird.item_id
                 LEFT OUTER JOIN catalog.item_relation        ir
                   ON i.item_id = ir.base_item_id
              ORDER BY item_relation_id, i.dummy_item_flag DESC  
            )  p
       )  temp
         ON temp.item_id = it.item_id
       INNER JOIN static_content.lookup      lsis
         ON temp.seller_item_status = lsis.lookup_value
           AND lsis.lookup_type_id  = 19             -- seller_status
           AND lsis.lookup_value    = 1              -- active 
       INNER JOIN static_content.lookup      lcis
         ON temp.catalog_status = lcis.lookup_value  
           AND lcis.lookup_type_id = 18             -- catalog_status
           AND lcis.lookup_value   = 2              -- published
       INNER JOIN semistatic_content.content_item_class cic
         ON temp.content_item_class_id = cic.content_item_class_id
           AND cic.status = 1
       INNER JOIN catalog.content_item                  ci
         ON temp.content_item_id = ci.content_item_id
           AND ci.status = 1
       INNER JOIN semistatic_content.store_hierarchy    sh
         ON temp.shc_hierarchy_id = sh.store_hierarchy_id
           AND sh.store_id = 1
           AND sh.status   = 1
       INNER JOIN static_content.item_relation_type     irt
         ON temp.base_mask = irt.bit_value & temp.base_mask
   WHERE temp.account_id       = 0               -- TW
     AND temp.account_type     = 1               -- const
     AND temp.catalog_status   = 2               -- published
     AND temp.fulfillment_type = 3               -- FBS
     AND temp.item_relation_status <> 0          -- inactive item filter
   ORDER BY 2, 3; "

   ${MYSQL_CMD} -h${shard_host} -P${shard_port} -e "${MYSQL_PUB_TW_ITEMS_RPT_QUERY}" | 
    sed 's/"/""/g;s/\t/","/g;s/^/"/;s/$/"/;s/\n//g' > $tmp_dir/TW_item_publish.csv
  if [ test "$?" != "0" ]; then
    echo "Getting Published SHC Shippable Items Report failed..." 1>&2
    exit 1
  else
    echo "RPT_QUERY=${MYSQL_PUB_TW_ITEMS_RPT_QUERY}"
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
    echo " " >> "$tmp_dir/item_publish_rpt.msg"
    Time="Execution Time: "$mins" mins, "$secs" secs"
    echo $Time >> "$tmp_dir/item_publish_rpt.msg"
    cat "$tmp_dir/item_publish_rpt.msg";
  else
    echo " " >> "$tmp_dir/item_publish_rpt.msg"
    Time="Execution Time: "$mins" mins, "$secs" secs"
    echo $Time >> "$tmp_dir/item_publish_rpt.msg"
    cat "$tmp_dir/item_publish_rpt.msg";
  fi
}

# print messages to the msg file

echo "Getting Report for ${reportDate}..."
echo "Published Items Reports" >> "$tmp_dir/item_publish_rpt.msg"
echo "----------------------------">> "$tmp_dir/item_publish_rpt.msg"
echo "Report for ${reportDate} is attached." >> "$tmp_dir/item_publish_rpt.msg"
echo " " >> "$tmp_dir/item_publish_rpt.msg"

#############################################  
## call the functions one by one VD report ##
#############################################

# Getting Shards for VD Items
getShards VD;

if [ ! -s $tmp_dir/shards_for_${shard_type_name}_VD.txt ]; then
  echo "No shards under ${shard_type_name} to process report..." 1>&2
  exit 1
else 
  shard_count="$(cat $tmp_dir/shards_for_${shard_type_name}_VD.txt | wc -l)"
  count=0
fi

# Pulling report for VD Items from respective shard

cat $tmp_dir/shards_for_${shard_type_name}_VD.txt | \
while read line
do
  shard_index=$(echo ${line} | cut -d '|' -f 1 )
  shard_host=$(echo ${line}| cut -d '|' -f 2)
  shard_port=$(echo ${line}| cut -d '|' -f 3)
  
  getPublishItemsRpt "${shard_index}" "${shard_host}" "${shard_port}";
  fetch_status="$(echo $?)"
  if [ "$fetch_status" == "2" ]; then 
    count=$((count + 1))
    if [ "$count" == "$shard_count" ]; then
      echo "No data found..."
    fi
  elif [ "$fetch_status" == "0" ];then
    if [ -s $tmp_dir/item_publish.csv ]; then
      tail -n +2 $tmp_dir/item_publish_temp_${shard_index}.csv >> $tmp_dir/item_publish.csv
    else
      cat $tmp_dir/item_publish_temp_${shard_index}.csv > $tmp_dir/item_publish.csv
    fi
  fi
done

if [ test -s $tmp_dir/item_publish.csv ]; then
  echo "There are $(( `cat $tmp_dir/item_publish.csv | cut -d, -f3 | sort -u | wc -l | awk '{print $1}'` - 1)) VD item(s) published on ${reportDate}." >> "$tmp_dir/item_publish_rpt.msg"
  printExecTime VD;
  # exit 0
else
  echo "VD Report generation failed..." 1>&2
  echo "There are no VD item(s) published on ${reportDate}." >> "$tmp_dir/item_publish_rpt.msg"
  printExecTime VD;     
  #  exit 1
fi

# Print messages to the msg file

echo " " >> "$tmp_dir/item_publish_rpt.msg"

#############################################
## call the functions one by one TW report ##
#############################################

# Getting shards for TW Items
getShards TW;
  
if [ ! -s $tmp_dir/shards_for_${shard_type_name}_TW.txt ]; then
  echo "No shards under ${shard_type_name} to process report..." 1>&2
  exit 1
fi

# Pulling report for TW Items from respective shard

cat $tmp_dir/shards_for_${shard_type_name}_TW.txt | \
while read line
do
  shard_index=$(echo ${line} | cut -d '|' -f 1 )
  shard_host=$(echo ${line}| cut -d '|' -f 2)
  shard_port=$(echo ${line}| cut -d '|' -f 3)
      
  getTWPublish_Report "${shard_index}" "${shard_host}" "${shard_port}";
  
  if [ test -s $tmp_dir/TW_item_publish.csv ]; then
    echo "There are $(( `cat $tmp_dir/TW_item_publish.csv | cut -d, -f2 | sort -u | wc -l | awk '{print $1}'` - 1)) SHC Shippable item(s) published on ${reportDate}." >> "$tmp_dir/item_publish_rpt.msg"
    printExecTime TW;
    exit 0
  else
    echo "There are no SHC Shippable item(s) published on ${reportDate}." >> "$tmp_dir/item_publish_rpt.msg"
    printExecTime TW;
    exit 0
  fi
done

run_status="$(echo $?)"

# Removing temporary files
rm $tmp_dir/shards_for_*.txt $tmp_dir/item_publish_temp*.csv

if [ "$run_status" == "0" ] && [ "$?" == "0" ]; then 
  exit 0
else 
  echo "Unknown Error." 1>&2
  exit 2
fi

#############################################
##              End of Script              ##
#############################################
