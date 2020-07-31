# terraform-generated Inventory for installation and configuration of LSF

# local should be your on-prem LSF master
[local]
localhost ansible_connection=local

[login]
${login_ip}

[worker]
%{ for worker_ip in worker_ips ~}
${worker_ip}
%{ endfor ~}

[master]
%{ for master_ip in master_ips ~}
${master_ip}
%{ endfor ~}

[deployer]
${deployer_ip}

[compute:children]
worker
master

[lsf_install:children]
worker
master
deployer
local


# inventory section for LSF-RC setup
[LSF_Masters]
%{ for master_ip in master_ips ~}
${master_ip}
%{ endfor ~}


[LSF_Servers]
%{ for worker_ip in worker_ips ~}
${worker_ip}
%{ endfor ~}


[lsf_rc:children]
LSF_Masters
LSF_Servers


[all:vars]
ansible_ssh_user=root
ansible_ssh_common_args='-F ${ssh_config}'


[lsf_install:vars]
nfs_volume_size=${nfs_volume_size}
nfs_server_ip=${nfs_server_ip}
nfs_mnt_dir=${nfs_mnt_dir}
lsf_cluster_name=${lsf_cluster_name}


[lsf_rc:vars]
LSF_NFS_MOUNT_DIR=${nfs_mnt_dir}
LSF_CLUSTER_NAME=${lsf_cluster_name}
