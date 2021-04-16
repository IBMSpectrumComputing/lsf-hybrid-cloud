## Prerequisites
The following steps assume that you already have a LSF cluster and meet the requirements
listed below. We also assume that you have an existing IBM Cloud account.

* You must have an existing LSF cluster set up and have root access to the LSF master host.
* There is a RSA ssh key pair (id_rsa/id_rsa.pub) in the /root/.ssh directory on the LSF master host and
  the ssh passwordless setup allows the LSF master to connect to all the LSF servers without password.
* You must be able to restart the LSF cluster master daemon.
* You must be familiar with operating the IBM Cloud web console and the IBM Cloud CLI.

## IBM Cloud CLI and API Key
It is recommened to have the IBM Cloud CLI(https://cloud.ibm.com/docs/cli) installed on your local machine. The Cloud API key (https://cloud.ibm.com/docs/iam?topic=iam-userapikey) is also required. The CLI command to create an API key is through the "ibmcloud iam api-key-create" command. Export your API key to the IBMCLOUD_API_KEY environment variable on your local machine.
```
export IBMCLOUD_API_KEY=<YOUR_API_KEY_HERE>
```
## The Inventory File
You need to have an inventory file with the following structure:
```
[local]
localhost ansible_connection=local

[LSF_Masters]
lsf-master-0

[LSF_Servers]
lsf-worker-0

[all:vars]
ansible_ssh_user=root
ansible_ssh_private_key_file=/home/vncviewer/.ssh/id_rsa
```

The host in the local group is where the playbooks are going to be run.
The ansible_ssh_user and ansible_ssh_private_key_file are optional and only required when
you need to ssh to the nodes in the LSF cluster from you local machine. You can also specify
the private key using the ansible command line options. 
```
ansible-playbook -i inventory_file [--private-key PRIVATE_KEY_FILE --user root] 
```
The host in the local group can be one of the LSF masters.

***NOTE: If you have created the LSF cluster using the setup in the git repository, you can use the inventory file created under the directory specified in the GEN_FILES_DIR environment variable.***

## The Group Variables File
Open the group_vars/all under playbook/ and make sure the variables are set up correctly.
Please pay attention to LSF_SUITE_TOP, LSF_VER_DIR, LSF_CLUSTER_NAME, LSF_GUI_BIN and LSF_NFS_MNT_DIR, which should be
consistent with the LSF cluster on the Cloud. The LSF_CLUSTER_NAME name needs to match with the LSF cluster name
on the Cloud, which you could get using the lsid command from any of the LSF nodes.
```
root@hf-lsf-master-0:~>lsid
IBM Spectrum LSF 10.1.0.9, Oct 16 2019
...

My cluster name is hf-lsf-clust
My master name is hf-lsf-master-0
```

## GEN2/GEN2-config.yml
Open the GEN2/GEN2-config.yml file under playbook/ and fill out the values for the GEN2_xx variables as well
CORES_PER_SOCKET, SOCKET_PER_NODE, and MEMORY_PER_NODE. These information can be retrieved from
either the IBM Cloud web console or IBM Cloud Cli. There are also scripts available to you to help gather this information. The scripts/get-vm-info.sh script takes the instance name of a virtual server and would gather the values for GEN2_xx variables.
```
lsf-rc-gen2/playbook$ ./scripts/get-vm-info.sh hf-lsf1-master-0
GEN2_Region: eu-gb
GEN2_Zone: eu-gb-1
GEN2_VPC_ID: r018-f4387210-9fc5-452b-a87f-6db24f3786c8
GEN2_Image_ID: 99edcc54-c513-4d46-9f5b-36243a1e50e2
GEN2_SUBNET_ID: 0787-4c778898-0075-483d-8189-bd897d0e7fea
GEN2_SG_ID: r018-12aac500-1317-4951-b1d7-2dcca494a7cf
GEN2_PROFILE: bx2-4x16
CORES_PER_SOCKET: 2
SOCKET_PER_NODE: 1
MEMORY_PER_NODE: 16384
```
The GEN2_DNS_xx variables can be retrieved using the scripts/get-dns-info.sh script given the DNS instance name.
```
lsf-rc-gen2/playbook$ ./scripts/get-dns-info.sh hf-lsf1-dns
GEN2_DNS_Instance_ID: cfc5a61b-0bd5-450f-ab30-eea08e4e2cd2
GEN2_DNS_Zone_ID: hf-lsf1.com:5cc23076-06b1-4a5e-9291-fa6012ce73d7
GEN2_DNS_Domain_Name: hf-lsf1.com
```
You should also change the rc_vm_prefix variable so that you can easily track the new nodes added to your LSF cluster.

The key specified in lsf_key_name on the Cloud should match the RSA public key in the LSF masters. 

The create-key.yml playbook will retrieve the RSA public key from the LSF master
and use IBM Cloud CLI to create a key with the name specified in the lsf_key_name variable.

For more details about the variables in GEN2-config.yml, please check the README file in GEN2/.

**NOTE: If you have created the LSF cluster using the setup in the git repository, you can find all the GEN2_xx variables (+ core/socket/memory) in a GEN2-cfg.yml file created under the path in GEN_FILES_DIR environment variable. You can just copy and paste the values to GEN2/GEN2-config.yml.***

## RC deployment and LSF RC configuration on the LSF Cluster
After the variable files, group_vars/all and GEN2/GEN2-config.yml are filled out and the inventory file
is ready, we can run the step-all-setup-rc.yml playbook to complete the installation and
the configuration for Resource Connector in the LSF cluster. 
```
ansible-playbook -i inventory_file step-all-setup-rc.yml [--private-key PRIVATE_KEY_FILE --user root]
```

You can also run the steps separately by following the step ordering.
```
Step 1: ansible-playbook -i inventory_file [--private-key PRIVATE_KEY_FILE] step1-install-tools.yml

Step 2: ansible-playbook -i inventory_file [--private-key PRIVATE_KEY_FILE] step2-prepare-files.yml

Step 3: ansible-playbook -i inventory_file [--private-key PRIVATE_KEY_FILE] step3-deploy-rc.yml

Step 4: ansible-playbook -i inventory_file [--private-key PRIVATE_KEY_FILE] step4-config-lsf-rc.yml
```
Please note that your IBM Cloud API key will be included in the credential file generated in the step 3. The lsfadmin user id will be added to the sudo group in the step 4.

```

## Submit jobs to request NextGen virtual servers
In this section, "hf-rc-9634-vm-0.hf-lsf.com" is a sample virtual server in NextGen.

1. Use bsub to submit jobs that require hosts provisioned by NextGen.

The following bsub command with no options submits a job that will trigger a borrow demand when there are no available resources in LSF cluster:
```
$ bsub myjob
``` 
2. Use bhosts to monitor borrowed hosts. Host status becomes "ok" when it joins the LSF cluster as a dynamic host.

```
$ bhosts -a

HOST_NAME                    STATUS       JL/U    MAX  NJOBS    RUN  SSUSP  USUSP    RSV
lsfmaster                    ok              -      1      0      0      0      0      0
hf-rc-9634-vm-0.hf-lsf.com   ok              -      1      1      1      0      0      0
```
Verify that this job runs on hf-rc-9634-vm-0.hf-lsf.com using the bjobs command.

3. LSF can dispatch subsequent jobs to an existing NextGen virtual server if there is demand and job resource requirements match the host template. If there is no additional demand for the host, LSF will relinquish the host and a cancel request will be sent to the cloud. After some time the virtual server will no longer be available.

