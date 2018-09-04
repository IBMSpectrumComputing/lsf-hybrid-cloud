# lsf-hybrid-cloud

## Overview
This repository contains sample code for building two varieties for LSF Hybrid Clouds.  LSF Stretch Clusters for extending an on premises LSF cluster using on cloud resources, and LSF Multi Clusters, for creating a second dynamic LSF cluster on cloud that on premises workload can automatically be forwarded to.

IBM® Spectrum LSF (formerly IBM® Platform™ LSF®) is a complete workload management solution for demanding HPC environments. Featuring intelligent, policy-driven scheduling and easy to use interfaces for job and workflow management, it helps organizations to improve competitiveness by accelerating research and design while controlling costs through superior resource utilization.

Please note, Spectrum LSF is not itself an application in the traditional sense, but instead provides an environment and framework for other applications to be managed and run in a load balanced efficient manner.   It is expected that you will install some kind of application(s) into this environment, or use application installed in your on premise environment to make proper evaluation use of the features and benefits of Spectrum LSF.

Additional videos that explain how to use this code is posted here:
    { TO be added }

The sample Ansible playbooks will create the LSF Hybrid cluster on AWS.  These playbooks should be taken and customized to meet your specific site requirements.


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


