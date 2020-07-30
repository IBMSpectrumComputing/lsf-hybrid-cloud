This setup will allocate VPC resources using Ansible and Terraform.

## Create a VPC in IBM Cloud and Install LSF:


### 1. Configuration of the setup
   * Specify where to allocate how many resources under which names etc.

1.1. Set `IBMCLOUD_API_KEY` environment variable
     Acquire your key info and set the cloud api key. Several ansible scripts will check for this setting and fail if not set.
   
1.2. Create a copy of tf_inventory.in for modifications (e.g.:`tf_inventory.yml`). This is a yaml-format inventory file because this format makes it a little easier to handle many variables than the ini-format
   Important settings:
   * vpc_region
   * vpc_zone
   * resource_prefix
   * domain_name
   * {master,worker}_nodes
   * key_name
   * ssh_key_file
   * {worker,master,login}_profile
   * image_name
   * tfbinary_path
   * lsf_cluster_name
   * vpn_peer and security settings (to generate vpn.yml file and create security policies. The policies will be created according to the parameters. However, step 3 allows to create new policies and change peer configuration if necessary. Therefore, it's fine if not all data for `vpn_peer` is known yet. See also the comments in `tf_inventory.in` for details.)

1.3. Set `GEN_FILES_DIR` environment variable to a directory (use absolute path) where terraform and ansible should place generated files for subsequent steps. *IMPORTANT NOTE:* If you plan to create multiple VPCs, the `GEN_FILES_DIR` needs to be unique for each VPC otherwise newly generated files overwrite data from existing VPCs.

1.4. Update/check `group_vars/lsf_install` to set source and target location of LSF installer binary.
If multi-cluster setup is not required, you can ignore the multicluster member of the lsf variable. See below for multi-cluster setup for an explanation of these settings.


1.5. Install terraform and terraform provider (if not done already)
     * make sure you have set `tfbinary_path` and `tfplugin_path` in `tf_inventory.yml`
     * make sure your version of the provider is >= 1.8.1 (bugfix for cleanup)
```
  ansible-playbook -i tf_inventory.yml create_vpc.yml --tags "install-terraform" [-K]
```
  Note that -K option to provide the sudo passwd is required in case your `tfbinary_path` or `tfplugin_path` are only writable by root.


1.6. (Optional): Install IBM Cloud CLI tools.
   * Some of the provided scripts use the CLI tools to simplify steps and extract data. If you want to use these scripts, you might want to install this.
For this step, the settings `tfbinary_path` and `tfplugin_path` in `tf_inventory.yml` are important.
In case you want the terraform user to be different from your current user, you can add `tf_owner` and `tf_plugin_owner` settings. Since changing user requires elevated privileges, you might have to add `-K` for ansible to ask for your sudo passwd.
```
  ansible-playbook -i tf_inventory.yml create_vpc.yml --tags "install-ibmcloud-cli" -K
```

   * Step 1.5 and 1.6 can be done in one step by running:
```
  ansible-playbook -i tf_inventory.yml create_vpc.yml --tags "prereq" -K
```


### 2. Run playbook to terraform your VPC with the settings in `tf_inventory.yml`.
   * before you make the first attempt to create this VPC, make sure there's no `terraform.tfstate` file in the `GEN_FILES_DIR` from a previous test. Otherwise, the playbook assumes this is a re-try and uses an old or incorrect state file for terraform.
```
ansible-playbook -i tf_inventory.yml create_vpc.yml
```
   * this creates a directory `${GEN_FILES_DIR}` to keep the following files
     * `cluster.inventory`  to use with subsequent steps (including autoscaling)
     * `ssh_config` an ssh config file to allow direct login to private IPs from the inventory (`ssh -F <ssh_config> <host>`)
     * `terraform.tfstate` terraform status (required for tear-down of resources)
     * `terraform.tfvars` terraform variables (required for tear-down of resources)
     * `GEN2-cfg.yml` needed as input for auto-scaling
     * `vpn.yml` coordinates of the VPN gateway in this setup
     * `clusterhosts` an /etc/hosts-style file with the cluster master and worker nodes
     * `tf_inventory.yml` a copy of your tf_inventory for later use (in case you're juggling multiple VPCs)

   * In case of failures or partial creation of resources, the tfstate file is saved and can be used to re-run the playbook for a retry and/or for manual runs with terraform.

2.n. To delete all the resources, run playbook to destroy with `tf_inventory.yml`
```
ansible-playbook -i ${GEN_FILES_DIR}/tf_inventory.yml clean_vpc.yml
```
  * the cleanup removes some of the generated files like the inventory and the GEN2-cfg. However, the terraform state and variables will be preserved in case anything goes wrong. This is done by appending a timestamp to the generated directory in `GEN_FILES_DIR`. The playbook can be rerun after a partial cleanup and ansible will use the corresponding tfstate file. However, up to now we've seen no cases where that succeeded. Therefore, ansible will use the Cloud CLI and retrieve a list of all resources filtered by the `resource_prefix` setting and will list everything that remains.


### 3. Configure/Bringup VPN Connection
   This describes the VPN option that uses VPNaaS using a site-to-site VPN between the Cloud VPN gateway created in step 2 and your on-prem VPN gateway (requires separate setup).  This step creates a VPN Connection from Cloud to on-prem.

  * Step 2 created a `vpn.yml` with initial information about the Cloud VPN gateway and network. Now, you'll need to edit this file and add the remaining missing information to allow connection to your on-prem gateway. There are some comments for guidance in the file. Note that the 'peer' for this connection is your on-prem VPN. Most notible things to look for:
    * `peer_address`: the IP of your on-prem VPN gateway
    * `peer_cidrs`: a list of CIDR blocks of your on-prem network that you want to connect to this VPN
    * `preshared_key`: a passphrase or key that needs to match the setup of your on-prem VPN gateway
    * The security policy settings need to match your on-prem (peer) VPN settings to successfully connect

  * Make sure one of the below alternatives for the security policies matches your on-prem VPN configuration:
    a) use the pre-filled ids `ike_pol_id` and `ipsec_pol_id` for policies created by terraform based on the `tf_inventory.yml`  or:
    b) if you need a new set of policies then remove the policy references (comment out) and set up the `security` section according to your on-prem setup to let ansible create new policies for you

  * When the configuration is done, run the playbook:
```
ansible-playbook -i ${GEN_FILES_DIR}/cluster.inventory static_cluster.yml --tags "vpn"
```
  This adds another block of information to the `vpn.yml` file. For example it contains the VPN-connection ID that will be required to destroy the resource later.

  * To cleanup the VPN connection (and any newly added policies) run:
```
ansible-playbook -i ${GEN_FILES_DIR}/cluster.inventory static_cluster.yml --tags "clean_vpn"
```


3a) Alternative VPN using OpenVPN

 As an alternative to the VPNaaS solution (which might involve manual setup of on-premise VPN systems), we provide an OpenVPN-based automation for quick tests.  Note that this puts the VPN server into the cloud (master node) and has security implications and we don't recommend this as a permanent solution for anything sensitive.
The on-premise master will become the VPN client. The cloud master will become the VPN server.

  * Edit the OpenVPN section in the generated `vpn.yml` and fill in any missing or undesired settings
    * `peer_address`: needs to be the IP of the on-prem master (passwordless ssh login from ansible play host needs to be available when running from a 3rd location)
    * `peer_nic`: the network interface to use for the VPN at the on-premise side.
    * `ovpn_cidr`: the subnet cidr to be used between OpenVPN server and client

  * Run the static_cluster playbook with the tag to create the VPN::

```
ansible-playbook -i ${GEN_FILES_DIR}/cluster.inventory static_cluster.yml --tags "open_vpn"
```
  It will prepare a setup.sh script in `${GEN_FILES_DIR}/scripts` which uses ssh (and the generated ssh_config) to log into the cloud nodes for setup.  The setup includes generation of certificates (using easy-rsa) and configure client, server and iptables-based forwarding rules (VPN port) on the login node.
  In our experiments, for the LSF data manager to work, the IP addresses of the corresponding master nodes needed to be the OpenVPN IPs (address of the tunX device).


### 4. Run the static_cluster playbook with the generated inventory to install LSF (this does not require a functional VPN at this point):
Before running, double-check any settings in group_vars/lsf_install to allow successful installation of LSF.
```
ansible-playbook -i ${GEN_FILES_DIR}/cluster.inventory static_cluster.yml --tags "setup" [-K]
```
In case you're not running this as root, you'll need the `-K` option because it needs sudo for the collection of user and group information on the on-premise machine (running host).
Instead of splitting the playbook into many files, we've enabled separate steps through tags. The `setup` tag is to run the entire setup of the LSF cluster. Individual sub-tasks can be separated out by listing the required tags. The ordering of tasks in the file reflects one functional sequence of steps.

This step will install a functional LSF cluster on the VPC. It will grab the list of local users and groups and enable their login. For the data manager to work, users need a home directory in a file system that's shared between the nodes of the VPC. The setup will create a home directory only for the users listed in variable `lsf_user_list` in `group_vars/lsf_install`.  The users or administrators will need to manually create or enable ssh keys for each user to allow passwordless login between on-premise and cloud LSF clusters (both ways). This step is not automated because it would require intrusive access the user directories and is therefore deemed inappropriate for this proof of concept example. The passwordless access is especially important for use of the LSF data manager.


### 5. Multi-cluster configuration (incomplete yet)
The `multicluster` section of `group_vars/lsf_install` is important to be set up for this step.
 * There's one section for the on-prem and one for the cloud-side LSF master
 * The `conf_dir` is the LSF configuration directory
 * `cluster_name` of the cloud LSF is already configured via inventory, the `cluster_name` of the on-prem LSF should be configured here.
 * If the playbooks are run from the on-prem LSF master, the hostnames are autodetected
 * If you use a non-standard port, then it should be set here too
 * `sndqueue` will be the name of the on-prem queue that forwards jobs to the cloud master
 * `vpn` contains the vpn settings (tbd)
 * `rc` configures resource connector items like the name of the dynamic hosts group

To run on-prem and cloud steps for datamanager and multi-cluster in one step:
NOTE: Not yet advisable because of missing bits and pieces!
```
ansible-playbook -i ${GEN_FILES_DIR}/cluster.inventory static_cluster.yml --tags "config_mc"
```
The step-by-step alternative is shown below:

5.1. Data Manager
 After the configuration, run the playbook with `config_dm` tag to set up the datamanager
```
ansible-playbook -i ${GEN_FILES_DIR}/cluster.inventory static_cluster.yml --tags "config_dm"
```

5.2. Set up Multi-cluster and queues

 * Configure the cloud-side queues and settings of LSF:
```
ansible-playbook -i ${GEN_FILES_DIR}/cluster.inventory static_cluster.yml --tags "mc_cloud"
```

 * Configure the on-prem-side queues and settings of LSF:
```
ansible-playbook -i ${GEN_FILES_DIR}/cluster.inventory static_cluster.yml --tags "mc_onprem"
```


## TROUBLESHOOTING

 * If one or more workers had to be rebooted for whatever reason, rerun necessary roles by running the playbook with `--tags "restart_worker" --limit "<worker-ip1>[,<worker-ip2>]"`. Note that the `--limit` parameter is only needed if a subset of workers was restarted.

 * If the master had to be rebooted for whatever reason, rerun roles necessary roles by running the playbook with `--tags "restart_master"`. Note that if you have multiple masters on the cloud side, you might want to use `--limit "<master-ip>"` to only perform the tasks on the restarted nodes.

 * We noticed some issues with terraform cleanup running into timeouts. In this case the playbook will collect a list of resources that failed to get destroyed. The list of IDs can be used for manual destruction via CLI or GUI. Please make sure your terraform provider version is 1.8.1 or later to include a bug fix that addressed this issue.

 * For the LSF data manager to work correctly please check that both master nodes have locally functional data managers and then use `bdata connections` to check for outgoing and incoming connection status to be ok. If not, make sure that firewalls and security rules allow access to the configured data manager port both directions between the 2 LSF master nodes.

 * Users cannot ship data using LFS data manager: this is most often a problem with passwordless access. Make sure you can log in from any master to itself and to the peer master without password or other interactive steps.
