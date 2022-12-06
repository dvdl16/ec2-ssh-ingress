# EC2 SSH Ingress Control Script

This script uses AWS CLI to add or remove a public IP from a Security Group's inbound rules.

## Requirements

- This script requires `jq` to be installed. On Ubuntu, you can install this with `sudo apt install jq`.
- This script also requires a valid AWS CLI Credentials file: `~/.aws/credentials`

## Usage

To run the script, mark it as executable and run it:

```bash
chmod +x ./ec2-ssh-ingress.sh
./ec2-ssh-ingress.sh
```