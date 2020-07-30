# created by terraform from template
# ssh_config file to access private IP hosts via
# public gateway ProxyJump
# use: ssh -F ssh_config <private_ip>

# master hosts
%{ for master_private_ip in master_private_ips ~}
Host ${master_private_ip}
   ProxyJump  ${login_public_ip}

%{ endfor ~}

# worker hosts
%{ for worker_private_ip in worker_private_ips ~}
Host ${worker_private_ip}
   ProxyJump  ${login_public_ip}

%{ endfor ~}


Host *
   IdentityFile ~/.ssh/${local_ssh_keyfile}
   User root
   UserKnownHostsFile=/dev/null
   StrictHostKeyChecking no
   ConnectTimeout 50
