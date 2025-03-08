import boto3
import json
import pandas as pd
import ast

# -------------------------------
# Configuration
# -------------------------------
BUCKET_NAME = "aws-gpu-monitoring-logs"  # Replace with your valid bucket name (no spaces)
PREFIX = ""  # If your logs are stored in a folder within the bucket, set the prefix here (e.g., "logs/")
OUTPUT_CSV = "aws_gpu_monitoring_logs_parsed.csv"

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
    """Download an object from S3 and return its content as a string."""
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8")
    return content

def flatten_record(record):
    """
    Flatten a nested JSON record using pandas.json_normalize.
    This uses '_' as a separator for nested keys.
    """
    df = pd.json_normalize(record, sep='_')
    return df.to_dict(orient='records')[0]

def parse_reservations(res_str):
    """
    Parse the instance_data.Reservations string and extract key fields.
    We use ast.literal_eval to convert the string representation into Python objects.
    Returns a dict with the extracted ReservationId, OwnerId, InstanceId, and InstanceType.
    """
    try:
        reservations = ast.literal_eval(res_str)
    except Exception as e:
        # If parsing fails, return empty values.
        return {
            "ReservationId": "",
            "OwnerId": "",
            "InstanceId": "",
            "InstanceType": ""
        }
    
    # If the reservations list exists and contains data, extract fields from the first reservation.
    if isinstance(reservations, list) and reservations:
        res = reservations[0]
        reservation_id = res.get("ReservationId", "")
        owner_id = res.get("OwnerId", "")
        instance_id = ""
        instance_type = ""
        if "Instances" in res and isinstance(res["Instances"], list) and res["Instances"]:
            instance = res["Instances"][0]
            instance_id = instance.get("InstanceId", "")
            instance_type = instance.get("InstanceType", "")
        return {
            "ReservationId": reservation_id,
            "OwnerId": owner_id,
            "InstanceId": instance_id,
            "InstanceType": instance_type
        }
    return {
        "ReservationId": "",
        "OwnerId": "",
        "InstanceId": "",
        "InstanceType": ""
    }

def main():
    print("Listing objects in S3 bucket...")
    keys = list_log_keys(BUCKET_NAME, PREFIX)
    print(f"Found {len(keys)} objects.")

    records = []
    for key in keys:
        try:
            content = get_log_content(BUCKET_NAME, key)
            data = json.loads(content)
            # Add the S3 key to the record for traceability.
            data['s3_key'] = key
            # Flatten the entire JSON record.
            flat_record = flatten_record(data)
            # Convert any list or dict values to JSON strings for CSV readability.
            for k, v in flat_record.items():
                if isinstance(v, (list, dict)):
                    flat_record[k] = json.dumps(v)
            records.append(flat_record)
        except Exception as e:
            print(f"Error processing {key}: {e}")

    if not records:
        print("No records found.")
        return

    # Create a DataFrame from the flattened records.
    df = pd.DataFrame(records)
    
    # If the 'instance_data.Reservations' column exists, parse it further.
    if "instance_data.Reservations" in df.columns:
        # Parse the reservations column to extract key fields.
        reservations_info = df["instance_data.Reservations"].apply(parse_reservations)
        # Convert the series of dicts into a DataFrame.
        reservations_df = pd.json_normalize(reservations_info)
        # Merge the extracted columns into the main DataFrame.
        df = pd.concat([df, reservations_df], axis=1)
        # Optionally, drop the original column if you no longer need it:
        # df.drop(columns=["instance_data.Reservations"], inplace=True)
    
    # Write the final DataFrame to CSV for Excel analysis.
    df.to_csv(OUTPUT_CSV, index=False)
    print(f"Data saved to {OUTPUT_CSV}")
    print(df.head())

if __name__ == "__main__":
    main()