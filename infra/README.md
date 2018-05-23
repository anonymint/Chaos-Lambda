# Infrastructure for master account

This is the account which is the main account that's going to schedule to run, randomlly pick up targets and apply chaos via assuming role we created in `infra_target`

## Optional predefine
By default, Terraform script will look for 

* Bucket `chaos-engineer-master`

## How to run

```
terraform plan && terraform get

terraform plan -var 'master_account={13_digits_codes}' -var 'region={region_you_want}'

terraform apply -var 'master_account={13_digits_codes}' -var 'region={region_you_want}'

terraform destroy -var 'master_account={13_digits_codes}' -var 'region={region_you_want}'
```
