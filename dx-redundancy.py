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
