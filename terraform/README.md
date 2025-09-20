This folder contains infrastructure definition of AWS for this project. Infrastructure is handled using Terraform (Infra as Code). TO deploy, run "terraform apply" in the terminal.



AWS Infrastructure :

-SQS queue to read events with the relevant IAM role. 

-Lamba function (python) loads the data from the SQS queue to S3



