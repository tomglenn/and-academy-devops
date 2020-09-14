variable "env" {
    default = "dev"
}

resource "aws_s3_bucket" "test" {
    bucket = "tomglenn-test123-${var.env}"
}