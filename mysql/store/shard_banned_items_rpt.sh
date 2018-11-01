#! /bin/bash
st=$(date +%s)

##################################################
##       Script to report banned items          ##
##################################################

rootDir=$(dirname $0)
PRGNAME=$(basename $0 .sh)

# paths
TMPDIR="/var/batch/PROD_SUPPORT/bin/tmp/$PRGNAME"

#create temporary working directory if not exists
mkdir -p $TMPDIR
find $TMPDIR -type f -delete

reportDate="$(date '+%Y-%m-%d')"

# dB host names
acctDBhost="db1"

# initialize files
cat /dev/null > "$TMPDIR/$PRGNAME.msg"
cat /dev/null > "$TMPDIR/banned_items_vd.csv"
cat /dev/null > "$TMPDIR/banned_items_tw.csv"

# mysql command.
# !!! DO NOT GIVE -v OPTION, SCRIPT WILL NOT WORK !!!
MYSQL_CMD="/usr/bin/mysql -user -password"

#shard type name
shard_type_name="catalog_shard"

####################################################################################################
## function getShards call mysql and get the shards for the shard_type from account.account table ##
####################################################################################################

function getShards() {

  if [ "$1" == "VD" ]; then
    MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY="
      -- get shards for the shard_type
      SELECT s.shard_index,
             s.db_host,
             s.db_port
        FROM account.shard       s,
             account.shard_type  st
       WHERE UPPER(st.shard_type_name) = UPPER(\"${shard_type_name}\")
         AND s.shard_type_bit_value & st.shard_type_bit_value = st.shard_type_bit_value
         AND s.shard_status = 1;
    "

    ${MYSQL_CMD} -h${acctDBhost} -e "${MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY}" | grep -v "shard_index" | \
                                     sed 's/[ \t]/|/g' > $TMPDIR/shards_for_${shard_type_name}_VD.txt

    if [ "$?" != "0" ]; then
      echo "Getting Shards for ${shard_type_name} failed..." 1>&2
      # exit 1
    else
      echo -e "\n VD SHARD_HOSTS=$(cat $TMPDIR/shards_for_${shard_type_name}_VD.txt)"
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

    ${MYSQL_CMD} -h${acctDBhost} -e "${MYSQL_SHARDS_FROM_SHARD_TYPE_QUERY}" | grep -v "shard_index" | \
                                     sed 's/[ \t]/|/g' > $TMPDIR/shards_for_${shard_type_name}_TW.txt

    if [ "$?" != "0" ]; then
      echo "Getting Shards for ${shard_type_name} failed..." 1>&2
      # exit 1
    else
      echo -e "\n TW SHARD_HOSTS=$(cat $TMPDIR/shards_for_${shard_type_name}_TW.txt)"
    fi
  fi
}

#############################################################################################
##      function getAccountIds call mysql and get the account_ids from item table          ##
#############################################################################################

function getAccountIds() {

  shard_index="$1"
  shard_host="$2"
  shard_port="$3"

  MYSQL_ACCOUNTIDS_QUERY="
    -- get account_ids for new products
    SELECT DISTINCT i.account_id  AS account_ids
      FROM catalog.item  i
     WHERE i.account_id <> 0;
  "

  ACCOUNT_IDS=$(${MYSQL_CMD} -h${shard_host} -e "${MYSQL_ACCOUNTIDS_QUERY}" | grep -v "account_ids" | tr -s '\n' ',' | sed 's/\(.*\),$/\1/')
  if test "$?" != "0"
    then
      echo "Getting Account ids failed..." 1>&2
      # exit 1
    else
     echo "Getting Account ids Success..." 1>&2
  fi
}


###############################################################################################
##     function getAccountNameQuery account account id and name query as set of unions       ##
###############################################################################################

function getAccountNameQuery() {

  MYSQL_GET_ACCOUNT_NAMES="
    -- get account id and name
    SELECT a.account_id, 
           CONCAT('\'',a.account_name,'\'')
      FROM account.account a
     WHERE a.account_id IN ( ${ACCOUNT_IDS} );
   "

   ACCOUNT_NAMES_QUERY=$(${MYSQL_CMD} -h${acctDBhost} -e "${MYSQL_GET_ACCOUNT_NAMES}" | grep -v "account_id" |
                         awk 'BEGIN {FS="\t"};
                                    {print "SELECT " $1" AS account_id, " $2" AS account_name UNION"}
                              END {print "SELECT "$1" AS account_id, " $2" AS account_name"}')

  if test "$?" != "0"
    then
      echo "Getting VD Account names failed..." 1>&2
      exit 1;
    else
     echo "ACCOUNT_NAMES_QUERY=${ACCOUNT_NAMES_QUERY}"
  fi
}

######################################################################
##          function getBannedItemsVD to pull VD items              ##
######################################################################

function getBannedItemsVD() {

  shard_index="$1"
  shard_host="$2"
  shard_port="$3"

  echo " "
  echo "Generating report for VD items from ${shard_host} shard..."
  getAccountIds "${shard_index}" "${shard_host}" "${shard_port}";
  if [ "${NEW_ACCOUNTIDS}" == "NULL" ]
    then
     return 2
  fi

  #call getAccountNameQuery to get account names
  getAccountNameQuery;

  MYSQL_BANNED_ITEMS_RPT_QUERY="
    SELECT DISTINCT t.account_name,
           IFNULL(SUBSTRING_INDEX(store_hierarchy_display_path, '|', 1),'')  'shc_div_name',
           IFNULL(i.shc_division_nbr,'')         shc_division_nbr,
           i.item_id,
           IFNULL(CONCAT('\'',i.pid,'\''),'')    pid,
           IFNULL(CONCAT('\'',i.websku,'\''),'') websku,
           IFNULL(CONCAT('\'',ci.upc,'\''),'')   upc,
           CONCAT('\'',t2.ban_rule_name,'\'')   'ban_description',
           CASE i.catalog_status WHEN 0 THEN 'Rejected'
                                 WHEN 1 THEN 'Saved'
                                 WHEN 2 THEN 'Published'
                                 WHEN 3 THEN 'Ima_pending'
                                 WHEN 4 THEN 'New'
                                 WHEN 5 THEN 'Excluded'
           END                                  'catalog_status',
           IF(ci.enrichment_status = 2,
              'Enriched',
              'Needs Enrichment'
             )                                  'enrichment_status',
           IFNULL(i.created_dtm, '')            'item_created_dtm',
           IFNULL(i.modified_dtm, '')           'item_modified_dtm'
      FROM 
        (${ACCOUNT_NAMES_QUERY}
        )  t,
        (SELECT DISTINCT t1.item_id,
                GROUP_CONCAT(DISTINCT t1.ban_rule_name ORDER BY ban_rule_name SEPARATOR ', ') ban_rule_name
           FROM 
             (SELECT ibr.item_id, 
                     br.ban_rule_name
                FROM catalog.item_ban_rule       ibr,
                     semistatic_content.ban_rule br
               WHERE ibr.ban_rule_id = br.ban_rule_id
                 AND ibr.status = 1
              UNION
              SELECT isb.item_id,
                     'Item level ban' ban_rule_name
                FROM catalog.item_sticky_ban_list isb
               WHERE sticky_ban_state = 1
             ) t1
             GROUP BY item_id 
        )  t2,
        catalog.item i
        LEFT OUTER JOIN semistatic_content.store_hierarchy sh 
          ON i.shc_hierarchy_id = sh.store_hierarchy_id 
           AND sh.status = 1
        catalog.content_item ci
    WHERE t.account_id      = i.account_id
      AND i.content_item_id = ci.content_item_id
      AND t2.item_id        = i.item_id
      AND i.seller_item_status = 1
   GROUP BY i.account_id, i.shc_division_nbr, item_id
  ORDER BY 1,2,4;
  "
  ${MYSQL_CMD} -h${shard_host} -P${shard_port} -e "${MYSQL_BANNED_ITEMS_RPT_QUERY}" | sed 's/"/""/g;s/\t/","/g;s/^/"/;s/$/"/;s/\n//g' > $TMPDIR/banned_items_temp_${shard_index}.csv
  if test "$?" != "0"
    then
      echo "Getting VD Items Report failed for ${shard_host} shard..." 1>&2
      exit 1
    else
      echo "VD Report generation success for ${shard_host} shard." 1>&2
  fi
}

######################################################################
##        function getBannedItemsTW to pull TW items                ##
######################################################################

function getBannedItemsTW() {

  shard_index="$1"
  shard_host="$2"
  shard_port="$3"

  echo " "
  echo "Generating report for TW items from ${shard_host} shard..."

  MYSQL_BANNED_ITEMS_RPT_QUERY="
    SELECT DISTINCT 'SHC' AS account_name,
           IFNULL(SUBSTRING_INDEX(store_hierarchy_display_path, '|', 1),'')  AS shc_div_name,
           IFNULL(i.shc_division_nbr,'') shc_division_nbr,
           i.item_id,
           IFNULL(CONCAT('\'',i.pid,'\''),'')    pid,
           IFNULL(CONCAT('\'',i.websku,'\''),'') websku,
           IFNULL(CONCAT('\'',ci.upc,'\''),'')   upc,
           CONCAT('\'',T2.ban_rule_name,'\'')    'ban_description',
           CASE i.catalog_status WHEN 0 THEN 'Rejected'
                                 WHEN 1 THEN 'Saved'
                                 WHEN 2 THEN 'Published'
                                 WHEN 3 THEN 'Ima_pending'
                                 WHEN 4 THEN 'New'
                                 WHEN 5 THEN 'Excluded'
           END  'catalog_status',
           IF(ci.enrichment_status = 2,
              'Enriched',
              'Needs Enrichment'
             )                            'enrichment_status',
           IFNULL(i.created_dtm, '')      'item_created_dtm',
           IFNULL(i.modified_dtm, '')     'item_modified_dtm'
      FROM 
         (SELECT DISTINCT t1.item_id,
                 GROUP_CONCAT(DISTINCT t1.ban_rule_name ORDER BY ban_rule_name SEPARATOR ', ') ban_rule_name
            FROM 
              (SELECT ibr.item_id, 
                      br.ban_rule_name
                 FROM catalog.item_ban_rule ibr,
                      semistatic_content.ban_rule br
                WHERE ibr.ban_rule_id = br.ban_rule_id
                  AND ibr.status=1
               UNION
               SELECT isb.item_id,
                      'Item level ban'  ban_rule_name
                 FROM catalog.item_sticky_ban_list isb
                WHERE sticky_ban_state = 1
              ) t1
              GROUP BY item_id 
         )  t2,
         catalog.item i
         LEFT OUTER JOIN semistatic_content.store_hierarchy sh 
           ON i.shc_hierarchy_id = sh.store_hierarchy_id 
             AND sh.status = 1,
         catalog.content_item ci
      WHERE i.content_item_id    = ci.content_item_id
        AND i.item_id            = t2.item_id
        AND i.seller_item_status = 1
        AND i.account_id         = 0
    GROUP BY i.shc_division_nbr, i.item_id
    ORDER BY 1, 2, 4;
  "

  ${MYSQL_CMD} -h${shard_host} -P${shard_port} -e "${MYSQL_BANNED_ITEMS_RPT_QUERY}" | sed 's/"/""/g;s/\t/","/g;s/^/"/;s/$/"/;s/\n//g' > $TMPDIR/banned_items_tw.csv
  if test "$?" != "0"
    then
      echo "Getting TW Items Report failed for ${shard_host} shard..." 1>&2
      exit 1
    else
      echo "TW Report generation success for ${shard_host} shard." 1>&2
  fi
}

########################################
##    calculate time of execution     ##
########################################

function printExecTime() {

  if test $1 == "VD"
   then
     vdt=$(date +%s)
     mins=$(( ($vdt-$st) / 60 ))
     secs=$(( ($vdt-$st) % 60 ))
     echo " " >> "$TMPDIR/$PRGNAME.msg"
     Time="Execution Time: "$mins" mins, "$secs" secs"
     echo $Time >> "$TMPDIR/$PRGNAME.msg"
     cat "$TMPDIR/$PRGNAME.msg";
  else
    twt=$(date +%s)
    mins=$(( ($twt-$vdt) / 60 ))
    secs=$(( ($twt-$vdt) % 60 ))
    echo " " >> "$TMPDIR/$PRGNAME.msg"
    Time="Execution Time: "$mins" mins, "$secs" secs"
    echo $Time >> "$TMPDIR/$PRGNAME.msg"
    cat "$TMPDIR/$PRGNAME.msg";
  fi
}

#################################################################
##        function zip_results to zip items report             ##
#################################################################
function zip_results() {
  if test -n "$(ls ${TMPDIR}/*.csv 2>/dev/null)"; then
    zip "${TMPDIR}/${PRGNAME}.zip" "${TMPDIR}/"*.csv >/dev/null 2>&1;
  fi
  [ "$?" == "0"  ] || return 2
}

# print messages to the msg file
echo "Getting Report for ${reportDate}..."
echo "Banned Items Report" >> "$TMPDIR/$PRGNAME.msg"
echo "-------------------------">> "$TMPDIR/$PRGNAME.msg"
echo "Reports for ${reportDate} is attached." >> "$TMPDIR/$PRGNAME.msg"
echo " " >> "$TMPDIR/$PRGNAME.msg"

#################################################################
##   call the functions one by one to report VD banned items   ##
#################################################################

#getting shards for VD items
getShards VD;

if [ ! -s $TMPDIR/shards_for_${shard_type_name}_VD.txt ]; then
  echo "No shards under ${shard_type_name} to process VD report..." 1>&2
  exit 1
else
  shard_count="$(cat $TMPDIR/shards_for_${shard_type_name}_VD.txt | wc -l)"
  count=0
fi

#Pulling report for VD items from respective shard

for line in "$(cat $TMPDIR/shards_for_${shard_type_name}_VD.txt)"
do
  shard_index=$(echo ${line} | cut -d '|' -f 1 )
  shard_host=$(echo ${line} | cut -d '|' -f 2)
  shard_port=$(echo ${line} | cut -d '|' -f 3)

  getBannedItemsVD "${shard_index}" "${shard_host}" "${shard_port}";
  fetch_status="$(echo $?)"
  if [ "$fetch_status" == "2" ]; then
    count=$((count + 1))
    if [ "$count" == "$shard_count" ]; then
      echo "No data found..."
    fi
  elif [ "$fetch_status" == "0" ];then
    if [ -s $TMPDIR/banned_items_vd.csv ];then
       tail -n +2 $TMPDIR/banned_items_temp_${shard_index}.csv >> $TMPDIR/banned_items_vd.csv
    else
       cat $TMPDIR/banned_items_temp_${shard_index}.csv > $TMPDIR/banned_items_vd.csv
    fi
  fi
done

if test -s $TMPDIR/banned_items_vd.csv
  then
    echo "There are $(( `cat $TMPDIR/banned_items_vd.csv | cut -d, -f4 | sort -u | wc -l | awk '{print $1}'` - 1)) Banned VD item(s)." >> "$TMPDIR/$PRGNAME.msg"
    printExecTime VD;
    # exit 0
  else
    echo "VD Report generation failed..." 1>&2
    echo "There are no Banned VD item(s)." >> "$TMPDIR/$PRGNAME.msg"
    printExecTime VD;
    #  exit 1
fi

# print messages to the msg file
echo " " >> "$TMPDIR/$PRGNAME.msg"

##########################################################
##   call the functions one by one to report TW items   ##
##########################################################

#getting shards for TW items
getShards TW;

if [ ! -s $TMPDIR/shards_for_${shard_type_name}_TW.txt ]; then
  echo "No shards under ${shard_type_name} to process TW report..." 1>&2
  exit 1
fi

#Pulling report for TW items from respective shard
for line in "$(cat $TMPDIR/shards_for_${shard_type_name}_TW.txt)"
do
  shard_index=$(echo ${line} | cut -d '|' -f 1 )
  shard_host=$(echo ${line} | cut -d '|' -f 2)
  shard_port=$(echo ${line} | cut -d '|' -f 3)

  getBannedItemsTW "${shard_index}" "${shard_host}" "${shard_port}";
  if test -s $TMPDIR/banned_items_tw.csv
    then
      echo "There are $(( `cat $TMPDIR/banned_items_tw.csv | cut -d, -f4 | sort -u | wc -l | awk '{print $1}'` - 1)) Banned SHC Shippable item(s)." >> "$TMPDIR/$PRGNAME.msg"
      printExecTime TW;
      #exit 0
    else
      echo "There are no Banned SHC Shippable item(s)." >> "$TMPDIR/$PRGNAME.msg"
      printExecTime TW;
      #exit 0
  fi
done

run_status="$(echo $?)"

#removing temporary files
rm $TMPDIR/shards_for_*.txt $TMPDIR/banned_items_temp_*.csv

#call function zip_results to zip results
[ "$run_status" == "0" ] && zip_results || (echo "Error in generating report..." && exit 2)
zip_status="$(echo $?)"

if [ "$?" == "0" ] && [ "$zip_status" == "0" ]; then
  exit 0
else
  echo "Unknown Error." 1>&2
  exit 2
fi

#############################################
##              End of Script              ##
#############################################
