#! /bin/bash

prgName=$(basename $0 .sh)

# paths
catalogDBhost="db_c1.s.com"
acctDBhost="db_a1.s.com"
tmpdir="/var/batch/PROD_SUPPORT/bin/tmp"
#tmpdir="/home/user2/offshore/user"

#catalogDBhost="0.0.0.0"
#acctDBhost="0.0.0.0"

# initialize files
cat /dev/null > "$tmpdir/$prgName.msg"
cat /dev/null > "$tmpdir/$prgName.csv"

# mysql command.
# !!! DO NOT GIVE -v OPTION, SCRIPT WILL NOT WORK !!!
MYSQL_CMD="/usr/bin/mysql -user -password"

reportDate=$(date)

# -------------------------------------
# getAccountId
# -------------------------------------
function getAccountId() {

  MYSQL_GET_ACCOUNT_ID="
    SELECT GROUP_CONCAT(DISTINCT i.account_id) AS account_ids
      FROM catalog.item                i,
           catalog.item_vendor_package ivp
     WHERE i.item_id  = ivp.item_id
       AND ivp.status = 1
       AND ivp.ima_exchange_status = 2;"

  ACCOUNT_IDS=$(${MYSQL_CMD} -h${catalogDBhost} -e "${MYSQL_GET_ACCOUNT_ID}" | grep -v "account_ids")

  if test "$?" != "0"
    then
      echo "Getting Account ids failed..." 1>&2
      exit 1
  else
    echo "ACCOUNT_IDS=${account_ids}"
  fi
}

# -------------------------------------
# getAccountNameQuery
# -------------------------------------
function getAccountNameQuery() {

  MYSQL_GET_ACCOUNT_NAMES="
  -- get account id and name
  SELECT a.account_id, 
         CONCAT('\'',a.account_name,'\'')
    FROM account.account  a
   WHERE a.account_id IN (${ACCOUNT_IDS});"

  NEW_ACCOUNT_NAMES_QUERY = $(${MYSQL_CMD} -h${acctDBhost} -e "${MYSQL_GET_ACCOUNT_NAMES}" | grep -v "account_id" |
                            awk 'BEGIN {FS="\t"};
                                 {print "SELECT " $1" AS account_id, " $2" AS account_name UNION"}
                                 END {print "SELECT "$1" AS account_id, " $2" AS account_name"}')
  if test "$?" != "0"
    then
      echo "Getting VD Account names failed..." 1>&2
      exit 1;
  fi
  echo "NEW_ACCOUNT_NAMES_QUERY=${NEW_ACCOUNT_NAMES_QUERY}"
}

# -------------------------------------
# getItemReport
# -------------------------------------
function getItemReport() {

  QUERY_THRESHOLD="
    SELECT pv.profile_term_value/86400
      FROM semistatic_content.profile_value pv,
           semistatic_content.profile       p
     WHERE pv.profile_term_type = 'IMA_PENDING_THRESHOLD'
       AND p.profile_name       = 'INTERNAL_SETTINGS'
       AND p.profile_id         = pv.profile_id;"

  threshold_limit=`${MYSQL_CMD} -h${catalogDBhost} -e "${QUERY_THRESHOLD}" | tail -n +2`
  echo "Genearting report for items in ima_pending_status for more than threshold($threshold_limit days) limit..."

  getAccountId;
  getAccountNameQuery;

  QUERY="
    SELECT t.account_name,
           tmp.account_id,
           tmp.content_item_class_display_path,
           tmp.upc,
           tmp.item_vendor_package_id,
           tmp.site_name,
           (DATEDIFF(NOW(), tmp.latest_modification_dtm)) AS number_of_days_in_ima_pending
      FROM 
        (${NEW_ACCOUNT_NAMES_QUERY}
        ) AS t,
        (SELECT i.account_id,
                i.item_id,
                cic.content_item_class_display_path,
                ci.upc,
                ivp.item_vendor_package_id,
                s.site_name,
                 ivp.ima_timestamp,
                ivp.modified_dtm
                IF((IFNULL(ivp.ima_timestamp,'')) > (IFNULL(ivp.modified_dtm,'')),
                    ivp.ima_timestamp,
                    ivp.modified_dtm
                  )     AS latest_modification_dtm
          FROM catalog.item i,
               catalog.content_item ci,
               catalog.item_vendor_package ivp,
               static_content.site s,
               semistatic_content.content_item_class cic
         WHERE i.account_id <> 0
           AND i.content_item_id = ci.content_item_id
           AND i.item_id = ivp.item_id
           AND ivp.store_id = s.site_id
           AND i.content_item_class_id = cic.content_item_class_id
           AND ivp.status              = 1
           AND i.seller_item_status    = 1
           AND ci.status               = 1
           AND ivp.ima_exchange_status = 2
        )  tmp,
        semistatic_content.profile_value   pv,
        semistatic_content.profile         p
   WHERE (DATEDIFF(NOW(), tmp.latest_modification_dtm) > (pv.profile_term_value/86400))
     AND p.profile_id         = pv.profile_id
     AND pv.profile_term_type = 'IMA_PENDING_THRESHOLD'
     AND p.profile_name       = 'INTERNAL_SETTINGS'
     AND tmp.account_id       = t.account_id;"

  ${MYSQL_CMD} -h${catalogDBhost} -e "${QUERY}" | sed 's/"/""/g;s/\t/","/g;s/^/"/;s/$/"/;s/\n//g' > $tmpdir/$prgName.csv
  [ ! "$?" == "0" ] && echo "Generate report failed.." && exit 1
}

getItemReport;

# print messages to the msg file
echo "Getting Report for ${reportDate}..."
echo "VD Items in IMA PENDING Status after threshold limit ($threshold_limit days)" >> "$tmpdir/$prgName.msg"
echo "------------------------------------------------------------------" >> "$tmpdir/$prgName.msg"
echo "Reports for ${reportDate} is attached." >> "$tmpdir/$prgName.msg"
echo " " >> "$tmpdir/$prgName.msg"

if test -s $tmpdir/$prgName.csv
  then
    echo "There are $(( `cat $tmpdir/$prgName.csv | cut -d, -f4 | sort -u | wc -l | awk '{print $1}'` - 1)) items in IMA_PENDING_STATUS." >> "$tmpdir/$prgName.msg";
    exit 0
  else
    echo "There are no items in IMA_PENDING_STATUS" >> "$tmpdir/$prgName.msg";
    exit 0
fi
