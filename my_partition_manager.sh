#!/bin/bash
# range partition : test.userlogs
usage() {
    echo "Usage: $0 -d <dbname> -t <tablename> -r month|day|week [-x <expire_unit>] [-a <add_unit>] [-p <partition_prefix>] [-f <partitioning_key_function>]"
    echo "An expire/add unit is based on your range type. " 
    exit 1
}

PAR_PREFIX='p'
PAR_FUNC='UNIX_TIMESTAMP'
while getopts ":d:t:r:x:a:p:f:" arg; do
  case $arg in
      d) DB_NAME=${OPTARG}
         ;;
      t) TABLE_NAME=${OPTARG}
         ;;
      r) RANGE_TYPE=${OPTARG}
         if [ $RANGE_TYPE != "month" -a $RANGE_TYPE != "day" -a $RANGE_TYPE != "week" ] ; then echo "ERROR IN OPTION: Please choose month, day, or week for your RANGE_TYPE"; usage; fi
         ;;
      x) EXPIRE_UNITS=${OPTARG}
         if [ $EXPIRE_UNITS -lt 1 ] ; then echo "ERROR IN OPTION: EXPIRE_UNITS needs to be greater than or equal to 1."; usage; fi
         ;;
      a) ADD_UNITS=${OPTARG}
         ;;
      p) PAR_PREFIX=${OPTARG}
         ;;
      f) PAR_FUNC=${OPTARG}
         ;;
      \?) echo "Invalid option: -$OPTARG" >&2
          exit 1
         ;;
      :) echo "Option -$OPTARG requires an argument." >&2
          exit 1
         ;;
  esac
done

if [ -z "$DB_NAME" -o -z "$TABLE_NAME" -o -z "$RANGE_TYPE" ]; then
    echo "DB_NAME, TABLE_NAME, RANGE_TYPE are mandatory"
    usage
fi

if [ -z "$EXPIRE_UNITS"  -a -z "$ADD_UNITS" ]; then
    echo "Please select at least one task (expire or add)"
    usage; #exit 1;
fi


MYSQL_HOME=/mysql/MyHome
MYSQL_HOST=127.0.0.1
MYSQL_PORT=20306
MYSQL_USER=root
MYSQL_PASS='xxxx'


## -------------------------------------------------------------------------------------
## Auto partition manager
## -------------------------------------------------------------------------------------
## -- crontab :
## ## Auto parition manager script
## ## 0 3 * * *  sh /mysql/admin/partition/my_partition_manager.sh -d dbname -t tablename -r monthly -x 3 -a 4 > /mysql/admin/partition/monthly_partition_dbname_tablename.log  2>&1
## ## 0 3 * * *  sh /mysql/admin/partition/my_partition_manager.sh -d dbname -t tablename -r daily -x 90 -a 91 > /mysql/admin/partition/daily_partition_dbname_tablename.log  2>&1
## -------------------------------------------------------------------------------------

## -------------------------------------------------------------------------------------
## Install script base directory
SCRIPT_BASEDIR=$(dirname $0)
## -------------------------------------------------------------------------------------

## This call will terminate script execution if there's error
## Call : exit_if_error $? "can't get mysql replication role"
## -------------------------------------------------------------------------------------
function exit_if_error(){
  if [ $1 -ne 0 ] ; then
    CURRENT_DTTM=`date '+%Y-%m-%d %H:%M:%S'`
    echo "[$CURRENT_DTTM][ERROR] PartitionManager: $2"
    exit
  fi
}

CURRENT_DTTM=`date '+%Y-%m-%d %H:%M:%S'`
echo "------------------------------------------------------------------------------------------------------------"
echo "-- Partition manager :: ${CURRENT_DTTM}"
echo "--     Target DB    :: ${DB_NAME}"
echo "--     Target Table :: ${TABLE_NAME}"
echo "--     Range Type :: ${RANGE_TYPE}"
echo "------------------------------------------------------------------------------------------------------------"

## CHECK TABLE IS PARTITION TABLE
QUERY_TO_CHECK="select not exists ( select 1 from information_schema.partitions where table_schema='${DB_NAME}' and table_name='${TABLE_NAME}')"
PARTITION_NOT_EXISTS=`${MYSQL_HOME}/bin/mysql --user="${MYSQL_USER}" --password="${MYSQL_PASS}" --skip-column-names --batch --execute="${QUERY_TO_CHECK}"`
#echo $PARTITION_NOT_EXISTS
exit_if_error ${PARTITION_NOT_EXISTS} "Partition Table does not exists: <${PARTITION_NOT_EXISTS}> $QUERY_TO_CHECK"

## RANGE_TYPE and Variables 
if [ $RANGE_TYPE = 'month' ]; then
	expr_to_create="DATE_FORMAT(cal.date - INTERVAL 1 MONTH, '%Y%m')"
	expr_high="DATE_FORMAT(cal.date,'%Y-%m-01')"
elif [ $RANGE_TYPE = 'week' ]; then
	expr_to_create="DATE_FORMAT(cal.date - interval 1 WEEK - interval weekday(cal.date) DAY, '%Y%m%d')"
	expr_high="DATE_FORMAT(cal.date  - interval weekday(cal.date) day,'%Y-%m-%d')"
elif [ $RANGE_TYPE = 'day' ]; then
	expr_to_create="DATE_FORMAT(cal.date - interval 1 DAY, '%Y%m%d')"
	expr_high="DATE_FORMAT(cal.date,'%Y-%m-%d')"
fi

## CHECK PARTITION TO CREATE OR DROP
if [ $ADD_UNITS ]; then
  echo "ADD Partiton for $ADD_UNITS $RANGE_TYPE(s)"
  QUERY_TO_GET_PARTITION_TO_ADD="
-- get partitions to add (ADD_UNITS)
SELECT CONCAT('${PAR_PREFIX}',$expr_to_create) as part_to_create, ${PAR_FUNC}($expr_high) as part_high, t.partition_name, t.partition_description
 FROM (
      SELECT SUBDATE(NOW(), INTERVAL ${EXPIRE_UNITS}-1 $RANGE_TYPE) + INTERVAL xc $RANGE_TYPE AS date
      FROM (
            SELECT @xi:=@xi+1 as xc from
            (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) xc1,
            (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) xc2,
            (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) xc3,
            -- (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) xc4,
            (SELECT @xi:=-1) xc0  -- 64 lines are generated
      ) xxc1
) cal
LEFT JOIN
(select partition_name, partition_description from information_schema.partitions where table_schema='${DB_NAME}' and table_name='${TABLE_NAME}') t
on ${PAR_FUNC}($expr_high) = t.partition_description
"
#### WHERE CONDITION, SUPPORT RANGE COLUMNS
  if [ ${PAR_FUNC^^} == 'QUOTE' ]; then
    QUERY_TO_GET_PARTITION_TO_ADD+="
where t.partition_name IS NULL AND ($expr_high) between  (select str_to_date(max(partition_description),'\'%Y-%m-%d\'') as max_value FROM information_schema.partitions  WHERE table_schema='${DB_NAME}' AND table_name='${TABLE_NAME}') and (NOW() + INTERVAL ${ADD_UNITS} $RANGE_TYPE)
ORDER BY 1, 2, 3
"
  else
    QUERY_TO_GET_PARTITION_TO_ADD+="
where t.partition_name IS NULL AND ${PAR_FUNC}($expr_high) between  (select max(partition_description) as max_value FROM information_schema.partitions  WHERE table_schema='${DB_NAME}' AND table_name='${TABLE_NAME}') and ${PAR_FUNC}(NOW() + INTERVAL ${ADD_UNITS} $RANGE_TYPE)
ORDER BY 1, 2, 3
"
  fi
#echo $QUERY_TO_GET_PARTITION_TO_ADD
#GET_PARTITION_TO_ADD=`${MYSQL_HOME}/bin/mysql --user="${MYSQL_USER}" --password="${MYSQL_PASS}" --skip-column-names --batch --execute="${QUERY_TO_GET_PARTITION_TO_ADD}"`
fi
if [ $EXPIRE_UNITS ]; then
  echo "DROP Partition before $EXPIRE_UNITS $RANGE_TYPE(s)"
  QUERY_TO_GET_PARTITION_TO_DROP="
-- get partitions to drop (EXPIRE_UNITS)
SELECT CONCAT('${PAR_PREFIX}',$expr_to_create) as part_to_create, ${PAR_FUNC}($expr_high) as part_high, t.partition_name, t.partition_description
 FROM (
SELECT SUBDATE(NOW(), INTERVAL ${EXPIRE_UNITS}-1 $RANGE_TYPE) + INTERVAL xc $RANGE_TYPE AS date
FROM (
      SELECT @xi:=@xi+1 as xc from
      (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) xc1,
      (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) xc2,
      (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) xc3,
      -- (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) xc4,
      (SELECT @xi:=-1) xc0  -- 64 lines are generated
     ) xxc1
) cal
RIGHT JOIN
(select partition_name, partition_description from information_schema.partitions WHERE table_schema='${DB_NAME}' AND table_name='${TABLE_NAME}') t
ON ${PAR_FUNC}($expr_high) = t.partition_description
"
#### WHERE CONDITION, SUPPORT RANGE COLUMNS
  if [ ${PAR_FUNC^^} == 'QUOTE' ]; then
    QUERY_TO_GET_PARTITION_TO_DROP+="
WHERE cal.date is null and str_to_date(t.partition_description,'\'%Y-%m-%d\'') < (SUBDATE(NOW(), INTERVAL ${EXPIRE_UNITS}-1 $RANGE_TYPE))
ORDER BY 1, 2, 3
"
  else
    QUERY_TO_GET_PARTITION_TO_DROP+="
WHERE cal.date is null and t.partition_description < ${PAR_FUNC}(SUBDATE(NOW(), INTERVAL ${EXPIRE_UNITS}-1 $RANGE_TYPE))
ORDER BY 1, 2, 3
"
  fi
#echo $QUERY_TO_GET_PARTITION_TO_DROP
#GET_PARTITION_TO_DROP=`${MYSQL_HOME}/bin/mysql --user="${MYSQL_USER}" --password="${MYSQL_PASS}" --skip-column-names --batch --execute="${QUERY_TO_GET_PARTITION_TO_DROP}"`
fi

#echo ""
#echo "Get partition to add "
#echo "${GET_PARTITION_TO_ADD}"
#echo "Get partition to drop "
#echo "${GET_PARTITION_TO_DROP}"

${MYSQL_HOME}/bin/mysql --user="${MYSQL_USER}" --password="${MYSQL_PASS}" --skip-column-names --batch --execute="${QUERY_TO_GET_PARTITION_TO_ADD};${QUERY_TO_GET_PARTITION_TO_DROP}"| while read line
do
  results=($line)
  if [ ${results[0]} != "NULL" ] && [ ${results[2]} == "NULL" ];then
	  echo "ADD PARTITION: ${results[0]}, ${results[1]}"
	  QUERY_ADD_PARTITION="ALTER TABLE \`${DB_NAME}\`.\`${TABLE_NAME}\` ADD PARTITION (PARTITION ${results[0]} VALUES LESS THAN (${results[1]}))"
	  echo $QUERY_ADD_PARTITION
	  ${MYSQL_HOME}/bin/mysql --user="${MYSQL_USER}" --password="${MYSQL_PASS}" --execute="${QUERY_ADD_PARTITION}"
          exit_if_error $? "Add partition query failed: <$?> $QUERY_ADD_PARTITION"
  elif [ ${results[0]} == "NULL" ] && [ ${results[2]} != "NULL" ];then
	  echo "DROP PARTITION: ${results[2]}, ${results[3]}"
	  QUERY_DROP_PARTITION="ALTER TABLE \`${DB_NAME}\`.\`${TABLE_NAME}\` DROP PARTITION ${results[2]}"
	  echo $QUERY_DROP_PARTITION
	  ${MYSQL_HOME}/bin/mysql --user="${MYSQL_USER}" --password="${MYSQL_PASS}" --execute="${QUERY_DROP_PARTITION}"
	  exit_if_error $? "Drop partition query failed : <$?> $QUERY_DROP_PARTITION"

  fi
  #declare -p results
done
