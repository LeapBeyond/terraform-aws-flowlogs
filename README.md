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

## Todo
- SSE on the S3 bucket
