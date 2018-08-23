# VPC FlowLogs demonstration

These scripts are used to set up an implementation of VPC flow logs based on [Analyzing VPC Flow Logs with Amazon Kinesis Firehose, Amazon Athena, and Amazon QuickSight]("https://aws.amazon.com/blogs/big-data/analyzing-vpc-flow-logs-with-amazon-kinesis-firehose-amazon-athena-and-amazon-quicksight/").

In order to provide a reasonably interesting network configuration for logging, these scripts will setup a fresh VPC containing two subnets. One subnet will host an EC2 instance, the other a NAT gateway. The instance will be able to reach out to the internet on port 80 and port 443 via the NAT gateway and an Internet gateway, and will be able to accessed via SSH from a limited IP range.

VPC flow logs will be collated into an S3 bucket, and exposed to Athena for ad-hoc queries.

## Todo
- SSE on the S3 bucket
