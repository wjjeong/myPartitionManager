# myPartitionManager
mysql monthly partition manager
- RANGE Partitioning 
  - based on the value of a TIMESTAMP column
  - partioning_key_function : Date or Time (default:UNIX_TIMESTAMP()) function
- RANGE COLUMNS partitioning supports
  - based on a DATE column
  - partitioning_key_function : QUOTE
## Usages
```
Usage: ./monthly_partition_manager.sh -d <dbname> -t <tablename> [-x <expire_months>] [-a <add_months>] [-p <partition_prefix>] [-f <partitioning_key_function>]
```
## Example
### RANGE partitioning
```
[root@testhost:/mysql/admin/partition]# ./monthly_partition_manager.sh -d test -t Alogs -a 10 -x 2
------------------------------------------------------------------------------------------------------------
-- Partition creating :: 2017-07-06 18:34:49
--     Target DB    :: test
--     Target Table :: Alogs
------------------------------------------------------------------------------------------------------------
ADD Partiton for 10 month(s)
DROP Partition before 3 month(s)
ADD PARTITION: p201804, 1525100400
ALTER TABLE test.Alogs ADD PARTITION (PARTITION p201804 VALUES LESS THAN (1525100400))
DROP PARTITION: p201704, 1493564400
ALTER TABLE test.Alogs DROP PARTITION p201704
```
```
[root@testhost:/mysql/admin/partition]#  sh /mysql/admin/partition/monthly_partition_manager.sh -d test -t Blogs -a 3 -f to_days
------------------------------------------------------------------------------------------------------------
-- Partition manager :: 2017-09-28 16:53:05
--     Target DB    :: test
--     Target Table :: Blogs
------------------------------------------------------------------------------------------------------------
ADD Partiton for 3 month(s)
Warning: Using a password on the command line interface can be insecure.
ADD PARTITION: p201711, 737029
ALTER TABLE test.Blogs ADD PARTITION (PARTITION p201711 VALUES LESS THAN (737029))
Warning: Using a password on the command line interface can be insecure.
```
### RANGE COLUMNS partitioning
```
[root@testhost:/mysql/admin/partition]# ./monthly_partition_manager.sh -d test -t Clogs -a 3 -x 3 -f quote
------------------------------------------------------------------------------------------------------------
-- Partition manager :: 2017-10-25 12:26:48
--     Target DB    :: test
--     Target Table :: Clogs
------------------------------------------------------------------------------------------------------------
Warning: Using a password on the command line interface can be insecure.
ADD Partiton for 3 month(s)
DROP Partition before 3 month(s)
Warning: Using a password on the command line interface can be insecure.
ADD PARTITION: p201712, '2018-01-01'
ALTER TABLE test.Clogs ADD PARTITION (PARTITION p201712 VALUES LESS THAN ('2018-01-01'))
Warning: Using a password on the command line interface can be insecure.
DROP PARTITION: p201706, '2017-07-01'
ALTER TABLE test.Clogs DROP PARTITION p201706
Warning: Using a password on the command line interface can be insecure.
```
