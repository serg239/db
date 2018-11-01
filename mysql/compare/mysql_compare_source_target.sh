#!/bin/bash
#set -x

bin_dir="$(dirname "${0}")"

stageSchemas="load_catalog catalog file"
liveSchemas="account user invoice order shipment shipping"

unload_compare_path="/tmp/unload_compare_path"
unload_source_path="${unload_compare_path}/source"
unload_target_path="${unload_compare_path}/target"

sendmail='/bin/mail -s'
sendto='my_name@my_host.com'
subject="mysql schemas for script ${which_script} compared to yesterday are"

diff_brief='/usr/bin/diff --brief -s'
diff_full='/usr/bin/diff'

table_compare_log="/tmp/unload_compare_path/table_compare.log"
column_compare_log="/tmp/unload_compare_path/column_compare.log"

function usage() {
cat << __USAGE__ >&2
Usage: ${0} [-v] -h <MySQL source host> 
                 -u <MySQL source user> 
                 -p <MySQL source password> 
                 -P <MySQL source port>  
                 -m <live or stage> 
                 -t <MySQL target host> 
                 -r <MySQL target user> 
                 -d <MySQL target password> 
                 -O <MySQL target port>
Options:
        -h      MySQL source host
        -u      MySQL source user
        -p      MySQL source password
        -P      MySQL source port
        -m      live or stage
        -t      MySQL target host
        -r      MySQL target user
        -d      MySQL target password
        -O      MySQL target port
        -v      verbose

__USAGE__
}

while getopts "h:u:p:P:m:t:r:d:O:v" option; do
  case "${option}" in
    h)  db_host="${OPTARG}";;
    u)  db_user="${OPTARG}";;
    p)  db_passwd="${OPTARG}";;
    P)  db_port="${OPTARG}";;
    m)  mode="${OPTARG}";;
    t)  dw_host="${OPTARG}";;
    r)  dw_user="${OPTARG}";;
    d)  dw_passwd="${OPTARG}";;
    O)  dw_port="${OPTARG}";;
    v)  verbose="-v";;
    *)  usage
        exit 2;;
  esac
done

if test -z "${db_user}" -o -z "${db_host}" -o -z "${db_passwd}" -o -z "${db_port}" -o -z "${mode}" -o -z "${dw_user}" -o -z "${dw_host}" -o -z "${dw_passwd}" -o -z "${dw_port}"; then
  usage
  exit 2
fi


function msg() {
  if test -n "${verbose}"; then
    echo "[$(date "+%F %T")] INFO ==>" "$@"
  fi
}

function err_msg() {
  echo "[$(date "+%F %T")] *** ERROR *** ==>" "$@" >&2
}

function delete_compare_dir () {
for schema in ${schemas[@]}; do
  msg "Removing directories for "${schema}"...."
  sudo rm -rf "${unload_compare_path}"
done
}


if [ "$mode" = "stage" ]
then
  schemas="${stageSchemas}"
elif [ "$mode" = "live" ]
then
  schemas="${liveSchemas}"
else
  usage
  exit 1
fi

MYSQL_CMD_SOURCE="mysql -u ${db_user} -p${db_passwd} -h ${db_host} -P ${db_port}"
MYSQL_CMD_DW="mysql -u ${dw_user} -p${dw_passwd} -h ${dw_host} -P ${dw_port}"


msg "Deleting unload directory with all the files and recreating directory ..."
delete_compare_dir

sudo mkdir ${unload_compare_path}
sudo mkdir ${unload_source_path}
sudo mkdir ${unload_target_path}

sudo chmod 777 ${unload_source_path}
sudo chmod 777 ${unload_target_path}

for schema in ${schemas[@]}; do
  msg "Running query for "${schema}"...."
  ${MYSQL_CMD_SOURCE} -e \
        "SELECT CONCAT(table_schema, '.', table_name) 'schema.table', ENGINE \
        FROM information_schema.tables \
        WHERE table_schema = '$schema' \
        ORDER BY table_name" > "${unload_source_path}/${schema}_1"
  if test "$?" != "0"; then err_msg "Failed to run query for '${unload_source_path}/${schema}' ..."; exit 1; fi
  sudo chmod 777 "${unload_source_path}/${schema}_1"

  ${MYSQL_CMD_SOURCE} -e \
        "SELECT CONCAT(table_schema, '.', table_name) 'schema.table', column_name, column_default, is_nullable, data_type, \
        character_maximum_length, numeric_precision, numeric_scale, \
        character_set_name, collation_name, column_type, column_key, extra \
        FROM information_schema.columns \
        WHERE table_schema = '$schema' \
        ORDER BY table_name, column_name" > "${unload_source_path}/${schema}_2"
  if test "$?" != "0"; then err_msg "Failed to run query for '${unload_source_path}/${schema}' ..."; exit 1; fi
  sudo chmod 777 "${unload_source_path}/${schema}_2"
done

for schema in ${schemas[@]}; do
  msg "Running query for "${schema}"...."
  ${MYSQL_CMD_DW} -e \
        "SELECT CONCAT(table_schema, '.', table_name) 'schema.table', ENGINE \
        FROM information_schema.tables \
        WHERE table_schema = '$schema' \
        ORDER BY table_name" > "${unload_target_path}/${schema}_1"
  if test "$?" != "0"; then err_msg "Failed to run query for '${unload_target_path}/${schema}' ..."; exit 1; fi
  sudo chmod 777 "${unload_target_path}/${schema}_1"

  ${MYSQL_CMD_DW} -e \
        "SELECT CONCAT(table_schema, '.', table_name) 'schema.table', column_name, column_default, is_nullable, data_type, \
        character_maximum_length, numeric_precision, numeric_scale, \
        character_set_name, collation_name, column_type, column_key, extra \
        FROM information_schema.columns \
        WHERE table_schema = '$schema' \
        ORDER BY table_name, column_name" > "${unload_target_path}/${schema}_2"
  if test "$?" != "0"; then err_msg "Failed to run query for '${unload_target_path}/${schema}' ..."; exit 1; fi
  sudo chmod 777 "${unload_target_path}/${schema}_2"
done

sudo touch $table_compare_log $column_compare_log
sudo chmod 777 $table_compare_log $column_compare_log

for schema in ${schemas[@]}; do
  sudo $diff_full "${unload_source_path}/${schema}_1" "${unload_target_path}/${schema}_1" >> $table_compare_log
done

diff_result=`ls -la $table_compare_log | awk '{print $9, "\t", $5}'`
if [[ "$diff_result" -ne "0" ]]; then
  $sendmail "Mysql Schema table comparison results between: $db_host and $dw_host " $sendto < $table_compare_log
else
  msg "${table_compare_log} is empty ...."
fi

for schema in ${schemas[@]}; do
  sudo $diff_full "${unload_source_path}/${schema}_2" "${unload_target_path}/${schema}_2" >> $column_compare_log
done

diff_result=`ls -la $column_compare_log | awk '{print $9, "\t", $5}'`
if [[ "$diff_result" -ne "0" ]]; then
  $sendmail "Mysql Schema column comparison results between: $db_host and $dw_host " $sendto < $column_compare_log
else
  msg "${column_compare_log} is empty ...."
fi
