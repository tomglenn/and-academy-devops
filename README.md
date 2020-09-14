# and-academy-devops

## Notes
---
### 12 Factor App
12 Factor application breaks down the 12 factors that 
make an application a good citizen
https://12factor.net/

### LucidChart
LucidChart can be used for creating AWS diagrams

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

## Course Steps
---
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

- Then run Terraform which will apply the config in `main.tf`
    ```
    terraform init
    terraform apply
    ```
- 
