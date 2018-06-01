"""
Chaos Tasks
"""

import random
from helper import *

def terminate_instance_worker(account, instance, region, dryrun=True):    
    if dryrun:
        result = "Terminate [DRY-RUN] {} from {} in {}".format(instance[1],
                                                           instance[0], region)
        printlog(result)
        return result
    else:    
        ec2 = assumRole(account, "ec2", region)
        ec2.terminate_instances(InstanceIds=[instance[1]])
        result = "TERMINATE", instance[1], "from", instance[0], "in", region
        printlog(result)
        return result


def max_cpu_worker(account, instance, region, dryrun=True):
    if dryrun:
        result = "Max out CPU [DRY-RUN] {} from {} in {}".format(instance[1],
                                                           instance[0], region)
        printlog(result)
        return result
    else:
        result = "Max out CPU {} from {} in {}".format(instance[1],
                                                           instance[0], region)
        ssm = assumRole(account, "ssm", region)
        resp = ssm.send_command(
            DocumentName="AWS-RunShellScript",
            Parameters={'commands': ["cat << EOF > /tmp/infiniteburn.sh","#!/bin/bash","while true;"," do openssl speed;","done","EOF","","# 32 parallel 100% CPU tasks should hit even the biggest EC2 instances","for i in {1..32}","do"," nohup /bin/bash /tmp/infiniteburn.sh > /dev/null 2>&1 &","done"]},
            InstanceIds=[instance[1]]
        )
        printlog(resp)
        return result

TASKS = [
    (terminate_instance_worker, "Terminate instances"),
    (max_cpu_worker, "Max out CPU")
]        

def calling_tasks_random(account, i, region, dryrun=True):
    random_task = random.randint(0, len(TASKS)-1)
    task_to_run, descritpion = TASKS[random_task]
    return task_to_run(account, i, region, dryrun) 