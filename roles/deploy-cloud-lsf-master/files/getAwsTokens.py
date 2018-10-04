#!/usr/bin/python

import os
import json
import urllib

URL='http://169.254.169.254/latest/meta-data/iam/security-credentials/{{ AWS_IAM_Role_Name }}'
GOTFILE='role.perm'
urllib.urlretrieve(URL, GOTFILE)

fp=open(GOTFILE, 'r')
rd=fp.read(-1)
fp.close()
jd=json.loads(rd)
print("[default]")
print("aws_access_key_id=" + jd['AccessKeyId'])
print("aws_secret_access_key=" + jd['SecretAccessKey'])
print("aws_session_token=" + jd['Token'])

