resource "aws_db_instance" "metadata" {
  identifier     = var.db_instance_identifier
  engine         = "mysql"
  engine_version = "8.0"

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  multi_az          = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result
  port     = 3306

  # Private access only: no public endpoint, reachable from the Lambda security group.
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period    = var.db_backup_retention_days
  backup_window              = "02:00-02:30"
  maintenance_window         = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.db_instance_identifier}-final-snapshot"

  tags = {
    Name = var.db_instance_identifier
  }
}
