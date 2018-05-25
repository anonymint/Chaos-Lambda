# Infrastructure for master account

This is the account which is the main account that's going to schedule to run, randomlly pick up targets and apply chaos via assuming role we created in `infra_target`

## Optional predefine
By default, Terraform script will look for 

* Bucket `chaos-engineer-master` or anything unique which you need to update `main.tf` terraform backend to match this name.

## How to run

```
terraform init && terraform get

terraform plan -var-file="config/master.tfvar" -var 'hook_url=your_hook_url' -var 'target_accounts=target_account_1,target_account_2'

terraform apply -var-file="config/master.tfvar" -var 'hook_url=your_hook_url' -var 'target_accounts=target_account_1,target_account_2'

terraform destroy -var-file="config/master.tfvar" -var 'hook_url=your_hook_url' -var 'target_accounts=target_account_1,target_account_2'
```
