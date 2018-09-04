# AWS-config.yml

The AWS-config.yml file contains the configuration parameters needed to create the LSF Cluster on AWS.  Use the instructions below to set the values appropriate for your account.

It is necessary to choose the type of LSF cluster to deploy early in the process.  This is done by editing the AWS/AWS-config.yml file.  For a LSF Stretch cluster change the file as follows:

'''bash
\# What type of cluster to deploy.  Uncomment one of these

\#multi_cluster: true

hybrid_cluster: true
'''

For a LSF Multi Cluster deployment change the file setting to:

'''bash
\# What type of cluster to deploy.  Uncomment one of these

multi_cluster: true

\#hybrid_cluster: true
'''

If these values are changed it will be necessary to use the Cleanup.yml playbook to reset the configuration.  

If you have an existing VPC, it is possible to skip this step by taking the related information and populating the AWS-config.yml file.
Make a backup copy of the AWS/AWS-config.yml file.  Edit the AWS/AWS-config.yml file, and set the appropriate values.

###AWS_Region:   		
Set this to the region you wish to deploy in

###AWS_Access_Key: 	
Set this to the Access Key for the AWS user account that is being used to deploy to the cloud.  This is needed for the duration of the deployment.  Once the cluster is deployed on the cloud these values can be deleted. Begins with: AK

###AWS_Secret_Key: 	
Set this to the Secret Key for the AWS user account that is being used to deploy to the cloud.  This is needed for the duration of the deployment.  Once the cluster is deployed on the cloud these values can be deleted. 

###AWS_Instance_Type: 
Set this to the size of the instance you want to create e.g. t2.micro

###AMS_Image: 
Set this to AMI ID for the image you want to deploy.  The default is a CentOS 7 image e.g.  ami-77724e12

###AWS_VPC_CIDR: 
Set this to the IPv4 address block you wish to use for the VPC.  This address block must not overlap with any addresses on the on-premises network, or the VPN network, e.g.  10.1.0.0/16

###AWS_VPC_PUB_CIDR: 
Set this to the IPv4 address block for the private network on EC2.  This subnet must be inside the AWS_VPC_CIDR address block e.g. 10.1.0.0/24

###CLIENT_NET: 10.10.10.0
###CLIENT_MASK: 255.255.255.0
Set these to the IPv4 network address and subnet mask for the on premises network that will be routed to the cloud servers.  The LSF master must be part of this network.  If Direct Connect is used this data is ignored.

###SERVER_IP: 10.0.11.1
###SERVER_NET: 10.0.11.0
SERVER_MASK: 255.255.255.0
These values are only used to control the VPN IP address of the on cloud instance providing the VPN.  Make sure these values do not overlap with any other networks.  If Direct Connect is used this data is ignored.

The following values need to be set when an existing VPC is to be used:

###AWS_VPC:
Set this to the VPC ID, or leave it as none to have the playbook generate it

###AWS_VPC_PRV_Subnet:
Set this to the Subnet ID of the private network of the EC2 instances, or leave it as none to have the playbook generate it. 

###AWS_VPC_IGW:
Set this to the Internet Gateway ID in the VPC, or leave it as none to have the playbook generate it. 

###AWS_VPC_Routes:
Set this to the VPC Routes ID, or leave it as none to have the playbook generate it.

###AWS_VPC_NACLs: none
Set this to the VPC Network ACLs ID, or leave it as none to have the playbook generate it.

###AWS_VPC_Security_Group:
Set this to the VPC Security Group ID to use, or leave it as none to have the playbook generate it.

###AWS_Key_Name:
Set this to the name of the SSH key that was generated in IAM for the AWS user you are using to deploy the LSF cluster.  If you do not have one, one will be generated.  The associated “.pem” file should be downloaded and placed in the AWS directory.

