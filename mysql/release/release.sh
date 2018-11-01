#!/bin/bash

binDir="$(dirname "${0}")"
deployDir="${binDir}/../schemas"
libDir="${binDir}/../lib"

catalogSchemas="static_content semistatic_content external_content inventory "
omsSchemas="account user invoice order shipment shipping"
reportSchemas="elt db_report"
# reportAuxiliarySchemas="account user creditcard invoice order shipment shipping inventory catalog file "
reportAuxiliarySchemas="account user static_content semistatic_content external_content "

function usage() {
  cat >&2 << __USAGE__

Usage: ${0} [-v] [-d] [-t] [-a] -h host [-P port] -u user -p passwd [-m <catalog|oms|report>] [-s schema_list] [-T] [-S] [-M]

Where:
  -v             : verbose
  -d             : deploy DDL before deploying code
  -t             : deploy triggers only
  -a             : deploy only APIs
  -h host        : db host
  -P port        : db port
  -u user        : db user name
  -p passwd      : db password
  -m mode        : subset of available schemas: catalog, oms, report or reportaux
  -s schema_list : list of schemas to deploy
  -T             : Migration switch, starts TCN data migration; defaulted to FALSE
  -S             : Migration switch, starts Project data migration; defaulted to FALSE
  -M             : Migration switch, starts DB migration (scipts located in the root folder); defaulted to FALSE

Note: only one flag -s or -c should be passed.
      Passing '-m catalog' is the same as '-s "${catalogSchemas}"'
      Passing '-m oms' is the same as '-s "${omsSchemas}"'
      Passing '-m report' is the same as '-s "${reportSchemas}"'
      Passing '-m reportaux' is the same as '-s "${reportAuxiliarySchemas}"'
__USAGE__
}

while getopts "vdh:p:u:P:s:m:MSTta" option; do
  case "${option}" in
    v)  verbose="-v";;
    d)  ddl="-d";;
    h)  host="${OPTARG}";;
    P)  port="${OPTARG}";;
    u)  user="${OPTARG}";;
    p)  passwd="${OPTARG}";;
    m)  mode="${OPTARG}";;
    s)  schemaList="${OPTARG}";;
    T)  migrateTCN="-T";;
    S)  migrateProject="-S";;
    M)  migrateDB="-M";;
    t)  deployTriggers="-t";;
    a)  deployAPIs="-a";;
    *)  usage
        exit 2;;
  esac
done

if [ -z "${host}" ] || [ -z "${port}" ] || [ -z "${user}" ]
then
  usage
  exit 1
fi

if [ "$mode" = "catalog" ] 
then
  schemas="${catalogSchemas}"
elif [ "$mode" = "oms" ]
then
  schemas="${omsSchemas}"
elif [ "$mode" = "report" ]
then
  schemas="${reportSchemas}"
elif [ "$mode" = "reportaux" ]
then
  schemas="${reportAuxiliarySchemas}"
elif [ -n "${schemaList}" ]
then
  schemas="${schemaList}"
else
  usage
  exit 1
fi

if [ -z "${passwd}" ]
then
   MYSQL_CMD_DDL="mysql -v -u ${user} -h ${host} -P ${port}"
   MYSQL_CMD_OTHER="mysql -u ${user} -h ${host} -P ${port}"
else
   MYSQL_CMD_DDL="mysql -v -u ${user} -p${passwd} -h ${host} -P ${port}"
   MYSQL_CMD_OTHER="mysql -u ${user} -p${passwd} -h ${host} -P ${port}"
fi

function msg() {
  if test -n "${verbose}"; then
    echo "[$(date "+%F %T")] INFO ==>" "$@"
  fi
}

function err_msg() {
  if test -n "${verbose}"; then
    echo "[$(date "+%F %T")] *** ERROR *** ==>" "$@" >&2
  fi
}

function cleanup() {
  msg "Cleaning up temporary files from [${TMPDIR}]..."
  rm -rf "${TMPDIR}"
}


function deployGrants() {
  # Call common grants
  ${MYSQL_CMD_OTHER} < "${libDir}"/common_grants.sql
  if test "$?" != "0"; then err_msg "Failed to run grants SQL ${sql_file}'"; exit 1; fi
}

function deployDDL() {
  for schema in ${schemas[@]}; do
    msg "Deploying DDL/DML release scripts to "${schema}"...."
    if [[ -n $( ls "${deployDir}"/"${schema}"/release_scripts/*.sql 2> /dev/null) ]]; then
      echo "DDL: for $schema"
      for sql_file in "${deployDir}"/"${schema}"/release_scripts/*.sql; do
        msg "Deploying release SQL $(basename "${sql_file}")..."
        ${MYSQL_CMD_DDL} < "${sql_file}"
        if test "$?" != "0"; then err_msg "Failed to run release SQL ${sql_file}'"; exit 1; fi
      done
    fi
  done
}


function deployOperationalProcs() {
    msg "Deploying Operational Procs to "${mode}"...."
    if [[ -n $( ls "${libDir}"/procs/*.sql 2> /dev/null) ]]; then
      echo "DDL: for $schema"
      for sql_file in "${libDir}"/procs/*.sql; do
        msg "Deploying release SQL $(basename "${sql_file}")..."
        ${MYSQL_CMD_OTHER} < "${sql_file}"
        if test "$?" != "0"; then err_msg "Failed to run release SQL ${sql_file}'"; exit 1; fi
      done
    fi
}

# At some point we might want to have a "deploy triggers only" switch" but for now we'll lump it all together with DDL 
function deployTriggers() {
  for schema in ${schemas[@]}; do
    msg "Deploying Triggers to "${schema}"...."
    if [[ -n $( ls "${deployDir}"/"${schema}"/triggers/*.sql 2> /dev/null) ]]; then
      echo "TRIGGERS: for $schema"
      for sql_file in "${deployDir}"/"${schema}"/triggers/*.sql; do
        msg "Deploying release SQL $(basename "${sql_file}")..."
        ${MYSQL_CMD_OTHER} < "${sql_file}"
        if test "$?" != "0"; then err_msg "Failed to run release SQL ${sql_file}'"; exit 1; fi
      done
    fi
  done
}

function deployCode() {
  for schema in ${schemas[@]}; do
    msg "Deploying procs to "${schema}"...."
    if [[ -n $( ls "${deployDir}"/"${schema}"/procs/*.sql 2> /dev/null) ]]; then
      echo "CODE: for $schema"
      for sql_file in "${deployDir}"/"${schema}"/procs/*.sql; do
        msg "Deploying release SQL $(basename "${sql_file}")..."
        ${MYSQL_CMD_OTHER} < "${sql_file}"
        if test "$?" != "0"; then err_msg "Failed to run release SQL ${sql_file}'"; exit 1; fi
      done
    fi
  done
}

function deployMigrationDB() {
  for schema in ${schemas[@]}; do
    msg "Deploying DB migration scripts to "${schema}"...."
    if [[ -n $( ls "${deployDir}"/"${schema}"/migration/*.sql 2> /dev/null) ]]; then
      echo "MIGRATION: for $schema"
      for sql_file in "${deployDir}"/"${schema}"/migration/*.sql; do
        msg "Deploying release SQL $(basename "${sql_file}")..."
        ${MYSQL_CMD_DDL} < "${sql_file}"
        if test "$?" != "0"; then err_msg "Failed to run release SQL ${sql_file}'"; exit 1; fi
      done
    fi
  done
}


function deployMigrationScripts() {
  for schema in ${schemas[@]}; do
    msg "Deploying migration scripts to "${schema}"...."

    if [ -n "${migrateTCN}" ]; then
      ls "${deployDir}"/"${schema}"/migration | grep TCN >> /dev/null
      res=$?
     
      if [[ "$res" = "0" ]]; then
      echo "TCN data MIGRATION: for $schema"
      for sql_file in `ls "${deployDir}"/"${schema}"/migration/TCN/*.sql`; do
        msg "Deploying release SQL $(basename "${sql_file}")..."
        ${MYSQL_CMD_DDL} < "${sql_file}"
        if test "$?" != "0"; then err_msg "Failed to run release SQL ${sql_file}'"; exit 1; fi
      done
      fi
   fi
    
    if [ -n "${migrateProject}" ]; then
      ls "${deployDir}"/"${schema}"/migration | grep Project >> /dev/null
      res=$?
     
      if [[ "$res" = "0" ]]; then
      echo "Project data MIGRATION: for $schema"
      for sql_file in `ls "${deployDir}"/"${schema}"/migration/Project/*.sql`; do
        msg "Deploying release SQL $(basename "${sql_file}")..."
        ${MYSQL_CMD_DDL} < "${sql_file}"
        if test "$?" != "0"; then err_msg "Failed to run release SQL ${sql_file}'"; exit 1; fi
      done
      fi
   fi
    
  done
}


# starting here


deployOperationalProcs

deployGrants


# deploying ddl
if [ -n "${ddl}" ]
then
  deployDDL
  if [ "$mode" !=  "reportaux" ]; then
    deployCode
      #deployTriggers
  fi
fi

# trigggers
if [ -n "${deployTriggers}" ]
then
  if [ "$mode" !=  "reportaux" ]; then
      deployTriggers
  fi
fi


# DB migration
if [ -n "${migrateDB}" ]
then
  if [ "$mode" !=  "reportaux" ]; then
      deployMigrationDB
  fi
fi


# the rest of migrations
if [ -n "${migrateTCN}" ] || [ -n "${migrateProject}" ]
then
  deployMigrationScripts
fi

# APIs
if [ -n "${deployAPIs}" ]
then
  if [ "$mode" !=  "reportaux" ]
  then
    deployCode
  fi
fi


msg "***"
msg "*** Database release finished, please [re]start the Project DB application"
msg "***"
