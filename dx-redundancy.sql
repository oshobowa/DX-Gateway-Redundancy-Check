#Account Name Table
CREATE EXTERNAL TABLE IF NOT EXISTS `eks`.`accountname` (
 `AccountID` string,
 `AccountName` string
 )
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES (
 'serialization.format' = ',',
 'field.delim' = ','
)
LOCATION 's3://BUCKET-NAME/dx-report/accounts/'
TBLPROPERTIES ('skip.header.line.count'='1')
;

#DX Data Table
CREATE EXTERNAL TABLE IF NOT EXISTS `dx_report` (
 `accountid` string,
 `virtualinterfaceid` string,
  `virtualinterfacename` string,
 `virtualifacetype` string,
 `circuitid` string,
 `region` string,
 `VLAN` string,
 `ASN` string,
 `AmazonASN` string,
 `Customer_IP` string,
 `Amazon_IP` string,
 `Status` string
 )
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES (
 'serialization.format' = ',',
 'field.delim' = ','
)
LOCATION 's3://BUCKET-NAME/dx-report/'
TBLPROPERTIES ('skip.header.line.count'='1')
;

#DX Data and Account Name Mapping
CREATE OR REPLACE VIEW "dx_inventory_vlan" AS 
SELECT DISTINCT
dx_report_vlan.virtualinterfaceid,
dx_report_vlan.accountid,
accountname.accountname,
dx_report_vlan.virtualinterfacename,
dx_report_vlan.virtualifacetype,
dx_report_vlan.circuitid,
dx_report_vlan.region,
dx_report_vlan.VLAN,
dx_report_vlan.ASN,
dx_report_vlan.AmazonASN,
dx_report_vlan.Customer_IP,
dx_report_vlan.Amazon_IP,
dx_report_vlan.Status
FROM
  (dx_report_vlan
INNER JOIN accountname ON (dx_report_vlan.accountid = accountname.accountid))