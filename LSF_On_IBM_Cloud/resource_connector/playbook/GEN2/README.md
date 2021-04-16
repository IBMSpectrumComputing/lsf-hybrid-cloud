The GEN2-config.yml file contains the configuration parameters needed to 
create the new virtual servers in the LSF Cluster on the IBM Cloud. Use 
the instructions below to set the values appropriate for your LSF cluster.

The following information can be obtained using IBM Cloud CLI
or you can use playbook/scripts/get-vm-info.sh to retrieve the
information. The script takes the name of your virtual server (VSI). Use
"ibmcloud is instances" to get the VSI name.
```
GEN2_Region: eu-de
GEN2_Zone: eu-de-1
GEN2_VPC_ID: r010-15459595-0b09-487f-8a67-7fa87c6fea9d
GEN2_Image_ID: 99edcc54-c513-4d46-9f5b-36243a1e50e2
GEN2_SUBNET_ID: 02b7-8eced36a-3261-4d6a-9741-47b91331ffbe
GEN2_SG_ID: r010-8ad4533a-687c-462f-8075-ba1946bc9b5d
GEN2_PROFILE: bx2-4x16
CORES_PER_SOCKET: 2
SOCKET_PER_NODE: 1
MEMORY_PER_NODE: 16384
```

For these three variables:
```
CORES_PER_SOCKET: 2
SOCKET_PER_NODE: 1
MEMORY_PER_NODE: 16384
```
The get-vm-info.sh script assumes that your virtual server only has one socket/chip/numa node
per instance and the cores are with hyper threading on. The memory reported here is in terms of
MB.

The DNS information can be obtained using IBM Cloud CLI
or you can use playbook/scripts/get-dns-info.sh to retrieve the
information. The script takes the name of your DNS instance. Use
"ibmcloud dns instances " to get your DNS instance name.
There may be multiple zones for a given service instance.
The script assumes that only one zone exist for this DNS instance.
```
GEN2_DNS_Instance_ID: e92648fd-3b9f-4d7c-971e-bc8140ba353d
GEN2_DNS_Zone_ID: hf-lsf.com:6bcefc25-bf68-4ad1-8085-674e4e9f0987
GEN2_DNS_Domain_Name: hf-lsf.com
```

The lsf_key_name variable holds the key name on the Cloud that contains the RSA public key
in the LSF master.
```
lsf_key_name: hf-rc-lsf-key
```

The rc_maxNumber determines the maximum number of virtual servers that can be provisioned. 
This value limits the number of dynamic hosts that can be requested by LSF.
```
rc_maxNumber: 100
```

rc_vm_refix sets the prefix for new virtual server name.
```
rc_vm_prefix: hf-rc
```
