# VPC FlowLogs demonstration

These scripts are used to set up an implementation of VPC flow logs based on [Analyzing VPC Flow Logs with Amazon Kinesis Firehose, Amazon Athena, and Amazon QuickSight]("https://aws.amazon.com/blogs/big-data/analyzing-vpc-flow-logs-with-amazon-kinesis-firehose-amazon-athena-and-amazon-quicksight/").

In order to provide a reasonably interesting network configuration for logging, these scripts will setup a fresh VPC containing two subnets. One subnet will host an EC2 instance, the other a NAT gateway. The instance will be able to reach out to the internet on port 80 and port 443 via the NAT gateway and an Internet gateway, and will be able to accessed via SSH from a limited IP range.

VPC flow logs will be collated into an S3 bucket, and exposed to Athena for ad-hoc queries.

## Use

### Bootstrap
The first thing that needs to be done is to bootstrap up some resources for terraform. The assets in the `bootstrap` folder do this. They set up an EC2 SSH Key Pair, and a DynamoDB table and S3 bucket for storing terraform state.

Within the `bootstrap` folder, copy `env.rc.template` to `env.rc` and supply the necessary settings.

Next, execute `bootstrap.sh`, you should be able to see output similar to the following at the end of the run:

```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

bucket_arn = arn:aws:s3:::terraform-state20180823151609662300000001
key_arn = arn:aws:kms:eu-west-2:889199313043:key/2e84e858-a65f-4e80-949f-34a6cef20870
project_tags = {
  client = Internal
  owner = rahook
  project = flowlogs-test
}
table_arn = arn:aws:dynamodb:eu-west-2:889199313043:table/terraform-state-lock
table_name = terraform-state-lock
```

You should also be able to see a new `.PEM` file in the `data` directory.

Finally, update the `platform/backend.tf` file with the bucket and table ARNs as required - all values in this file must correspond to the values from the bootstrap script.

## Platform
 - change into folder, setup variables, do terraform init, terraform plan

Once the instances are available, you should be able to SSH into the "bastion" instance, and thence to the "test" instance, and exercise HTTP and HTTPS from both:
```
$ ssh -i bastion.pem ec2-user@ec2-35-176-219-165.eu-west-2.compute.amazonaws.com
[ec2-user@ip-172-30-10-102 ~]$ curl -I http://example.net
HTTP/1.1 200 OK
Content-Encoding: gzip
Accept-Ranges: bytes
Cache-Control: max-age=604800
Content-Type: text/html; charset=UTF-8
Date: Fri, 24 Aug 2018 14:39:44 GMT
Etag: "1541025663+ident"
Expires: Fri, 31 Aug 2018 14:39:44 GMT
Last-Modified: Fri, 09 Aug 2013 23:54:35 GMT
Server: ECS (dca/2486)
X-Cache: HIT
Content-Length: 606

[ec2-user@ip-172-30-10-102 ~]$ curl -I https://example.com
HTTP/2 200
content-encoding: gzip
accept-ranges: bytes
cache-control: max-age=604800
content-type: text/html; charset=UTF-8
date: Fri, 24 Aug 2018 14:39:51 GMT
etag: "1541025663"
expires: Fri, 31 Aug 2018 14:39:51 GMT
last-modified: Fri, 09 Aug 2013 23:54:35 GMT
server: ECS (dca/2454)
x-cache: HIT
content-length: 606

[ec2-user@ip-172-30-10-102 ~]$ ssh -i ~/.ssh/vpclogstest.pem ec2-user@ip-172-30-10-28.eu-west-2.compute.internal
[ec2-user@ip-172-30-10-28 ~]$ curl -I http://example.net
HTTP/1.1 200 OK
Accept-Ranges: bytes
Cache-Control: max-age=604800
Content-Type: text/html; charset=UTF-8
Date: Fri, 24 Aug 2018 14:40:03 GMT
Etag: "1541025663"
Expires: Fri, 31 Aug 2018 14:40:03 GMT
Last-Modified: Fri, 09 Aug 2013 23:54:35 GMT
Server: ECS (dca/249F)
X-Cache: HIT
Content-Length: 1270

[ec2-user@ip-172-30-10-28 ~]$ curl -I https://example.com
HTTP/2 200
content-encoding: gzip
accept-ranges: bytes
cache-control: max-age=604800
content-type: text/html; charset=UTF-8
date: Fri, 24 Aug 2018 14:40:08 GMT
etag: "1541025663"
expires: Fri, 31 Aug 2018 14:40:08 GMT
last-modified: Fri, 09 Aug 2013 23:54:35 GMT
server: ECS (dca/532C)
x-cache: HIT
content-length: 606

[ec2-user@ip-172-30-10-28 ~]$
```

*NOTE* terraform does not set expiry on created CloudWatch log group, recommend setting it to something sensible in the console

## Todo
- SSE on the S3 bucket
- the athena table and s3 bucket are set with force-destroy = true, for convenience, but not good idea for real use
- athena result encryption https://docs.aws.amazon.com/athena/latest/ug/encryption.html#encrypting-query-results-stored-in-s3
- parquet??? https://engineering.opsgenie.com/analyzing-aws-vpc-flow-logs-using-apache-parquet-files-and-amazon-athena-27f8025371fa
