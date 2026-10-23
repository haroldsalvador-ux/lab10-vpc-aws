#!/bin/bash
# Lab 10 - Reto: instancias de prueba para verificar la VPC RETO-LAB10
# Ejecutar en AWS CloudShell (us-east-2). No usa claves de acceso ni pares de llaves.
REGION=us-east-2
VPC=$(aws ec2 describe-vpcs --region $REGION --filters Name=tag:Name,Values=RETO-LAB10-vpc --query 'Vpcs[0].VpcId' --output text)
PUB=$(aws ec2 describe-subnets --region $REGION --filters Name=vpc-id,Values=$VPC Name=tag:Name,Values='*public1*' --query 'Subnets[0].SubnetId' --output text)
PRIV=$(aws ec2 describe-subnets --region $REGION --filters Name=vpc-id,Values=$VPC Name=tag:Name,Values='*private1*' --query 'Subnets[0].SubnetId' --output text)
AMI=$(aws ssm get-parameter --region $REGION --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
PL=$(aws ec2 describe-managed-prefix-lists --region $REGION --filters Name=prefix-list-name,Values=com.amazonaws.$REGION.ec2-instance-connect --query 'PrefixLists[0].PrefixListId' --output text)

# Grupo de seguridad publico: HTTP desde Internet, SSH solo desde EC2 Instance Connect
SGPUB=$(aws ec2 create-security-group --region $REGION --group-name RETO-SG-PUBLICO --description "Web publico RETO" --vpc-id $VPC --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region $REGION --group-id $SGPUB --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region $REGION --group-id $SGPUB --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,PrefixListIds=[{PrefixListId=$PL}]"

# Grupo de seguridad privado: solo acepta trafico desde el grupo publico
SGPRIV=$(aws ec2 create-security-group --region $REGION --group-name RETO-SG-PRIVADO --description "Privado RETO solo desde SG publico" --vpc-id $VPC --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region $REGION --group-id $SGPRIV --protocol icmp --port -1 --source-group $SGPUB
aws ec2 authorize-security-group-ingress --region $REGION --group-id $SGPRIV --protocol tcp --port 22 --source-group $SGPUB

printf '#!/bin/bash\ndnf install -y httpd\necho "<h1>RETO LAB10 - EC2 en subred publica OK</h1>" > /var/www/html/index.html\nsystemctl enable --now httpd\n' > web.sh

aws ec2 run-instances --region $REGION --image-id $AMI --instance-type t3.micro --subnet-id $PUB --security-group-ids $SGPUB \
  --associate-public-ip-address --user-data file://web.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=RETO-EC2-PUBLICA}]' --query 'Instances[0].InstanceId' --output text
aws ec2 run-instances --region $REGION --image-id $AMI --instance-type t3.micro --subnet-id $PRIV --security-group-ids $SGPRIV \
  --no-associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=RETO-EC2-PRIVADA}]' --query 'Instances[0].InstanceId' --output text
