resource "aws_backup_vault" "this" {
  name = "${var.project_name}-backup-vault"
}

resource "aws_backup_plan" "daily" {
  name = "${var.project_name}-daily-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_retention_days
    }
  }
}

# --- IAM role assumed by the AWS Backup service ------------------------------
data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.project_name}-aws-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restores" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# --- Protect the metadata database ------------------------------------------
resource "aws_backup_selection" "rds" {
  name         = "${var.project_name}-rds-selection"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [aws_db_instance.metadata.arn]
}

# --- Backup job notifications -------------------------------------------------
resource "aws_sns_topic" "backup_notifications" {
  name = "${var.project_name}-backup-notifications"
}

data "aws_iam_policy_document" "backup_sns" {
  statement {
    sid       = "AllowAWSBackupToPublish"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.backup_notifications.arn]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "backup_notifications" {
  arn    = aws_sns_topic.backup_notifications.arn
  policy = data.aws_iam_policy_document.backup_sns.json
}

resource "aws_backup_vault_notifications" "this" {
  backup_vault_name   = aws_backup_vault.this.name
  sns_topic_arn       = aws_sns_topic.backup_notifications.arn
  backup_vault_events = ["BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED", "RESTORE_JOB_COMPLETED"]

  depends_on = [aws_sns_topic_policy.backup_notifications]
}

resource "aws_sns_topic_subscription" "backup_email" {
  count = var.alert_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
