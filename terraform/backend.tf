terraform {
  backend "s3" {
    # Remote state stored in S3 - change bucket name to your unique bucket
    bucket         = "fintech-terraform-state-bucket"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true

    # DynamoDB table for state locking - prevents concurrent applies
    # This prevents two people from running terraform apply at the same time
    dynamodb_table = "fintech-terraform-lock"
  }
}

# ---------------------------------------------------------------
# HOW TO SET UP REMOTE STATE (run these AWS CLI commands once):
#
# aws s3api create-bucket \
#   --bucket fintech-terraform-state-bucket \
#   --region ap-south-1 \
#   --create-bucket-configuration LocationConstraint=ap-south-1
#
# aws s3api put-bucket-versioning \
#   --bucket fintech-terraform-state-bucket \
#   --versioning-configuration Status=Enabled
#
# aws dynamodb create-table \
#   --table-name fintech-terraform-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region ap-south-1
# ---------------------------------------------------------------
