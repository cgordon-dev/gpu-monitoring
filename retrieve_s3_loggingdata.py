import boto3
import json
import pandas as pd
import os

# -------------------------------
# Configuration
# -------------------------------
BUCKET_NAME = "aws-gpu-monitoring-logs"  # Replace with your valid bucket name
PREFIX = ""  # Adjust if logs are stored in a specific folder
OUTPUT_CSV = "aws_gpu_monitoring_logs_exploded.csv"

# -------------------------------
# Initialize S3 Client
# -------------------------------
s3 = boto3.client("s3")

def list_log_keys(bucket, prefix=""):
    """List all object keys in the specified S3 bucket under an optional prefix."""
    keys = []
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        if "Contents" in page:
            for obj in page["Contents"]:
                keys.append(obj["Key"])
    return keys

def get_log_content(bucket, key):
    """Download an object from S3 and return its content as a JSON object."""
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8")
    return json.loads(content)

def flatten_record(record):
    """Flatten a nested JSON record using pandas.json_normalize."""
    df = pd.json_normalize(record, sep='_')
    return df.to_dict(orient='records')[0]

def process_reservations_in_row(row):
    """Process the 'instance_data.Reservations' field in a DataFrame row."""
    base_data = row.to_dict()
    reservations = base_data.pop("instance_data_Reservations", "[]")
    
    try:
        reservations = json.loads(reservations) if isinstance(reservations, str) else reservations
    except json.JSONDecodeError:
        reservations = []
    
    new_rows = []
    for res in reservations:
        flat_res = pd.json_normalize(res, sep='_').to_dict(orient='records')[0]
        
        # Extract relevant fields
        flat_res["ReservationId"] = res.get("ReservationId", "")
        flat_res["OwnerId"] = res.get("OwnerId", "")
        instances = res.get("Instances", [])
        
        if instances:
            instance_data = instances[0]  # Assuming first instance is primary
            flat_res.update({
                "InstanceId": instance_data.get("InstanceId", ""),
                "InstanceType": instance_data.get("InstanceType", ""),
                "PrivateIpAddress": instance_data.get("PrivateIpAddress", ""),
                "PublicIpAddress": instance_data.get("PublicIpAddress", ""),
                "State": instance_data.get("State", {}).get("Name", ""),
                "SecurityGroups": ", ".join([group.get("GroupName", "") for group in instance_data.get("SecurityGroups", [])]),
                "LaunchTime": instance_data.get("LaunchTime", ""),
                "KeyName": instance_data.get("KeyName", ""),
                "ImageId": instance_data.get("ImageId", ""),
                "SubnetId": instance_data.get("SubnetId", ""),
                "VpcId": instance_data.get("VpcId", ""),
                "AmiLaunchIndex": int(float(instance_data.get("AmiLaunchIndex", 0))),
                "Placement_AvailabilityZone": instance_data.get("Placement", {}).get("AvailabilityZone", ""),
            })
        
        combined = base_data.copy()
        combined.update(flat_res)
        new_rows.append(combined)
    
    return new_rows if new_rows else [base_data]

def load_existing_csv():
    """Load existing CSV data if available."""
    if os.path.exists(OUTPUT_CSV):
        return pd.read_csv(OUTPUT_CSV)
    return pd.DataFrame()

def main():
    print("Retrieving all log files from S3...")
    log_files = list_log_keys(BUCKET_NAME, PREFIX)
    if not log_files:
        print("No log files found in S3.")
        return
    
    existing_df = load_existing_csv()
    processed_keys = set(existing_df["s3_key"].unique()) if not existing_df.empty else set()
    
    new_records = []
    for log_file in log_files:
        if log_file in processed_keys:
            continue  # Skip already processed logs
        
        print(f"Processing log file: {log_file}")
        log_data = get_log_content(BUCKET_NAME, log_file)
        log_data['s3_key'] = log_file
        flat_record = flatten_record(log_data)
        
        # Ensure 'estimated_hourly_cost' is correctly extracted
        flat_record["estimated_hourly_cost"] = log_data.get("estimated_hourly_cost", "N/A")
        
        for k, v in flat_record.items():
            if isinstance(v, (list, dict)):
                flat_record[k] = json.dumps(v)
        
        df = pd.DataFrame([flat_record])
        for index, row in df.iterrows():
            new_records.extend(process_reservations_in_row(row))
    
    if new_records:
        new_df = pd.DataFrame(new_records)
        
        # Remove redundant 'Instances' column
        if 'Instances' in new_df.columns:
            new_df.drop(columns=['Instances'], inplace=True)
        
        # Fill missing metadata fields
        metadata_fields = ["SecurityGroups", "LaunchTime", "KeyName", "ImageId", "SubnetId", "VpcId", "AmiLaunchIndex", "Placement_AvailabilityZone"]
        for field in metadata_fields:
            if field in new_df.columns:
                new_df[field] = new_df[field].fillna("Unknown")
        
        updated_df = pd.concat([existing_df, new_df], ignore_index=True)
        updated_df.to_csv(OUTPUT_CSV, index=False)
        print(f"Data updated and saved to {OUTPUT_CSV}")
    else:
        print("No new logs found.")

if __name__ == "__main__":
    main()

