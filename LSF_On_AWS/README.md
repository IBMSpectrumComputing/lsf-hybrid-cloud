# lsf-hybrid-cloud

## Overview
This repository contains sample code for building two varieties for LSF Hybrid Clouds.  LSF Stretch Clusters for extending an on premises LSF cluster using on cloud resources, and LSF Multi Clusters, for creating a second dynamic LSF cluster on cloud that on premises workload can automatically be forwarded to.

IBM® Spectrum LSF (formerly IBM® Platform™ LSF®) is a complete workload management solution for demanding HPC environments. Featuring intelligent, policy-driven scheduling and easy to use interfaces for job and workflow management, it helps organizations to improve competitiveness by accelerating research and design while controlling costs through superior resource utilization.

Please note, Spectrum LSF is not itself an application in the traditional sense, but instead provides an environment and framework for other applications to be managed and run in a load balanced efficient manner.   It is expected that you will install some kind of application(s) into this environment, or use application installed in your on premise environment to make proper evaluation use of the features and benefits of Spectrum LSF.

Additional videos that explain how to use this code are detailed below. 


The sample Ansible playbooks will create the LSF Hybrid cluster on AWS.  These playbooks should be taken and customized to meet your specific site requirements.

## Requirements
To use these playbooks you will need the following:
1. IBM Spectrum Suite 10.2.x Enterprise, HPC, or Workgroup editions (Note: Workgroup does not support the Multi Cluster install)
2. LSF Master with a YUM repository containing CentOS 7.5, or RHEL 7.5.  This is because of a dependency of the python2-boto3 package.

## Launching
The LSF Stretch cluster and LSF Multi clusters are all created using a series of Ansible playbooks.  These playbooks are used to perform the following steps in order:
1. Prepare the on premises LSF master to deploy the EC2 instances by installing the necessary software prerequisites.
2. Optionally creating a VPC from some minimal configuration
3. Optionally bringing up a VPN connection
4. Marshalling and preparing configuration files for the cloud machines
5. Launching EC2 instances for the LSF cluster
6. Optionally accessing on premises storage
7. Installing the LSF Stretch cluster or LSF Multi cluster

These playbooks are provided as a framework for customization.  Initially they can be run to create a simple on cloud cluster, but they are intended to be taken and customized to meet particular site needs.

## Prerequisites
Before deploying the LSF cluster we recommend that you become familiar with the Cloud services that will be used, currently:
1. **Amazon EC2** - The Amazon EC2 service enables you to launch virtual machine instances with a variety of operating systems. 
2. **Amazon VPC** - The Amazon VPC service lets you provision a private, isolated section of the AWS Cloud where you can launch AWS services and other resources in a virtual network that you define.
3. **IAM** - AWS Identity and Access Management (IAM) enables you to securely control access to AWS services and resources for your users.

As you explore the configuration of the cluster other services may also be needed such as EBS, EFS, and the network connection services.

### Assumptions
* You are familiar with LSF
* LSF Suite is installed on premises
* The running LSF cluster has applications, licenses, users, and project data available to it for executing tasks

## Deployment Options
The code in this repository can deploy two types of LSF Cluster:
1. LSF Stretch Cluster
2. LSF Multi Cluster

The type of cluster to deploy will depend greatly on the workload to run on the cloud and the number of machines.  Some experimentation will be needed to determine which is best for you.
Some factors to consider are:
1. Network latency between your on premise environment and the primary cloud environment being considered
2. The location of required services (Project data, user authentication, application binaries, etc)
3. Expected data traffic exiting the cloud over the internet

 
### LSF Stretch Clusters
This architecture assumes that you have a cluster in another location – either on premise or even running in another cloud or cloud location.   The “stretched cluster” architecture is defined as a single cluster stretched over a WAN so that compute nodes in the cloud communicate with a master scheduling host on the originating location.

Generally, though much simpler in concept than “Multi-Cluster”,  this means that all LSF daemon communication with the master scheduler happens over the WAN which can be a source of extra cost or lowered reliability.

### LSF Multi Cluster
This is a more complex architecture which adds a master scheduler running in the cloud.   By adding a master scheduler in the cloud, the architecture eliminates all the communication from cloud compute node to the on premise master.

The two master schedulers instead exchange task meta-data in a “job forwarding” model.    In this model, users on premise submit workload to a queue on premise, which in turn forwards that workload to the cloud for execution.   Upon task completion, the master in the cloud communicates completion, and status with the on premise master and the user is notified.

## Instructional Videos
These videos look at how to extent your on premises LSF clusters to the Cloud. In them we look at various topics you need to consider in constructing you Hybrid cloud solution. We show two different LSF configurations suitable for small and large clusters and discuss the benefits of each. We provide sample Ansible playbooks which you can take and customise for your site. Each video covers a different topic, and a different Ansible playbook. They are best viewed in order.

### [LSF Cloud Video 1 - Introduction](http://ibm.biz/LSFcloud_video1)
This is the first of the video series on creating a hybrid LSF cluster.  This video covers, what is LSF, why do users want to go to the cloud, and how we can help in that journey.  We outline two different ways LSF can be configured.  The first extends the on premises cluster by adding cloud servers to the cluster.  The second constructs a second cluster on the cloud, and dynamically sizes that cluster based on the amount of workload.  The subsequent videos provide additional details and live demonstrations on how to build them.

### [LSF Cloud Video 2 - What Type of Cluster](http://ibm.biz/LSFcloud_video2)
This video provides details on different way LSF can be configured to use Cloud machines.  We start from the simplest case, the LSF Stretch Cluster, which adds Cloud machines into an existing on premises cluster.  We then show a LSF Multi Cluster, which creates a separate LSF cluster on the cloud that accepts workload from the on premises cluster and dynamically resizes based on policies.  The uses cases of each one is outlined along with the benefits and issues.

### [LSF Cloud Video 3 - Installing Prerequisites](http://ibm.biz/LSFcloud_video3)
In this video we start the process of building a LSF hybrid cluster.  We start from an existing on premises LSF Suite cluster, and use that, along with some sample Ansible playbooks to deploy the LSF Stretch and LSF Multi clusters on to Amazon Elastic Compute Cloud (Amazon EC2) instances.  This video discusses the prerequisites for the sample playbooks.  It shows how to setup your AWS account and get the needed AWS keys and certificate that will be used later.  It shows the git repository that hosts the code.  It shows how to add the AWS keys to the playbooks and run the first playbook to setup you LSF Master to build the rest of the solution.

### [LSF Cloud Video 4 - Amazon VPC Configuration](http://ibm.biz/LSFcloud_video4)
This video focuses specifically on Amazon Web Services and there Cloud environment.  In it we show a playbook that will construct a Amazon VPC, along with associated subnets, routes, security groups, network ACLs, and internet gateways.  We also show how to use an existing Amazon VPC with the playbooks.  The LSF cluster will use this Amazon VPC to access the cloud instances.

### [LSF Cloud Video 5 - Network Connection](http://ibm.biz/LSFcloud_video5)
The connection between the on premises cluster and the cloud instances is a critical part of the infrastructure.  This video looks at different options available with AWS.  It shows a sample playbook that will construct a VPN using OpenVPN.  We also test the connection to verify it can work with LSF.

### [LSF Cloud Video 6 - Users and Groups](http://ibm.biz/LSFcloud_video6)
In this video we discuss ways in which to resolve the issue of providing a consistent user experience with a hybrid cloud.  We look at possible solutions for synchronising user, group and host configurations between the on premises and cloud machines.  We show a playbook that synchronises the users, groups and hosts between the on premises LSF master and the cloud instances.

### [LSF Cloud Video 7 - Bringup LSF Cloud Instances](http://ibm.biz/LSFcloud_video7)
This video uses a playbook to bring up additional cloud instances.  The machines are configured so that they can be reached from the on premises LSF master and the users, groups, and host resolution is configured.

### [LSF Cloud Video 8 - Storage](http://ibm.biz/LSFcloud_video8)
In this video we cover one of the more difficult issues to address in constructing an LSF hybrid cluster.  The architecture of the storage will have a large impact on how the on cloud cluster performs.  This video will cover some options, but it is strongly recommended that users perform there own experiments to see what storage configuration option works best for there workloads.  We demonstrate a simple storage configuration.

### [LSF Cloud Video 9 - LSF Stretch Cluster deployment](http://ibm.biz/LSFcloud_video9) 
This video demonstrates the deployment of the LSF Stretch cluster.  We take the machine(s) deployed in the previous videos and extent the existing on premises cluster to include additional cloud machines.  We show how the LSF Master is reconfigured, and demonstrate jobs running on the cloud instances.

### [LSF Cloud Video 10 - LSF Multi Cluster deployment](http://ibm.biz/LSFcloud_video10) 
Here we demonstrate the deployment of the LSF Multi cluster.  We take the machine(s) deployed in the previous videos and extent the existing on premises cluster to include additional cloud machines.  We show how the LSF Master on premises and on cloud is reconfigured.  We submit work to the cluster and see it dynamically create new machines on the cloud, and see it terminate those machines when the load drops.

### [LSF Cloud Video 11 - Decommissioning the Cluster](http://ibm.biz/LSFcloud_video11) 
This video demonstrates how to take down the on cloud cluster.  It also shows what must be done to remove any hosts that were dynamically created by the resource connector in the LSF Multi cluster.  It is **VERY** important to clean up fully, so a thorough review of this video is recommended. 

## Extending the Code
The Ansible playbooks used in these videos is hosted on Github <a href="https://github.com/IBMSpectrumComputing/lsf-hybrid-cloud" rel="noopener" target="_blank">here.</a>  They are public and freely available for you to take and customize.  If you add a new feature you'd like to share with everyone, please post it.

## Known Issues
You may encounter an installation issue with Step6-install-LSF for the Multi-Cluster installation where it complains with:
```
2019-01-06 20:53:05,573 p=3555 u=root |  failed: [10.1.1.187] (item=[u'ansible',
 u'python2-boto', u'python2-boto3']) => {"changed": true, "failed": true, "item"
: ["ansible", "python2-boto", "python2-boto3"], "msg": "Error: Package: python2-
boto3-1.4.6-1.el7.noarch (epel)\n           Requires: python2-s3transfer >= 0.1.
10\n           Available: python2-s3transfer-0.1.10-1.el7.noarch (epel)\n
        python2-s3transfer = 0.1.10-1.el7\n", "rc": 1, ...
```
The problem comes from a renamed python2-s3transfer package.  It's now called python-s3transfer, however the python2-boto3 uses the old name in its dependency list.

If you encounter this problem use the following proceedure to work around the issue until the dependency list is fixed.

### Login to LSF Master on Cloud
Get the IP address of the LSF master on cloud from the inventory_ec2servers.yml file.  It will typically be in: /opt/ibm/lsf-hybrid-cloud
In the list of ec2servers take the IP address of the first occurance of "prv_ip".  This is the private IP of the LSF master node, and should be reachable provided the VPN is running.  SSH to this machine e.g. 
```
# ssh {IP address from above}
```

### Manually Install the Needed Packages
Use the proceedure below to install the needed packages:
```
# yum -y install python2-s3transfer
# yum -y install ansible python2-boto

# mkdir rpms
# cd rpms
# yumdownloader --resolve python2-boto3

# rpm -i python2-jmespath-0.9.0-3.el7.noarch.rpm
# rpm -i python2-futures-3.1.1-5.el7.noarch.rpm
# rpm -i python2-botocore-1.6.0-1.el7.noarch.rpm
# rpm -i --nodeps python2-boto3-1.4.6-1.el7.noarch.rpm
```
Change the rpm names to match the current versions you downloaded.

### Restart the Installation Step
Re-run the Step6-install-LSF playbook.
