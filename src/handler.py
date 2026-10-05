"""
document-management: AWS Lambda handler (reference implementation)

Invocation modes
----------------
1. S3 event (ObjectCreated)      -> stores the new object's metadata in Amazon RDS for MySQL
2. {"action": "get_download_url", "object_key": "<key>"}
                                 -> returns a time-limited pre-signed download URL
3. {"action": "list_documents"}  -> returns the 50 most recent metadata rows (for verification)

Database credentials are read from AWS Secrets Manager at runtime (never hard-coded).
"""

import json
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3
import pymysql
import pymysql.cursors

SECRET_NAME = os.environ["SECRET_NAME"]
DB_NAME = os.environ["DB_NAME"]
BUCKET_NAME = os.environ.get("BUCKET_NAME", "")
URL_EXPIRY_SECONDS = int(os.environ.get("PRESIGNED_URL_EXPIRY_SECONDS", "900"))

_secrets = boto3.client("secretsmanager")
_s3 = boto3.client("s3")
_secret_cache = None

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS document_metadata (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    bucket_name      VARCHAR(255)  NOT NULL,
    object_key       VARCHAR(1024) NOT NULL,
    file_name        VARCHAR(512)  NOT NULL,
    file_size_bytes  BIGINT        NOT NULL,
    storage_class    VARCHAR(64)   NOT NULL,
    upload_timestamp DATETIME      NOT NULL,
    created_at       TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_upload_timestamp (upload_timestamp)
)
"""

INSERT_SQL = """
INSERT INTO document_metadata
    (bucket_name, object_key, file_name, file_size_bytes, storage_class, upload_timestamp)
VALUES (%s, %s, %s, %s, %s, %s)
"""


def _db_credentials():
    """Fetch (and cache for warm invocations) the DB credentials from Secrets Manager."""
    global _secret_cache
    if _secret_cache is None:
        response = _secrets.get_secret_value(SecretId=SECRET_NAME)
        _secret_cache = json.loads(response["SecretString"])
    return _secret_cache


def _connect(dict_cursor=False):
    creds = _db_credentials()
    return pymysql.connect(
        host=creds["host"],
        port=int(creds.get("port", 3306)),
        user=creds["username"],
        password=creds["password"],
        database=DB_NAME,
        charset="utf8mb4",
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor if dict_cursor else pymysql.cursors.Cursor,
    )


def _parse_event_time(value):
    """S3 event times look like 2026-01-13T10:15:30.123Z; MySQL DATETIME wants no 'Z'."""
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%S.%fZ")
    except (TypeError, ValueError):
        return datetime.now(timezone.utc).replace(tzinfo=None)


def _response(status, body):
    return {"statusCode": status, "body": json.dumps(body, default=str)}


# ---------------------------------------------------------------------------
# Mode 1: S3 ObjectCreated event -> metadata row
# ---------------------------------------------------------------------------
def _handle_s3_event(event):
    conn = _connect()
    stored = 0
    try:
        with conn.cursor() as cur:
            cur.execute(CREATE_TABLE_SQL)
            for record in event["Records"]:
                bucket = record["s3"]["bucket"]["name"]
                key = unquote_plus(record["s3"]["object"]["key"])  # keys arrive URL-encoded
                size = record["s3"]["object"].get("size", 0)
                head = _s3.head_object(Bucket=bucket, Key=key)
                storage_class = head.get("StorageClass", "STANDARD")
                cur.execute(
                    INSERT_SQL,
                    (
                        bucket,
                        key,
                        key.rsplit("/", 1)[-1],
                        size,
                        storage_class,
                        _parse_event_time(record.get("eventTime")),
                    ),
                )
                stored += 1
        conn.commit()
    finally:
        conn.close()
    print(f"Stored metadata for {stored} object(s)")
    return _response(200, {"stored": stored})


# ---------------------------------------------------------------------------
# Mode 2: pre-signed download URL
# ---------------------------------------------------------------------------
def _handle_download_url(event):
    key = event.get("object_key")
    if not key:
        return _response(400, {"message": "object_key is required"})

    head = _s3.head_object(Bucket=BUCKET_NAME, Key=key)

    # Objects in Glacier Flexible Retrieval cannot be read until they are restored.
    if head.get("StorageClass") in ("GLACIER", "DEEP_ARCHIVE"):
        restore_status = head.get("Restore", "")
        if 'ongoing-request="false"' not in restore_status:
            return _response(
                409,
                {
                    "message": "Object is archived. Request a restore (aws s3api restore-object) "
                    "and retry once the restore has completed.",
                    "storage_class": head.get("StorageClass"),
                    "restore_status": restore_status or "not requested",
                },
            )

    url = _s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET_NAME, "Key": key},
        ExpiresIn=URL_EXPIRY_SECONDS,
    )
    return _response(200, {"url": url, "expires_in_seconds": URL_EXPIRY_SECONDS})


# ---------------------------------------------------------------------------
# Mode 3: list recent metadata rows
# ---------------------------------------------------------------------------
def _handle_list_documents():
    conn = _connect(dict_cursor=True)
    try:
        with conn.cursor() as cur:
            cur.execute(CREATE_TABLE_SQL)
            cur.execute(
                "SELECT id, bucket_name, object_key, file_name, file_size_bytes, "
                "storage_class, upload_timestamp FROM document_metadata "
                "ORDER BY upload_timestamp DESC LIMIT 50"
            )
            rows = cur.fetchall()
    finally:
        conn.close()
    return _response(200, {"count": len(rows), "documents": rows})


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def lambda_handler(event, context):
    if event.get("Records") and event["Records"][0].get("eventSource") == "aws:s3":
        return _handle_s3_event(event)

    action = event.get("action")
    if action == "get_download_url":
        return _handle_download_url(event)
    if action == "list_documents":
        return _handle_list_documents()

    return _response(400, {"message": "Unsupported event"})
