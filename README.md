# AWS ECS Tutorial
## use terraform

## use cli
### create ECSTaskRole and ECSTaskExecRole
```sh
name="app1"
aws iam create-role \
  --role-name ${name}ECSTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ecs-tasks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }'

  aws iam create-role \
  --role-name ${name}ECSExecTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ecs-tasks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }'  
```
### Attach the policy
```sh
name="app1"
aws iam attach-role-policy \
  --role-name ${name}ECSTaskRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  
aws iam attach-role-policy \
  --role-name ${name}ECSExecTaskRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### create task defination
- use command below to register task `task-def.json`
```
aws ecs register-task-definition --cli-input-json file://nginx-task.json
```

### Create ECS Service with task-def
#### create sg and rule policy
```
aws ec2 create-security-group \
  --group-name nginx-sg \
  --description "Allow HTTP from anywhere" \
  --vpc-id vpc-0621bf0e1105ee58e

aws ec2 authorize-security-group-ingress \
  --group-id sg-04aeba1a978ddf56a \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

#### create service
```
clusterName="andromedra"
serviceName="app1"
taskDefName="app1"
subnet="subnet-0cd41348bd023a40c"
sgId="sg-04aeba1a978ddf56"

aws ecs create-service \
  --cluster ${clusterName} \
  --service-name ${serviceName} \
  --task-definition ${taskDefName} \
  --launch-type FARGATE \
  --desired-count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[${subnet}],securityGroups=[${sgId}],assignPublicIp=ENABLED}" \
  --enable-execute-command
```

### ALB or NLB
#### Public ALB usecase
- create sg
```sh
name="app1"
vpcId="vpc-0621bf0e1105ee58e"

aws ec2 create-security-group \
  --group-name ${name}-alb-sg \
  --description "Allow HTTP from anywhere" \
  --vpc-id ${vpcId} 

sgId="sg-0d131d6ca7bc0a5f9"
allowPort="80"
allowCird="0.0.0.0/"

aws ec2 authorize-security-group-ingress \
  --group-id ${sgId} \
  --protocol tcp \
  --port ${allowPort} \
  --cidr ${allowCird} 
```

- create alb
```sh
albName="public-alb"
subnet1="subnet-0962b009e239b1e7a"
subnet2="subnet-08a543c4e3cfa38e4"
sgName="sg-0d131d6ca7bc0a5f9"

aws elbv2 create-load-balancer \
  --name ${albName} \
  --subnets ${subnet1} ${subnet2} \
  --scheme internet-facing \
  --security-groups ${sgName} 
```

- create target-group
```sh
targetGroupName="app1-tg"
targetGroupPort="80"
vpcId="vpc-0621bf0e1105ee58"

aws elbv2 create-target-group \
  --name ${targetGroupName} \
  --protocol HTTP \
  --port ${targetGroupPort} \
  --vpc-id ${vpcId} \
  --target-type ip
```

- create listener
```sh
albArn="arn:aws:elasticloadbalancing:ap-southeast-1:058264383156:loadbalancer/app/public-alb/a2bbb570ad4581c"
listenerPort="80"
targetGroupArn="arn:aws:elasticloadbalancing:ap-southeast-1:058264383156:targetgroup/nginx-ecs-tg/4dd37de257fd0495"

aws elbv2 create-listener \
  --load-balancer-arn ${albArn} \
  --protocol HTTP \
  --port ${listenerPort} \
  --default-actions Type=forward,TargetGroupArn=${targetGroupArn}
```

- update service 
```sh
clusterName="andromedra-dacx2"
serviceName="app1"
albArn="arn:aws:elasticloadbalancing:ap-southeast-1:058264383156:targetgroup/nginx-ecs-tg/4dd37de257fd0495"
containerName="nginx"
containerPort="80"

aws ecs update-service \
  --cluster ${clusterName} \
  --service ${serviceName} \
  --force-new-deployment \
  --load-balancers "targetGroupArn=${albArn},containerName=${containerName},containerPort=${containerPort}"
```
- 

#### Private NLB usecase
- create nlb
```sh
name="app1"
subnet1="subnet-0962b009e239b1e7"
subnet2="subnet-0f31bbdb37a20368"

aws elbv2 create-load-balancer \
  --name ${name}-internal-nlb \
  --subnets $subnet1 $subnet2 \
  --scheme internal \
  --type network
```

- create nlb target-group
```
name="app1"
vpcID="vpc-0621bf0e1105ee58"

aws elbv2 create-target-group \
  --name ${name}-tg \
  --protocol TCP \
  --port 80 \
  --vpc-id ${vpcID} \
  --target-type ip
```

- create nlb listener
```sh
name="app1"
nlbArn="arn:aws:elasticloadbalancing:ap-southeast-1:058264383156:loadbalancer/net/private-nlb/163770ee63432810"
targetGroupArn="arn:aws:elasticloadbalancing:ap-southeast-1:058264383156:targetgroup/nginx-tg/4961709c83e52f29"

aws elbv2 create-listener \
  --load-balancer-arn ${nlbArn} \
  --protocol TCP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=${targetGroupArn}
```

- update ecs service
```sh
name="app1"
clusterName="andromedra"
serviceName="app1"
nlbArn="arn:aws:elasticloadbalancing:ap-southeast-1:058264383156:loadbalancer/net/private-nlb/163770ee63432810"
targetGroupArn="arn:aws:elasticloadbalancing:ap-southeast-1:058264383156:targetgroup/nginx-tg/4961709c83e52f29"
containerName="nginx"
containerPort="80"

aws ecs update-service \
  --cluster ${clusterName} \
  --service ${serviceName} \
  --force-new-deployment \
  --load-balancers "targetGroupArn=${targetGroupArn},containerName=${containerName},containerPort=${containerPort}"
```

# ECR 
- login
```
aws ecr get-login-password --region ap-southeast-1 \
| docker login --username AWS \
--password-stdin 058264383156.dkr.ecr.ap-southeast-1.amazonaws.com
```

- push
```
docker tag api-optimized:latest 058264383156.dkr.ecr.ap-southeast-1.amazonaws.com/nginx:latest
docker push 058264383156.dkr.ecr.ap-southeast-1.amazonaws.com/nginx:latest

```





