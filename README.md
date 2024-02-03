# DirectConnect Redundancy Monitoring Solution

AWS Direct Connect (DX) is a cloud service provided by Amazon Web Services (AWS) that allows you to establish a dedicated private connection from your on-premises data center or office location to AWS. It provides a more consistent network experience than internet-based connections by bypassing the public internet. tI provides a dedicated bridge between on-premises infrastructure and the AWS cloud. AWS Direct Connect facilitates establishing a dedicated network connection from on-premises sites to AWS, giving better performance, consistency, and security for workloads using AWS resources. It is a key enabling service for hybrid architectures.

There are two ways to establish a Direct Connect Connetion between a on-premises data center to AWS. These are 2 methods are Direct Connect Gateway (DXGW) and Virtual Private Gateway (VGW)

**Direct Connect Gateway**

Direct Connect Gateway allows you to connect your on-prem data center to multiple Amazon VPCs using a single Direct Connect connection. The Direct Connect Gateway acts as a hub. You can then associate up to 10 VPCs with that Gateway. The VPCs will in turn be able to access the on-prem data center over the single Direct Connect connection to the Gateway.   This simplifies the network architecture and reduces costs compared to having dedicated Direct Connect connections to each VPC individually. The Gateway centralizes connectivity to VPCs through a single on-prem endpoint.

**Virtual Private Gateway**

Virtual Private Gateway or VGW is a virtual network gateway that is used to associate a VPC (Virtual Private Cloud) with other network gateways. You then create a private virtual interface (VIF) and associate it with the VGW. The VIF enables connectivity between the VGW and Direct Connect. This establishes direct private access from your on-premises network to the VPC over the Direct Connect link. Over the same Direct Connect link, you can create multiple VGWs and private VIFs to connect to different VPCs. This allows you to access multiple VPCs directly from your on-premises network over a single Direct Connect connection. The VGWs and VIFs provide isolated, private connectivity between your network and each VPC.

##Problem Statement

AWS Trusted Advisor is a service provided by Amazon Web Services that performs automated checks on an AWS account and makes recommendations to improve performance, security, fault tolerance, and cost optimization. The Trusted Advisor currently provides fault tolerance checks for AWS Direct Connect connections that are set up with a Virtual Private Gateway (VGW). These checks help ensure the Direct Connect connection has redundancy in case of a network failure.
However, for Direct Connect setups using a Direct Connect Gateway (DXGW) instead of a VGW, Trusted Advisor does not currently perform fault tolerance checks. This presents an issue for customers using Direct Connect with DXGW, as they lack visibility into the redundancy of their connection through Trusted Advisor.
To address this gap and provide fault tolerance monitoring for DXGW Direct Connect customers, I created a custom tool or solution. This tool monitors the customer's Direct Connect setup and checks for redundancy and failover capabilities. It looks at aspects like multiple physical connections, BGP and link aggregation configurations to determine if there is adequate redundancy.
The results of the fault tolerance checks are presented on a dashboard. This provides DXGW Direct Connect customers visibility into whether their connection has the proper redundancy to maintain availability even in the event of a failure. By creating this tool, I enabled Trusted Advisor-like fault tolerance monitoring for an AWS setup that it does not currently cover out of the box.


##Solution

The solution was created using Lambda (serverless compute) to call the DescribeVirtualInterface API to collect DirectConnect data for a customer's AWS infrastructure. Lambda is a serverless compute service that allows you to run code without provisioning servers. A Lambda function was created that calls the DescribeVirtualInterface API, which is a DirectConnect API that provides information about configured virtual interfaces. This allows the solution to programmatically collect DirectConnect configuration data for the customer's AWS environment.
The Lambda function will be triggered by EventBridge on a schedule defined by the customer. EventBridge is a serverless event bus that can trigger Lambda functions on a scheduled basis. The customer can define how often they want the Lambda function to execute and collect the DirectConnect data.
The Lambda function collects information such as the virtual interfaces (VIFs), DirectConnect device, VLAN, ASNs etc. This is configuration data about the customer's DirectConnect setup.
This data is uploaded to an S3 bucket which is then used to create an Athena table and a table view for account name mapping. S3 provides object storage, and the DirectConnect data is stored in an S3 bucket. Athena allows querying data in S3 using standard SQL. So an Athena table is created from the S3 data, along with a view that maps account IDs to account names.
Amazon QuickSight DataSets are created using the Athena table and view. QuickSight is a business intelligence service that can visualize data from various sources. DataSets in QuickSight point to the data source, in this case the Athena table and view.
The QuickSight DataSets will also be refreshed on a schedule defined by the customer. So the DirectConnect data queried via Athena will be regularly updated in QuickSight.
In order to check for redundancy and present the findings, a QuickSight Calculated Field is used to check for distinct DirectConnect devices per account and per virtual interface. This allows identifying redundant connections.
An example screenshot shows the redundancy status visually.
The solution also provides a centralized inventory and easy search lookup of virtual interfaces, DirectConnect, ASNs etc by AWS account. This overcomes a limitation of the AWS DirectConnect console which lacks this aggregated view across accounts.


![image](https://github.com/oshobowa/DX-Gateway-Redundancy-Check/blob/main/image.png)

##Implementation

Create a Lambda function and grant the Lambda function's execution role permissions to access an S3 bucket, using the following code to create the Lambda function:

```
import boto3
import csv
from botocore.exceptions import ClientError
import json

def lambda_handler(event, context):
    regions = ['eu-west-1','us-west-1','us-east-1']
    for region in regions:
            client = boto3.client("directconnect", region_name=region)
            dxinfo = client.describe_virtual_interfaces()
            header = ["AccountID","VirtualInterfaceID", "VirtualInterfaceName","VirtualInterfaceType","CircuitID","Region","VLAN","ASN","AmazonASN","EA-IP","Amazon-IP","Status"]
            file_name = (f"dx-info-{region}.csv")
            s3_path = 'dx-report/' + file_name
            with open('/tmp/file_name', "w", encoding="UTF8") as f:
                writer = csv.writer(f)
                writer.writerow(header)
                #print(response)
                for vif in dxinfo.get("virtualInterfaces"):
                    AccountID = vif.get('ownerAccount')
                    VirtualInterfaceID = vif.get('virtualInterfaceId')
                    VirtualInterfaceName = vif.get('virtualInterfaceName')
                    VirtualInterfaceType = vif.get('virtualInterfaceType')
                    CircuitID = vif.get('connectionId')
                    VLAN = vif.get('vlan')
                    ASN = vif.get('asn')
                    AmazonASN = vif.get('amazonSideAsn')
                    Customer_IP = vif.get('customerAddress')
                    Amazon_IP = vif.get('amazonAddress')
                    Status = vif.get('virtualInterfaceState')
                    data = [AccountID,VirtualInterfaceID,VirtualInterfaceName,VirtualInterfaceType,CircuitID,region,VLAN,ASN,AmazonASN,Customer_IP,Amazon_IP,Status]
                    writer.writerow(data)
                    data = []
                f.close()
            s3_client = boto3.resource("s3")
            # Replace bucket name
            bucket = s3_client.Bucket('BUCKET-NAME')
            bucket.upload_file('/tmp/file_name', s3_path)

```

Create Athena table and table view using the S3 bucket and prefix specified in the Lambda function as the location;

```
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
```

* Open QuickSight and created an account --> After the account creation, grant QuickSight permission to the S3 bucket and Athena.
* Create DataSets dx_inventory_vlan pointing the "dx_inventory_vlan" view, then create another DataSet "dx_report_vlan" pointing to the dx_report table.

Run the commands below to get the DataSet information;

```
aws quicksight list-data-sets --aws-account-id <> --region us-east-1
```

Create Dashboard using the command and json below

```
aws quicksight create-dashboard --aws-account-id <> --dashboard-id DX_Inventory --name dx_intentory --source-entity file://dash.json
{
 "SourceTemplate": {
  "DataSetReferences": [
    {
      "DataSetPlaceholder": "dx_inventory_vlan",
      "DataSetArn": "arn:aws:quicksight:us-east-1:1234567890:dataset/8e13cbaa-6d09-4409-9cf4-d8f6ad80254b"
    },
    {
      "DataSetPlaceholder": "dx_report_vlan",
      "DataSetArn": "arn:aws:quicksight:us-east-1:1234567890:dataset/a384abd4-db15-46ef-b8ab-98fc47cb6c1c"
    }
  ],
    "Arn": "arn:aws:quicksight:us-east-1:266692567846:template/DX_Info_Redundancy_Prod"
 }
}
```

```aws quicksight list-users --aws-account-id 1234567890 --region us-east-1 --namespace default
```

Update Dashboard permission using the command and json below

```
aws quicksight update-dashboard-permissions --aws-account-id 1234567890 --dashboard-id DX_Inventory --grant-permissions file://dash-perm.json
[
  {
    "Principal": "arn:aws:quicksight:us-east-1:1234567890:user/default/olajide",
    "Actions": [
      "quicksight:DescribeDashboard",
      "quicksight:ListDashboardVersions",
      "quicksight:UpdateDashboardPermissions",
      "quicksight:QueryDashboard",
      "quicksight:UpdateDashboard",
      "quicksight:DeleteDashboard",
      "quicksight:DescribeDashboardPermissions",
      "quicksight:UpdateDashboardPublishedVersion"
    ]
  }
]
```





