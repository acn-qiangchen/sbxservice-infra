#!/bin/bash
# This script will clean up the existing firewall routes 
# to prepare for applying the new configuration

# Make sure AWS_PROFILE is set
export AWS_PROFILE=sbxservice-poc

echo "Cleaning up existing firewall routes..."

# Public route table in AZ-1 (us-east-1a) - rtb-02a53c058f832e253
echo "Cleaning public route table in AZ-1..."
aws ec2 delete-route --route-table-id rtb-02a53c058f832e253 --destination-cidr-block 10.0.10.0/24 || true
aws ec2 delete-route --route-table-id rtb-02a53c058f832e253 --destination-cidr-block 10.0.11.0/24 || true

# Public route table in AZ-2 (us-east-1b) - rtb-02342235b35bc8488
echo "Cleaning public route table in AZ-2..."
aws ec2 delete-route --route-table-id rtb-02342235b35bc8488 --destination-cidr-block 10.0.10.0/24 || true
aws ec2 delete-route --route-table-id rtb-02342235b35bc8488 --destination-cidr-block 10.0.11.0/24 || true

# Private route table in AZ-1 (us-east-1a) - rtb-0280ea83fd389c430
echo "Cleaning private route table in AZ-1..."
aws ec2 delete-route --route-table-id rtb-0280ea83fd389c430 --destination-cidr-block 10.0.0.0/24 || true
aws ec2 delete-route --route-table-id rtb-0280ea83fd389c430 --destination-cidr-block 10.0.1.0/24 || true

# Private route table in AZ-2 (us-east-1b) - rtb-02d2bf6d22d8bc3f4
echo "Cleaning private route table in AZ-2..."
aws ec2 delete-route --route-table-id rtb-02d2bf6d22d8bc3f4 --destination-cidr-block 10.0.0.0/24 || true
aws ec2 delete-route --route-table-id rtb-02d2bf6d22d8bc3f4 --destination-cidr-block 10.0.1.0/24 || true

echo "Clean up complete. Now you can run terraform apply." 