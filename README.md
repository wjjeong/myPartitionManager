# myPartitionManager
mysql partition manager
- RANGE Partitioning : monthly, weekly, daily
  - based on the value of a TIMESTAMP column
  - partioning_key_function : Date or Time (default:UNIX_TIMESTAMP()) function
- RANGE COLUMNS partitioning supports
  - based on a DATE column
  - partitioning_key_function : QUOTE
## Usage
```
Usage: ./my_partition_manager.sh -d <dbname> -t <tablename> -u month|week|day [-x <expire_months>] [-a <add_months>] [-p <partition_prefix>] [-f <partitioning_key_function>]
```
## Example
### RANGE partitioning(weekly)
```
[root@host:/mysql/admin/partition]# ./my_partition_manager.sh -d test -t weeklogs -r week -a 3 -x 5
------------------------------------------------------------------------------------------------------------
-- Partition manager :: 2018-06-01 17:27:32
--     Target DB    :: test
--     Target Table :: weeklogs
--     Range Type :: week
------------------------------------------------------------------------------------------------------------
Warning: Using a password on the command line interface can be insecure.
ADD Partiton for 3 week(s)
DROP Partition before 5 week(s)
Warning: Using a password on the command line interface can be insecure.
ADD PARTITION: p20180611, 1529247600
ALTER TABLE `test`.`weeklogs` ADD PARTITION (PARTITION p20180611 VALUES LESS THAN (1529247600))
Warning: Using a password on the command line interface can be insecure.
DROP PARTITION: p20180416, 1524409200
ALTER TABLE `test`.`weeklogs` DROP PARTITION p20180416
Warning: Using a password on the command line interface can be insecure.
```
### RANGE partitioning(monthly)

```
[root@host:/mysql/admin/partition]# ./my_partition_manager.sh -d test -t monthlogs -r month -a 10 -x 2
------------------------------------------------------------------------------------------------------------
-- Partition creating :: 2017-07-06 18:34:49
--     Target DB    :: test
--     Target Table :: monthlogs
------------------------------------------------------------------------------------------------------------
ADD Partiton for 10 month(s)
DROP Partition before 3 month(s)
ADD PARTITION: p201804, 1525100400
ALTER TABLE test.monthlogs ADD PARTITION (PARTITION p201804 VALUES LESS THAN (1525100400))
DROP PARTITION: p201704, 1493564400
ALTER TABLE test.monthlogs DROP PARTITION p201704
```
```
[root@host:/mysql/admin/partition]#  ./my_partition_manager.sh -d test -t datetypelogs -r month -a 3 -f to_days
------------------------------------------------------------------------------------------------------------
-- Partition manager :: 2017-09-28 16:53:05
--     Target DB    :: test
--     Target Table :: datetypelogs
------------------------------------------------------------------------------------------------------------
ADD Partiton for 3 month(s)
Warning: Using a password on the command line interface can be insecure.
ADD PARTITION: p201711, 737029
ALTER TABLE test.datetypelogs ADD PARTITION (PARTITION p201711 VALUES LESS THAN (737029))
Warning: Using a password on the command line interface can be insecure.
```
### RANGE COLUMNS partitioning
```
[root@host:/mysql/admin/partition]# ./monthly_partition_manager.sh -d test -t range_columns_par -r month -a 3 -x 3 -f quote
------------------------------------------------------------------------------------------------------------
-- Partition manager :: 2017-10-25 12:26:48
--     Target DB    :: test
--     Target Table :: range_columns_par
------------------------------------------------------------------------------------------------------------
Warning: Using a password on the command line interface can be insecure.
ADD Partiton for 3 month(s)
DROP Partition before 3 month(s)
Warning: Using a password on the command line interface can be insecure.
ADD PARTITION: p201712, '2018-01-01'
ALTER TABLE test.range_columns_par ADD PARTITION (PARTITION p201712 VALUES LESS THAN ('2018-01-01'))
Warning: Using a password on the command line interface can be insecure.
DROP PARTITION: p201706, '2017-07-01'
ALTER TABLE test.range_columns_par DROP PARTITION p201706
Warning: Using a password on the command line interface can be insecure.
```
