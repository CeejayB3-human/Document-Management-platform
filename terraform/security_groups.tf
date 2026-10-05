# Security groups are created empty and rules are attached as separate
# resources, so the Lambda <-> RDS references do not create a dependency cycle.

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for the document-management Lambda function"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = var.rds_security_group_name
  description = "Security group for the Amazon RDS for MySQL instance"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = var.rds_security_group_name
  }
}

resource "aws_security_group" "vpce" {
  name        = "${var.project_name}-vpce-sg"
  description = "Security group for the Secrets Manager interface endpoint"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-vpce-sg"
  }
}

# --- Lambda egress: only RDS, the Secrets Manager endpoint and S3 -----------
resource "aws_vpc_security_group_egress_rule" "lambda_to_rds" {
  security_group_id            = aws_security_group.lambda.id
  description                  = "MySQL to RDS"
  referenced_security_group_id = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_vpce" {
  security_group_id            = aws_security_group.lambda.id
  description                  = "HTTPS to the Secrets Manager endpoint"
  referenced_security_group_id = aws_security_group.vpce.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_s3" {
  security_group_id = aws_security_group.lambda.id
  description       = "HTTPS to S3 through the gateway endpoint"
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# --- RDS ingress: MySQL from the Lambda security group only -----------------
resource "aws_vpc_security_group_ingress_rule" "rds_from_lambda" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from the Lambda function"
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

# --- Endpoint ingress: HTTPS from the Lambda security group only ------------
resource "aws_vpc_security_group_ingress_rule" "vpce_from_lambda" {
  security_group_id            = aws_security_group.vpce.id
  description                  = "HTTPS from the Lambda function"
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
