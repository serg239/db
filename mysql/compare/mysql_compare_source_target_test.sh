#!/bin/bash
#set -x

# Example: <>/db/bin/mysql_compare_source_target_test.sh -v -h dbtrunk-db1 -u data_owner -pdata_owner -P 3306 -t dbtrunk-db3 -r data_owner -d data_owner -O 3306


bin_dir="$(dirname "${0}")"

db1_dbSchemas="account user"
db2_dbSchemas="static_content semistatic_content load_catalog catalog external_content"

db_unload_compare_path="/tmp/db_unload_compare_path"

sendmail='/bin/mail -s'
sendto='my_name@my_host.com'
subject="MySQL schemas for script ${which_script} compared to yesterday are"

# diff_brief='/usr/bin/diff --brief -s'
# diff_full='/usr/bin/diff'

tables_compare_log_fname="${db_unload_compare_path}/tables_compare.log"
columns_compare_log_fname="${db_unload_compare_path}/columns_compare.log"

function usage() {
cat << __USAGE__ >&2
Usage: ${0} [-v] -h <src_host> -u <src_user_name> -p <src_password> -P <src_port> -t <trg_host> -r <trg_user> -d <trg_password> -O <trg_port>

Options:
        -h      MySQL source host
        -u      MySQL source user
        -p      MySQL source password
        -P      MySQL source port
        -t      MySQL target host
        -r      MySQL target user
        -d      MySQL target password
        -O      MySQL target port
        -v      verbose

__USAGE__
}

while getopts "h:u:p:P:t:r:d:O:v" option; do
  case "${option}" in
    h)  src_host="${OPTARG}";;
    u)  src_user="${OPTARG}";;
    p)  src_passwd="${OPTARG}";;
    P)  src_port="${OPTARG}";;
    t)  trg_host="${OPTARG}";;
    r)  trg_user="${OPTARG}";;
    d)  trg_passwd="${OPTARG}";;
    O)  trg_port="${OPTARG}";;
    v)  verbose="-v";;
    \? | *) usage
        exit 2;;
  esac
done

if test -z "${src_user}" -o -z "${src_host}" -o -z "${src_passwd}" -o -z "${src_port}" -o -z "${trg_user}" -o -z "${trg_host}" -o -z "${trg_passwd}" -o -z "${trg_port}"; then
  usage
  exit 2
fi

# -------------------------------------
# msg()
# -------------------------------------
function msg() {
  if test -n "${verbose}"; then
    echo "[$(date "+%F %T")] INFO ==>" "$@"
  fi
}

# -------------------------------------
# err_msg()
# -------------------------------------
function err_msg() {
  echo "[$(date "+%F %T")] *** ERROR *** ==>" "$@" >&2
}

# -------------------------------------
# delete_diff_files ()
# -------------------------------------
function delete_diff_files () {
  msg "Removing files from "${db_unload_compare_path}"..."
  sudo rm -rf "${db_unload_compare_path}"
}

MYSQL_CMD_SRC="mysql -h ${src_host} -P ${src_port} -u ${src_user} -p${src_passwd} "
MYSQL_CMD_TRG="mysql -h ${trg_host} -P ${trg_port} -u ${trg_user} -p${trg_passwd} "

msg "Deleting unload directory with all the files and recreating directory ..."
delete_diff_files

db1_schemas="${db1_dbSchemas}"
db2_schemas="${db2_dbSchemas}"

# -------------------------------------
# Tables in DB1 database
# -------------------------------------
for schema in ${db1_schemas[@]}; do

  msg "Running query for "${schema}" tables...."

  ${MYSQL_CMD_SRC} -e \
  "SELECT CASE table_location WHEN "Local Table" THEN CONCAT("CREATE TABLE ", q1.table_schema, ".", q1.table_name, "()") \
                                                 ELSE CONCAT("DROP TABLE ", q1.table_schema, ".", q1.table_name, "()") \
          END AS sql_stmt_tables \
     FROM \
       (SELECT MIN(q.table_location)  AS table_location, \
               q.table_schema, \
               q.table_name \
          FROM \ 
       (SELECT "Local Table"    AS table_location, \
               table_schema, \
               table_name \
           FROM information_schema.tables \
          WHERE table_schema = '$schema' \
        UNION ALL \
        SELECT "Remote Table"    AS table_location, \
               table_schema, \
               table_name \
           FROM elt.db1_information_schema_columns \
          WHERE table_schema = '$schema' \
        ) AS q \
       GROUP BY table_schema, \
                table_name \
        HAVING COUNT(*) = 1 \
       ) q1 \
     ORDER BY sql_stmt_tables " >> "${tables_compare_log_fname}"
  if test "$?" != "0"; then
    err_msg "Failed to run query for '${schema}' tables..."; 
    exit 1; 
  fi

done

# -------------------------------------
# Tables in DB2 database
# -------------------------------------
for schema in ${db2_schemas[@]}; do

  msg "Running query for "${schema}" tables...."

  # Save DIFF Tables
  ${MYSQL_CMD_SRC} -e \
  "SELECT CASE table_location WHEN "Local Table" THEN CONCAT("CREATE TABLE ", q1.table_schema, ".", q1.table_name, "()") \
                                                 ELSE CONCAT("DROP TABLE ", q1.table_schema, ".", q1.table_name, "()") \
          END AS sql_stmt_tables \
     FROM \
       (SELECT MIN(q.table_location)  AS table_location, \
               q.table_schema, \
               q.table_name \
          FROM \ 
       (SELECT "Local Table"    AS table_location, \
               table_schema, \
               table_name \
           FROM information_schema.tables \
          WHERE table_schema = '$schema' \
        UNION ALL \
        SELECT "Remote Table"    AS table_location, \
               table_schema, \
               table_name \
           FROM elt.db2_information_schema_columns \
          WHERE table_schema = '$schema' \
        ) AS q \
       GROUP BY table_schema, \
                table_name \
        HAVING COUNT(*) = 1 \
       ) q1 \
     ORDER BY sql_stmt_tables " >> "${tables_compare_log_fname}"
  if test "$?" != "0"; then
    err_msg "Failed to run query for '${schema}' tables..."; 
    exit 1; 
  fi

done

# -------------------------------------
# Columns in DB1 database
# -------------------------------------
for schema in ${db1_schemas[@]}; do

  msg "Running query for "${schema}" columns...."

  ${MYSQL_CMD_SRC} -e \
  "SELECT CASE table_location WHEN "Local Table" THEN CONCAT("ALTER TABLE ", table_schema, ".", table_name, " DROP COLUMN ", column_name) \
                              ELSE CONCAT("ALTER TABLE ", table_schema, ".", table_name, \
                                          " ADD COLUMN ", column_name, " ", UPPER(column_type), \
                                          CASE WHEN is_nullable = "NO" THEN " NOT NULL" \
                                                                       ELSE " NULL" \
                                          END, \
                                          IF (column_default IS NOT NULL, \ 
                                              CONCAT(" DEFAULT ", column_default), \
                                              "" \
                                             ) \
                                         ) \
          END AS sql_stmt_columns \
      FROM \
       (SELECT MIN(table_location)  AS table_location, \
               table_schema, \
               table_name, \
               column_name, \ 
               column_type, \
               is_nullable, \
               column_default, \
               column_key \
          FROM \
           (SELECT 'Local Table'    AS table_location, \
                   table_schema, \
                   table_name, \
                   column_name, \ 
                   column_type, \
                   is_nullable, \
                   column_default, \
                   column_key, \
                   ordinal_position \
              FROM information_schema.columns \
             WHERE (table_schema, table_name) IN \
                (SELECT src_schema_name, \
                        src_table_name \
                   FROM elt.src_tables \
                  WHERE src_schema_name = '$schema' \
                )
            UNION ALL \
            SELECT 'Remote Table'   AS table_location, \
                   table_schema, \
                   table_name, \
                   column_name, \ 
                   column_type, \
                   is_nullable, \
                   CASE WHEN (column_type = "timestamp" AND column_default = "0000-00-00 00:00:00") THEN "2000-01-01 00:00:00" \
                        ELSE column_default \
                   END              AS column_default, \
                   column_key,  \
                   ordinal_position \
              FROM elt.db1_information_schema_columns \
             WHERE (table_schema, table_name) IN \
                (SELECT src_schema_name, \
                        src_table_name \
                   FROM elt.src_tables \
                  WHERE table_schema = = '$schema' \
                    AND table_name <> "shard_account_list" \
                ) \
           ) AS q \
       GROUP BY table_schema, \
                table_name, \
                column_name, \ 
                column_type, \
                column_key \
        HAVING COUNT(*) = 1 \
         ORDER BY table_schema, table_name, ordinal_position \
       ) q1 " >> "${tables_compare_log_fname}"
  if test "$?" != "0"; then
    err_msg "Failed to run query for '${schema}' columns..."; 
    exit 1; 
  fi

done

# -------------------------------------
# Columns in DB2 database
# -------------------------------------
for schema in ${db2_schemas[@]}; do

  msg "Running query for "${schema}" columns...."

  ${MYSQL_CMD_SRC} -e \
  "SELECT CASE table_location WHEN "Local Table" THEN CONCAT("ALTER TABLE ", table_schema, ".", table_name, " DROP COLUMN ", column_name) \
                              ELSE CONCAT("ALTER TABLE ", table_schema, ".", table_name, \
                                          " ADD COLUMN ", column_name, " ", UPPER(column_type), \
                                          CASE WHEN is_nullable = "NO" THEN " NOT NULL" \
                                                                       ELSE " NULL" \
                                          END, \
                                          IF (column_default IS NOT NULL, \ 
                                              CONCAT(" DEFAULT ", column_default), \
                                              "" \
                                             ) \
                                         ) \
          END AS sql_stmt_columns \
      FROM \
       (SELECT MIN(table_location)  AS table_location, \
               table_schema, \
               table_name, \
               column_name, \ 
               column_type, \
               is_nullable, \
               column_default, \
               column_key \
          FROM \
           (SELECT 'Local Table'    AS table_location, \
                   table_schema, \
                   table_name, \
                   column_name, \ 
                   column_type, \
                   is_nullable, \
                   column_default, \
                   column_key, \
                   ordinal_position \
              FROM information_schema.columns \
             WHERE (table_schema, table_name) IN \
                (SELECT src_schema_name, \
                        src_table_name \
                   FROM elt.src_tables \
                  WHERE src_schema_name = '$schema' \
                )
            UNION ALL \
            SELECT 'Remote Table'   AS table_location, \
                   table_schema, \
                   table_name, \
                   column_name, \ 
                   column_type, \
                   is_nullable, \
                   CASE WHEN (column_type = "timestamp" AND column_default = "0000-00-00 00:00:00") THEN "2000-01-01 00:00:00" \
                        ELSE column_default \
                   END              AS column_default, \
                   column_key,  \
                   ordinal_position \
              FROM elt.db2_information_schema_columns \
             WHERE (table_schema, table_name) IN \
                (SELECT src_schema_name, \
                        src_table_name \
                   FROM elt.src_tables \
                  WHERE table_schema = = '$schema' \
                    AND table_name <> "shard_account_list" \
                ) \
           ) AS q \
       GROUP BY table_schema, \
                table_name, \
                column_name, \ 
                column_type, \
                column_key \
        HAVING COUNT(*) = 1 \
         ORDER BY table_schema, table_name, ordinal_position \
       ) q1 " >> "${tables_compare_log_fname}"
  if test "$?" != "0"; then
    err_msg "Failed to run query for '${schema}' columns..."; 
    exit 1; 
  fi

done

sudo touch $tables_compare_log_fname $columns_compare_log_fname
sudo chmod 777 $tables_compare_log_fname $columns_compare_log_fname

# Compare Tables
diff_result=`ls -la $tables_compare_log_fname | awk '{print $9, "\t", $5}'`
if [[ "$diff_result" -ne "0" ]]; then
  $sendmail "Table's comparison results between: $src_host and $trg_host " $sendto < $tables_compare_log_fname
else
  msg "${tables_compare_log_fname} is empty ...."
fi

# Compare Columns
diff_result=`ls -la $columns_compare_log_fname | awk '{print $9, "\t", $5}'`
if [[ "$diff_result" -ne "0" ]]; then
  $sendmail "Column's comparison results between: $src_host and $trg_host " $sendto < $columns_compare_log_fname
else
  msg "${columns_compare_log_fname} is empty ...."
fi
