#!/bin/sh
inputFile=$1
outputFile=$2

count=$(cat $inputFile | jq '.machines[]' |grep 'name' | wc -l)

a=0
result="succeed"


cat > /tmp/ec2_instances << END
{
    "ec2": {
        "instances": [
        ]
    }
}
END

while [ $a -lt $count ]
do
  hostName=$(cat $inputFile | jq '.machines['${a}'].name')
  publicIp=$(cat $inputFile | jq '.machines['${a}'].publicIpAddress')
  privateIp=$(cat $inputFile | jq '.machines['${a}'].privateIpAddress')
  instanceId=$(cat $inputFile | jq '.machines['${a}'].machineId')
  rcAccount=$(cat $inputFile | jq '.machines['${a}'].rc_account')

  #add your custom code here for each machine in the request
  #write the output of each machine to the output json file

  sed -i '/]/i {\"name\": '${hostName}', \"result\": \"'${result}'\", \"message\": \"'${message}'\" }' $outputFile
  sed -i '/]/i {\"public_dns_name\": '${publicIp}', \"public_ip\": '${publicIp}', \"id\": '${instanceId}', \"private_dns_name\": '${hostName}', \"private_ip\": '${privateIp}', \"block_device_mapping\": \"\"},' /tmp/ec2_instances
  a=`expr $a + 1`
done

#remove redundant comma to have a valid json file
sed -i ':begin;$!N;s/},\n\s*]/}\n\t]/;tbegin;P;D' /tmp/ec2_instances

cd /opt/ibm/lsf_installer/; nohup ansible-playbook -i lsf-inventory make-lsf-server.yml  --extra-vars "@/tmp/ec2_instances" > /dev/null 2>&1 &
