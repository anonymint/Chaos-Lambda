import os
import random
from time import strftime, gmtime
import boto3

REGIONS_VAIRABLE_NAME = "regions"
ASG_GROUP_NAME = "asg_group_name"
ASG_TERMINATION_TAG = "chaos-termination-prob"
TERMINATION_UNLEASH_NAME = "unleash_chaos"
PROBABILITY_NAME = "probability"
ALERT_ARN_NAME = "sns_alert_arn"
TARGET_ACCOUNT_NAME = "target_accounts"
DEFAULT_PROBABILITY = 1.0 / 6.0  # one in six of hours unit


def get_target_account(context):
    targets = os.environ.get(TARGET_ACCOUNT_NAME, "").strip()
    if len(targets) > 0:
        return [t.strip() for t in targets.split(",")]
    else:
        return [context.invoked_function_arn.split(":")[4]]


def get_regions(context):
    regions = os.environ.get(REGIONS_VAIRABLE_NAME, "").strip()
    if len(regions) > 0:
        # if provided environments variables regions
        return [r.strip() for r in regions.split(",")]
    else:
        # default get region from lambda arn
        return [context.invoked_function_arn.split(":")[3]]


def get_global_probability(default):
    prob = os.environ.get(PROBABILITY_NAME, "").strip()
    if len(prob) == 0:
        return DEFAULT_PROBABILITY

    return convert_valid_prob_float(prob, default)


def run_chaos(accounts, regions, default_prob):
    results = []
    for account in accounts:
        for region in regions:
            asgs = get_asgs(account, region)
            instances = get_termination_instances(asgs, default_prob)
            results.extend(run_chaos_each_account_region(account, instances, region))
    return results


def get_asgs(account, region):
    given_asg = os.environ.get(ASG_GROUP_NAME, "").strip()
    asgs = assumRole(account, "autoscaling", region)
    for res in asgs.get_paginator("describe_auto_scaling_groups").paginate():
        for asg in res.get("AutoScalingGroups", []):
            if len(given_asg) > 0:
                group_names = given_asg.split(",")
                if asg['AutoScalingGroupName'] in group_names:
                    yield asg
            else:
                yield asg


def get_asg_tag(asg, tagname, default):
    for tag in asg.get("Tags", []):
        if tag.get("Key", "") == tagname:
            return tag.get("Value", "")
    return default


def get_probability(asg, default):
    custom_prob = get_asg_tag(asg, ASG_TERMINATION_TAG, None)
    if custom_prob is None:
        return default

    # check for valid number
    return convert_valid_prob_float(custom_prob, default)


def get_termination_instances(asgs, probability):
    termination_instances = []
    for asg in asgs:
        instances = asg.get("Instances", [])
        if len(instances) == 0:
            continue

        asg_prob = get_probability(asg, probability)
        # if asg_prob > random_figture then pick one to destroy
        if asg_prob > random.random():
            instance_id = random.choice(instances).get("InstanceId", None)
            termination_instances.append(
                (asg["AutoScalingGroupName"], instance_id))

    return termination_instances


def run_chaos_each_account_region(account, instances, region):
    unleash_chaos = os.environ.get(TERMINATION_UNLEASH_NAME, "").strip()
    results = []
    for i in instances:
        result = calling_tasks_random(account, i, region, dryrun=(not string_to_bool(unleash_chaos)))
        results.append(result)
    return results

# def terminate_no_point_of_return(account, instance, region):
#     ec2 = assumRole(account, "ec2", region)
#     ec2.terminate_instances(InstanceIds=[instance[1]])
#     result = "TERMINATE", instance[1], "from", instance[0], "in", region
#     printlog(result)
#     return result


# def terminate_dry_run(instance, region):
#     result = "Terminate [DRY-RUN] {} from {} in {}".format(instance[1],
#                                                            instance[0], region)
#     printlog(result)
#     return result


def printlog(*args):
    current = strftime("%Y-%m-%d %H:%M:%SZ", gmtime())
    print(current, *args)


def string_to_bool(s):
    if s.lower() in ["true", "t", "yes", "yeah", "yup", "y", "certainly",
                     "sure", "1"]:
        return True
    else:
        return False


def convert_valid_prob_float(value, default):
    """
    Helper method to check and convert float to valid probability value

    :param value: probability value supposed to be 0 - 1 range
    :type value: float
    :param default: default value if any error
    :type default: float
    :return: valid probability value
    :rtype: float
    """
    try:
        value = float(value)
    except ValueError:
        return default

        # check prob 0.0 - 1.0 only
    if value < 0 or value > 1:
        return default

    return value


def alert(data):
    alert_arn = os.environ.get(ALERT_ARN_NAME, '').strip()
    if len(alert_arn) > 0 and data:
        sns_client = boto3.client('sns')
        title = "Choas Engineer Team"
        message = 'Here is list of jobs we have done \n'
        message += ''.join(['\n * ' + d for d in data])
        sns_client.publish(TopicArn=alert_arn,
                           Subject=title,
                           Message=message)


def assumRole(account, service, region):
    sts_client = boto3.client('sts')
    assumeRoleObject = sts_client.assume_role(
        RoleArn='arn:aws:iam::' + account + ':role/chaos-engineer',
        RoleSessionName='AssumeRoleChaosEngineer'
    )

    credentials = assumeRoleObject['Credentials']
    client = boto3.client(
        service,
        region_name=region,
        aws_access_key_id=credentials['AccessKeyId'],
        aws_secret_access_key=credentials['SecretAccessKey'],
        aws_session_token=credentials['SessionToken'],
    )
    return client

"""
Chaos Tasks
"""
def calling_tasks_random(account, i, region, dryrun=True):
    random_task = random.randint(0, len(TASKS)-1)
    task_to_run, descritpion = TASKS[random_task]
    return task_to_run(account, i, region, dryrun) 


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

"""
Main Handler function
"""
def handler(event, context):
    """
    Main Lambda function
    """
    accounts = get_target_account(context)
    regions = get_regions(context)
    global_prob = get_global_probability(DEFAULT_PROBABILITY)
    result = run_chaos(accounts, regions, global_prob)
    alert(result)

# if __name__ == '__main__':
#     # calling_tasks_random("152303423357", ["asg","i-06d3fe93310a66d69"], "us-east-1", dryrun=True)
#     # max_cpu_worker("152303423357", ["asg","i-06d3fe93310a66d69"], "us-east-1", dryrun=False)
