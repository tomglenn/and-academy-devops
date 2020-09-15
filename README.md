# and-academy-devops

## Notes

### 12 Factor App
12 Factor application breaks down the 12 factors that 
make an application a good citizen
https://12factor.net/

### LucidChart
LucidChart can be used for creating AWS diagrams

### Codefresh
Codefresh.io is a CI/CD tool like CircleCI/Jenkins that is geared towards Kubernetes applications

### AWS

#### Account Structure
- Root Account
    - Sub Account - dev
    - Sub Account - uat (staging)
    - Sub Account - production

**IAM** - Identity Access Management  
Can assign permissions to account via group controls

**ARN** - Amazon Resource Name  
Everything (including users) in AWS have an ARN which is a unique resource name.  

Through IAM you can assign any user permissions access to any resource (such as an S3 bucket) by assigning them the appropriate ARN access.

You can also use role based access. Processes such as CI/CD can run under a particular role.
Roles can have access to ARNs too.

Things which run *inside* AWS will have roles.  
Things which run *outside* AWS (such as Terraform) will have an actual user acccount.  
(Usually Terraform would run as an admin account.)

Terraform would be assigned admin access programatically via an ACCESS KEY.

## Day 1
- Create a new AWS account

- Within IAM create an `admin` account and `developer` account

- Go to Services -> AWS Organizations and create a new Organisation

- Create two sub-accounts within the organization
    - `dev` with role `OrganizationAccountAccessRole`
    - `uat` with role `OrganizationAccountAccessRole`

- Create new Role for uat - ReadOnlyRole
    - Give it ReadOnlyAccess

- Create a new Group in Root called Developers
    - Give it an inline policy
        - AWS Security Token Service
            - Action: AssumeRole
            - ARN for OrganizationAccountAccessRole in dev
        - AWS Security Token Service
            - Action: AssumeRole
            - ARN for ReadOnlyRole in uat

- Add the `developer` account to the `Developers` group

- Login as `developer` account

- Create a user `tf-admin` (`tom-terraform`)
    - Give programatic access and copy access keys
    - Give it AdministractorAccess

 - Within terminal set your environment vars.
    ```
    AWS_ACCESS_KEY_ID=<ACCESS KEY ID FOR TERRAFORM USER>
    AWS_SECRET_ACCESS_KEY=<SECRET KEY FOR TERRAFORM USER>
    AWS_REGION=eu-west-2
    ```

- Create a `main.tf` file
    ```
    resource "aws_s3_bucket" "test" {
        bucket = "tomglenn-test123"
    }
    ```

- Then run Terraform which will apply the config in `main.tf`
    ```
    terraform init
    terraform apply
    ```
- Create an account at terraform.io

- Create a new workspace with *Version Control Workflow* and connect your GitHub repo

- In AWS, login as admin and under `uat` create a new user for terraform `tf-deploy` with programmatic access. Copy down the keys.

- Back in terraform.io, click *Configure variables* and set your AWS access keys under Environment Variables

- In `main.tf` add a variable called `env` at the top of the file
    ```
    variable "env" {
        default = "dev"
    }
    ```

- Use this variable in the bucket name by adding `${var.env}` to the end of the bucket name

- In terraform.io add a terraform variable called env and call it `uat`.

- Copy code from https://github.com/and-digital/academy-devops-infra/blob/master/cluster.tf into your `main.tf`

- Run `terraform apply` to setup a whole web app

- Run `terraform destroy` to destroy the app and all infrastructure


## Day 2
- Create an account with codefresh.io

- Clone repo https://github.com/and-digital/and-devops-101

- Setup a codefresh pipeline for the new repository

- In your `main.tf` add a block to create an ecr repository
    ```
    resource "aws_ecr_repository" "main" {
        name = "toms-academy"
    }
    ```

- Next, add a block to create an IAM User in your `main.tf` file, this will be used to give codefresh access to upload the generated docker image to the ecr repository
    ```
    resource "aws_iam_user" "cf-deployer" {
        name = "codefresh"
    }
    ```

- We will also need to create a policy for that user, so again in `main.tf`
    ```
    resource "aws_iam_policy" "cf-deployer" {
    policy = jsonencode({
        Version: "2012-10-17",
        Statement: [
            {
            Effect: "Allow",
            Action: [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage",
            ],
            Resource: [ aws_ecr_repository.main.arn ]
            },
            {
            Effect: "Allow",
            Action: [
                "ecr:GetAuthorizationToken",
            ],
            Resource: "*"
            }
        ]
        })
    }
    ```

- Now attach the policy to the user we just created in `main.tf`
    ```
    resource "aws_iam_user_policy_attachment" "main" {
        policy_arn = aws_iam_policy.main.arn
        user = aws_iam_user.cf-deployer.name
    }
    ```

- Next create an access key for this user and output it
    ```
    resource "aws_iam_access_key" "cf-deployer" {
        user = aws_iam_user.cf-deployer.name
    }

    output "AWS_ACCESS_KEY_ID" {
    value = aws_iam_access_key.cf-deployer.id
    }

    output "AWS_SECRET_ACCESS_KEY" {
    value = aws_iam_access_key.cf-deployer.secret
    }
    ```

- 