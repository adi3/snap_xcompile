#!/bin/bash

# Create s3 bucket
uuid=$(head -c 16 /proc/sys/kernel/random/uuid)
#echo $uuid
name=arm64-snap-$uuid
echo "Creating S3 bucket"
#aws s3 mb s3://$bucket

# Upload code files to bucket
#aws s3 cp src/ s3://$bucket/src --recursive
#aws s3 cp snap/ s3://$bucket/snap --recursive

# initiate cfn stack
echo "Setting up xcompile resources"
stack_arn=$(aws cloudformation create-stack \
	--stack-name $name \
	--template-body file://arm64_cfn.yaml \
	--parameters ParameterKey=S3BucketName,ParameterValue=$name \
	--capabilities CAPABILITY_IAM \
	--query "StackId" --output text)

echo "Stack Name: $name"
echo "Stack ARN: $stack_arn"

# while loop checking for stack outputs -> ec2 ID
echo "Spinning up EC2 instance"
ec2_id='None'

while [ $ec2_id == 'None' ]; do
	sleep 1
	ec2_id=$(aws cloudformation describe-stacks \
		--stack-name $stack_arn \
		--query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" \
		--output text)
	echo -e '.\c'
done

echo -e "\nInstance ID: $ec2_id"
echo "Initiating build"

# while loop fetching and printing user data output
# complete when user data finished
status=''

while [ -z $status ]; do
	aws ec2 get-console-output \
		--instance-id $ec2_id \
		--output text

	aws ec2 get-console-output \
		--instance-id $ec2_id \
		--output text \
		| tail -n 10 \
		| grep -i USER-DATA

	sleep 1

	status=$(aws ec2 get-console-output \
		--instance-id $ec2_id \
		--output text \
		| grep -i SNAPPING_COMPLETE)

	echo $status
	echo 'trying again'
done

echo 'exiting'

# download snap from s3

# delete cfn stack
# aws cloudformation delete-stack --stack-name myteststack

# delete s3 bucket

#--query "Stacks[0].Outputs[?OutputKey=='DbUrl'].OutputValue" --output text