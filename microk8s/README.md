1. Set inventory to set IP, MUST be password-less SSH and sudo
2. `time ansible-playbook -i inventory.ini ansible.yml --private-key ~/id_rsa_priv.key -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"`

# Disclaimer
Tested on debian 13 AWS with t3.small
