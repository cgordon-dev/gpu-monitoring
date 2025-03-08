#!/bin/bash
set -e

# Configuration
INSTANCE_ID="i-00ec148fae2a25772"  # Replace with your EC2 instance ID
TAG_KEY="InstanceID"               # If using tags for cost allocation
START_DATE="2025-03-01"            # Start date for cost queries
S3_BUCKET="aws-gpu-monitoring-logs"   # S3 bucket to store logs
LOG_DIR="/tmp/aws_monitoring_logs"
POLL_INTERVAL=30                # Polling interval in seconds (3600 sec = 1 hour)

# Create a local directory for logs
mkdir -p "$LOG_DIR"

while true; do
    TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S")
    LOG_FILE="$LOG_DIR/log_${TIMESTAMP}.json"
    
    echo "[$TIMESTAMP] Collecting data..."

    # Get EC2 instance details
    INSTANCE_DATA=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --output json)
    
    # Get overall EC2 cost data for a given period
    OVERALL_COST=$(aws ce get-cost-and-usage \
        --time-period Start="$START_DATE",End=$(date +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Compute Cloud - Compute"]}}' \
        --output json)
    
    # If you are using cost allocation tags, get cost data filtered by a tag (optional)
    TAG_COST=$(aws ce get-cost-and-usage \
        --time-period Start="$START_DATE",End=$(date +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --filter "{\"Tags\": {\"Key\": \"$TAG_KEY\", \"Values\": [\"$INSTANCE_ID\"]}}" \
        --output json)
    
    # Combine the data into a single JSON structure
    cat <<EOF > "$LOG_FILE"
{
  "timestamp": "$TIMESTAMP",
  "instance_data": $INSTANCE_DATA,
  "overall_cost": $OVERALL_COST,
  "tag_cost": $TAG_COST
}
EOF

    # Upload the log file to S3
    aws s3 cp "$LOG_FILE" s3://"$S3_BUCKET"/

    echo "[$TIMESTAMP] Data uploaded to s3://$S3_BUCKET/"

    # Wait for the next polling interval
    sleep "$POLL_INTERVAL"
done