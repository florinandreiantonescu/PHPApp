# Provider configuration
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAZ7K3HF6VGLNKBSCN"
  secret_key = "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"
}

# S3 Bucket
resource "aws_s3_bucket" "php-code" {
  bucket = "php-code-bucket"

  tags = {
    Name = "S3 Bucket for the code"
  }
}

# Define the template file
data "template_file" "php_file" {
  template = "/home/andrei/Downloads/counts.php"

  vars = {
    mysql_hostname = aws_db_instance.mysql_db.endpoint
    mysql_username = aws_db_instance.mysql_db.username
    mysql_password = aws_db_instance.mysql_db.password
    mysql_database = aws_db_instance.mysql_db.db_name
  }
}

# Upload PHP file to S3 bucket
resource "aws_s3_bucket_object" "php-file" {
  bucket = aws_s3_bucket.php-code.id
  key    = "counts.php"  # The key represents the file name in the S3 bucket
  source = "/home/andrei/Downloads/counts.php"  # Replace with the path to your local PHP file

  # Optional: Content type of the file
  content_type = "text/plain"
}

resource "aws_iam_role" "beanstalk_instance_role" {
  name = "beanstalk-instance-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "beanstalk_instance_profile" {
  name = "beanstalk-instance-profile"
  role = aws_iam_role.beanstalk_instance_role.name
}


# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "php-app-prod" {
  name        = "PHPapplication"
  description = "Simple PHP application"

  tags = {
    Name = "PHPapplication"
  }
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "php-app-prod-env" {
  name                = "PHPenvironment"
  application         = aws_elastic_beanstalk_application.php-app-prod.name
  solution_stack_name = "64bit Amazon Linux 2 v3.5.8 running PHP 8.0"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.beanstalk_instance_profile.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "2"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"
  }

#   setting {
#     namespace = "aws:elasticbeanstalk:environment:process:default"
#     name      = "HealthCheckPath"
#     value     = "s3://${aws_s3_bucket.php-code.bucket}/index.php"
#   }

  # Environment variables
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VISIT_COUNT_DB_HOST"
    value     = aws_db_instance.mysql_db.endpoint
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VISIT_COUNT_DB_PORT"
    value     = aws_db_instance.mysql_db.port
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "RDS_HOSTNAME"
    value     = aws_db_instance.mysql_db.address
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "RDS_USERNAME"
    value     = aws_db_instance.mysql_db.username
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "RDS_PASSWORD"
    value     = aws_db_instance.mysql_db.password
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PHP_FILE_URL"
    value     = "s3://${aws_s3_bucket.php-code.bucket}/counts.php"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = "/home/andrei/Documents/id_rsa" # Replace with the path to your private key file
    host        = aws_elastic_beanstalk_environment.php-app-prod-env.cname
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Running remote-exec provisioner'",
      "echo 'This is a sample command executed on the EC2 instance'",
    ]
  }

  # Load balancer configuration
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

#   # SSL Certificate
#   setting {
#     namespace = "aws:elbv2:listener:443"
#     name      = "ListenerEnabled"
#     value     = "true"
#   }

#   setting {
#     namespace = "aws:elbv2:listener:443"
#     name      = "Protocol"
#     value     = "HTTPS"
#   }

#   setting {
#     namespace = "aws:elbv2:listener:443"
#     name      = "SSLCertificateArns"
#     value     = aws_acm_certificate.ssl_certificate.arn
#   }

  # Beats Installation
  provisioner "remote-exec" {
  inline = [
    "sudo yum update -y",
    "sudo yum install -y wget",
    "sudo wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.15.1-x86_64.rpm",
    "sudo rpm -vi filebeat-7.15.1-x86_64.rpm"
    # Add additional configuration and setup commands for Filebeat as needed
  ]
}
}

# Additional EC2 instance for Elastic Stack configuration
resource "aws_instance" "elk_instance" {
  ami           = "ami-0715c1897453cabd1"
  instance_type = "t2.micro"

  user_data = <<-EOF
    #!/bin/bash
    echo "Installing Elasticsearch..."
    sudo yum install -y https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.15.1-x86_64.rpm

    echo "Installing Logstash..."
    sudo yum install -y https://artifacts.elastic.co/downloads/logstash/logstash-7.15.1.rpm

    echo "Installing Kibana..."
    sudo yum install -y https://artifacts.elastic.co/downloads/kibana/kibana-7.15.1-x86_64.rpm

    echo "Configuring Elasticsearch, Logstash, and Kibana..."
    # Add configuration commands for Elasticsearch, Logstash, and Kibana here

    echo "Starting Elasticsearch, Logstash, and Kibana services..."
    sudo systemctl enable elasticsearch
    sudo systemctl start elasticsearch
    sudo systemctl enable logstash
    sudo systemctl start logstash
    sudo systemctl enable kibana
    sudo systemctl start kibana

    echo "Installing Beats..."
    # Add installation commands for Beats (Filebeat, Metricbeat, etc.) here
  EOF

  tags = {
    Name = "ELKInstance"
  }
}

# RDS MySQL Database
resource "aws_db_instance" "mysql_db" {
  engine            = "mysql"
  instance_class    = "db.t2.micro"
  allocated_storage = 20
  username          = "administrator"
  password          = "greudeghicit1242"
  final_snapshot_identifier = "final-db-snapshot333456"  # Provide a unique identifier for the final snapshot

  tags = {
    Name = "MyDBInstance"
  }
}

# Outputs
output "mysql_hostname" {
  value = aws_db_instance.mysql_db.endpoint
}

output "mysql_username" {
  value = aws_db_instance.mysql_db.username
}

output "mysql_password" {
  value = aws_db_instance.mysql_db.password
  sensitive = true
}

output "mysql_database" {
  value = aws_db_instance.mysql_db.db_name
}

# # ACM SSL Certificate
# resource "aws_acm_certificate" "ssl_certificate" {
#   private_key      = file("path/to/private-key.pem")
#   certificate_body = file("path/to/certificate.pem")
# }
