# README

This repository deploys EJBCA Community with Ansible.

This file is a practical English-language version of the main README, focused on the simplest use case in this workspace:

- EJBCA Community deployment
- target host configurable via `pki_server_name` in `host_vars`
- SSH connection with the user defined in `.env` via `PKI_ANSIBLE_USER`
- target machine: Debian 13

The workspace also contains several `host_vars` files for Community nodes and remote database nodes used in examples and validation.

## Overview

The main Community playbook is `deployCeNode.yml`.

For the remote database scenario, the playbook to use in this copy is `deployCeNodeExternalDB.yml`.

It installs and configures:

- MariaDB or PostgreSQL
- WildFly
- SoftHSM
- EJBCA Community
- Apache HTTPD
- a Management CA
- a Root CA
- a Sub CA
- the SuperAdmin account

## Post-installation behaviour

In this copy of the project, the Community installation also performs the following actions automatically:

- adds the necessary rules to the `Public Access Role` so that the Management CA, Root CA and Sub CA appear on the RA page `CA Certificates and CRLs`
- makes the CAs directly visible at `https://<fqdn>/ejbca/ra/cas.xhtml`
- exports the CA certificates to the Ansible controller in the `ejbcaCaCerts/` directory
- also exports the Super Administrator PKCS#12 file to that same directory

After a successful deployment you should therefore find:

- `ejbcaCaCerts/ManagementCA.crt`
- `ejbcaCaCerts/<Organisation>-Root-CA.crt`
- `ejbcaCaCerts/<Organisation>-Sub-CA.crt`
- `ejbcaCaCerts/<Organisation>-SuperAdministrator.p12`

With anonymised values as in `.env.example`, this corresponds for example to:

- `ejbcaCaCerts/ManagementCA.crt`
- `ejbcaCaCerts/Organization-RootCA.crt`
- `ejbcaCaCerts/Organization-SubCA.crt`
- `ejbcaCaCerts/Organization-SuperAdministrator.p12`

## WildFly and EJBCA upgrade

This copy of the workspace also contains upgrade playbooks dedicated to the Community scope:

- `upgradeWildfly.yml` : re-runs the WildFly installation/configuration then recompiles and redeploys EJBCA
- `upgradeEjbca.yml` : prepares the new EJBCA source on all `ceServers` nodes, then runs `ant upgrade` on the first node in the group

Minimal commands:

```bash
ansible-playbook -i inventory -l <pki-server> upgradeWildfly.yml
ansible-playbook -i inventory -l <pki-server> upgradeEjbca.yml
```

To validate the playbooks without a new version available, the safest approach is to start with:

```bash
ansible-playbook -i inventory --syntax-check upgradeWildfly.yml
ansible-playbook -i inventory --syntax-check upgradeEjbca.yml
ansible-playbook -i inventory -l <pki-server> --list-hosts upgradeWildfly.yml
ansible-playbook -i inventory -l <pki-server> --list-hosts upgradeEjbca.yml
```

For a test closer to a real upgrade without changing the production version, the recommended approach is to work on a VM restored from a backup or snapshot, then temporarily provide a re-zipped EJBCA package in a new source directory via:

- `ejbca_upgrade_software_url`
- `ejbca_upgrade_src_dir`

This allows you to validate the full Ansible flow without depending on a genuinely newer release.

## Important files

- `inventory` : Ansible inventory and SSH user for each host
- `inventory.example` : annotated inventory template — copy to `inventory` and fill in your hosts
- `host_vars/<pki-server>.yml` : variables for a Community node (one file per node, adapted to the target OS)
- `host_vars/<db-server>.yml` : variables for a remote DB server (one file per server)
- `group_vars/ceServers.yml` : Community deployment variables
- `group_vars/mariadbServers.yml` and `group_vars/postgresqlServers.yml` : remote DB server variables per engine
- `deployCeNode.yml` : main playbook for EJBCA Community
- `deployCeNodeExternalDB.yml` : Community playbook with remote database
- `.env.example` : reference for centralised user, group and password variables on the controller side
- `scripts/with-env.sh` : utility script to load `.env` before running Ansible
- `requirements-galaxy.yml` : list of Ansible Galaxy collections used by this repository
- `scripts/update-galaxy-deps.sh` : script to install or update those dependencies locally in the repository
- `ansible.cfg` : local Ansible configuration

## Pre-deployment checklist

Summary of all points to verify before running a playbook. Tick each row before the first run.

### Ansible control node

| # | Check | Command | Expected result |
|---|---|---|---|
| 1 | `.env` file created from `.env.example` | `cat .env` | Variables filled in (domain, org, users, passwords) |
| 2 | `inventory` file configured | `cat inventory` | Target node alias appears under `ceServers` |
| 3 | `host_vars/<pki-server>.yml` filled in | `cat host_vars/<pki-server>.yml` | Real IP, SSH user, `pki_server_name` |
| 4 | `host_vars/<db-server>.yml` filled in *(remote mode only)* | `cat host_vars/<db-server>.yml` | Real IP, SSH user, `hostname` |
| 5 | Galaxy dependencies installed | `./scripts/update-galaxy-deps.sh` | No errors |
| 6 | SSH key generated on the Ansible node | `ssh-keygen -t ed25519 -f ~/.ssh/ansible_pki` | Files `~/.ssh/ansible_pki` and `~/.ssh/ansible_pki.pub` present |
| 7 | Public key copied to PKI node | `ssh-copy-id -i ~/.ssh/ansible_pki.pub <user>@<pki-server>` | No errors |
| 8 | Public key copied to DB node *(remote mode only)* | `ssh-copy-id -i ~/.ssh/ansible_pki.pub <user>@<db-server>` | No errors |
| 9 | Passwordless SSH connection | `ssh -i ~/.ssh/ansible_pki <user>@<pki-server> exit` | Direct connection, exit 0 |

### Target machine (PKI node)

| # | Check | Command on target | Expected result |
|---|---|---|---|
| 10 | `python3` installed | `python3 --version` | Version printed |
| 11 | `sudo` installed | `sudo -V \| head -n 1` | Version printed |
| 12 | `sshd` active | `systemctl is-active ssh \|\| systemctl is-active sshd` | `active` |
| 13 | sudoers file created in `/etc/sudoers.d/` | `printf '<user> ALL=(ALL) NOPASSWD:ALL\n' \| sudo tee /etc/sudoers.d/<user> && sudo chmod 440 /etc/sudoers.d/<user> && sudo visudo -cf /etc/sudoers.d/<user>` | `...parsed OK` |
| 14 | Passwordless sudo | `sudo -n true` | No error |
| 15 | FQDN resolves | `getent hosts <pki-server>.domain.local` | Correct IP |
| 16 | Internet access or local repo | `curl -sI https://github.com/ \| head -1` | `HTTP/2 200` or `301` |
| 17 | Ports free | `ss -tlnp \| grep -E ':80\|:443\|:8080\|:8443\|:9990\|:9993'` | Empty (no conflicting service) |
| 18 | Sufficient disk space | `df -h /opt /var /tmp` | At least 5 GB available in `/opt` |
| 19 | Clock synchronised | `timedatectl status` | `synchronized: yes` |

### Validation from the Ansible node

| # | Check | Command | Expected result |
|---|---|---|---|
| 20 | Ansible ping to PKI node | `ansible -i inventory <pki-server> -m ping` | `pong` |
| 21 | Ansible ping to DB node *(remote mode only)* | `ansible -i inventory <db-server> -m ping` | `pong` |
| 22 | sudo elevation works | `ansible -i inventory <pki-server> -b -m command -a "id"` | `uid=0(root)` |

## Remote database scenario

This `ansible_ejbca-ce` copy supports two main modes:

- `deployCeNode.yml` : EJBCA Community with a local database on the same node
- `deployCeNodeExternalDB.yml` : EJBCA Community on `<pki-server>` with a remote database on the `<db-server>` host

In remote database mode:

- `<pki-server>` runs WildFly, EJBCA and Apache
- `<db-server>` runs the remote database server
- the WildFly datasource automatically uses the host defined for the DB group corresponding to the chosen engine
- SSH connection parameters are defined in `host_vars/<pki-server>.yml` and `host_vars/<db-server>.yml`

Minimal expected inventory structure:

```yaml
all:
  children:
    ceServers:
      hosts:
        <pki-server>:
    postgresqlServers:
      hosts:
        <db-server>:
```

And in `host_vars`:

```yaml
# host_vars/<pki-server>.yml
ansible_host: <PKI_SERVER_IP>
ansible_user: ansible-user
pki_server_name: <pki-server>
pki_domain_name: "{{ domain_name }}"
```

```yaml
# host_vars/<db-server>.yml
ansible_host: <DB_SERVER_IP>
ansible_user: ansible-user
hostname: <db-server>.domain.local
```

Recommended execution order:

1. Verify SSH and sudo access on `<pki-server>` and `<db-server>`.
2. Verify FQDN resolution for `<pki-server>.domain.local`.
3. Run `deployCeNodeExternalDB.yml`.

## Current workspace state

The workspace has already been adapted to:

- use a configurable SSH user via `.env` on the PKI server
- use `host_vars/<db-server>.yml` files for connection parameters of remote database servers
- support Debian 13 for MariaDB, PostgreSQL, WildFly and SoftHSM
- support AlmaLinux 10 and more broadly Red Hat variants for MariaDB, PostgreSQL, WildFly and SoftHSM
- validate Rocky Linux 10.1 on `<pki-server>` and `<db-server>` for MariaDB and PostgreSQL, both local and remote
- validate Red Hat Enterprise Linux 10.1 on `<pki-server>` and `<db-server>` for MariaDB and PostgreSQL, both local and remote
- validate Ubuntu 24.04 on `<pki-server>` and `<db-server>` for MariaDB and PostgreSQL, both local and remote
- fix three timing issues specific to Ubuntu 24.04: database persistence after `ra addendentity`, availability of the `GlobalConfigurationSessionBean` before `config protocols` commands, and a systemd race condition when stopping WildFly during the very first installation
- target EJBCA CE `9.3.7`

## Validation matrix

The table below summarises the OS, database engine and deployment mode combinations covered in this workspace.

| EJBCA node OS | Remote DB node OS | Database | Local DB mode | Remote DB mode | Status |
| --- | --- | --- | --- | --- | --- |
| Debian 13 | Debian 13 | MariaDB | ✅ validated | ✅ validated | ✅ validated |
| Debian 13 | Debian 13 | PostgreSQL | ✅ validated | ✅ validated | ✅ validated |
| AlmaLinux 10.1 | AlmaLinux 10.1 | MariaDB | ✅ validated | ✅ validated | ✅ validated |
| AlmaLinux 10.1 | AlmaLinux 10.1 | PostgreSQL | ✅ validated | ✅ validated | ✅ validated |
| Rocky Linux 10.1 | Rocky Linux 10.1 | MariaDB | ✅ validated | ✅ validated | ✅ validated |
| Rocky Linux 10.1 | Rocky Linux 10.1 | PostgreSQL | ✅ validated | ✅ validated | ✅ validated |
| Red Hat Enterprise Linux 10.1 | Red Hat Enterprise Linux 10.1 | MariaDB | ✅ validated | ✅ validated | ✅ validated |
| Red Hat Enterprise Linux 10.1 | Red Hat Enterprise Linux 10.1 | PostgreSQL | ✅ validated | ✅ validated | ✅ validated |
| Ubuntu 24.04 | Ubuntu 24.04 | MariaDB | ✅ validated | ✅ validated | ✅ validated |
| Ubuntu 24.04 | Ubuntu 24.04 | PostgreSQL | ✅ validated | ✅ validated | ✅ validated |

Quick reference:

- `local` means the database engine runs on the same node as WildFly and EJBCA
- `remote` means the database engine runs on a dedicated DB server
- `✅ validated` means the scenario has been executed and validated
- `n/a` means the mode is not applicable to the deployed combination

## Product versions

The following are the main versions targeted or observed on the PKI server.

- EJBCA Community : `9.3.7`
- WildFly : `35.0.1.Final`
- WildFly Galleon : `6.0.5`
- OpenJDK runtime detected : `21.0.10`
- Debian Java package used : `default-jdk-headless` version `2:1.21-76`
- Debian OpenJDK package : `openjdk-21-jdk-headless` version `21.0.10+7-1~deb13u1`
- MariaDB server : `11.8.3-0+deb13u1`
- PostgreSQL JDBC driver configured : `42.7.5`
- SoftHSM : `2.6.1-3`
- Apache Ant : `1.10.15`
- MariaDB JDBC driver : `3.5.2`

Useful information:

- the WildFly directory observed on the target is `/opt/wildfly-35.0.1.Final`
- the EJBCA source directory observed on the target is `/opt/ejbca-ce-r9.3.7`
- the JDBC driver deployed in WildFly depends on the chosen engine: `mariadb-java-client.jar` or `postgresql.jar`

## Centralising users, groups and passwords

This repository can centralise the most sensitive or repetitive variables in a `.env` file at the root of the repository.

The loaded variables cover in particular:

- the PKI domain, organisation name and country code
- the Management CA name and the SuperAdmin CN
- the list of IPs authorised for the healthcheck
- the Ansible SSH user
- the common remote group
- the supplementary EJBCA groups
- the `wildfly` application user and group
- the database name, user and passwords
- the EJBCA CLI, HTTPD and SuperAdmin passwords, and crypto token PINs

The `.env` file is not read automatically by Ansible. To load this file properly before a command, use:

```bash
./scripts/with-env.sh ansible-playbook -i inventory -l <pki-server> deployCeNode.yml -e 'database_engine=mariadb database_deployment_mode=local'
```

The repository provides:

- `.env.example` : list of supported variables
- `.env` : local file ignored by git for your current values
- `scripts/with-env.sh` : wrapper that loads `.env` then executes the requested command

Anonymised extract consistent with `.env.example`:

```dotenv
PKI_DOMAIN_NAME=domain.local
PKI_ORGANIZATION_NAME=Organization
PKI_ORGANIZATION_SHORT_NAME=Organization
PKI_COUNTRY_NAME=US
PKI_MANAGEMENT_CA_NAME=ManagementCA
PKI_ROOT_CA_NAME=Organization-RootCA
PKI_SUB_CA_NAME=Organization-SubCA
PKI_ANSIBLE_USER=useransible
PKI_REMOTE_GROUP=groupansible
PKI_DATABASE_USER=ejbca-usr
PKI_DEFAULT_SECRET_VALUE=password
```

The most relevant variables to set in `.env` are:

- `PKI_DOMAIN_NAME`
- `PKI_ORGANIZATION_NAME`
- `PKI_ORGANIZATION_SHORT_NAME`
- `PKI_ORGANIZATION_CRL_NAME`
- `PKI_COUNTRY_NAME`
- `PKI_MANAGEMENT_CA_NAME`
- `PKI_ROOT_CA_NAME`
- `PKI_SUB_CA_NAME`
- `PKI_SUPERADMIN_CN`
- `PKI_HEALTHCHECK_AUTHORIZED_IPS`
- `PKI_DATABASE_NAME`

Useful examples:

```bash
./scripts/with-env.sh ansible -i inventory <pki-server> -m ping
./scripts/with-env.sh ansible-playbook -i inventory -l <pki-server> deployCeNode.yml -e 'database_engine=postgresql database_deployment_mode=local'
./scripts/with-env.sh ansible-playbook -i inventory -l <pki-server>,<db-server> deployCeNodeExternalDB.yml -e 'database_engine=mariadb database_deployment_mode=remote database_server_inventory_name=<db-server>'
```

## Ansible Galaxy dependencies on the control node

This repository uses several external Ansible Galaxy collections, including:

- `ansible.posix`
- `community.general`
- `community.mysql`
- `community.postgresql`

The reference list is maintained in `requirements-galaxy.yml`.

To avoid relying solely on collections installed globally on the control node, this repository is configured to prefer local dependencies in `.ansible/collections` and `.ansible/roles`.

Before a first run, or after updating Ansible or the control node, run:

```bash
./scripts/update-galaxy-deps.sh
```

This script:

- installs or updates the collections defined in `requirements-galaxy.yml`
- places them in `.ansible/collections`
- also installs any Galaxy roles in `.ansible/roles`
- relies on `ansible.cfg`, already configured to prefer these local paths

If you encounter module, collection or version issues on the control node, start by re-running this script then check the configuration loaded by Ansible:

```bash
./scripts/update-galaxy-deps.sh
ansible-config dump --only-changed | egrep 'COLLECTIONS_PATHS|DEFAULT_ROLES_PATH'
```

## Prerequisites for Ansible to work correctly on the target machine

Before running the deployment, verify the following points on the target Debian 13 machine.

### Minimum packages required on the target

Ansible needs at least these components on the target side:

- `openssh-server` installed and running
- `python3` installed
- `sudo` installed
- a standard shell usable by the remote user

Direct verification example on the target:

```bash
dpkg -l openssh-server python3 sudo
systemctl status ssh --no-pager
python3 --version
sudo -V | head -n 1
```

### SSH access

The Ansible controller must be able to connect via SSH with the user defined in the inventory.

In this workspace, that is currently:

- SSH user : `ansible-user`
- target host : value of `pki_server_name` in `host_vars`
- application FQDN : `<pki-server>.<domain_name>`

Recommended checks:

1. The SSH connection works without unexpected interactive prompts.
2. The controller's public key is present in `~ansible-user/.ssh/authorized_keys` if you use keys.
3. If you use an SSH password, run Ansible with `--ask-pass`.

Simple test:

```bash
ssh ansible-user@<pki-server>
```

#### Create an SSH key pair on the Ansible node

If you do not yet have a dedicated key for Ansible, you can create one on the control node:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_pki -C "ansible@<pki-server>"
```

This generates:

- the private key `~/.ssh/ansible_pki`
- the public key `~/.ssh/ansible_pki.pub`

If you want to avoid any passphrase prompt for automated runs, leave the passphrase empty when creating the key.

#### Copy the public key to the target machine

The simplest method is `ssh-copy-id`:

```bash
ssh-copy-id -i ~/.ssh/ansible_pki.pub ansible-user@<pki-server>
```

Then explicitly test the key:

```bash
ssh -i ~/.ssh/ansible_pki ansible-user@<pki-server>
```

If `ssh-copy-id` is not available, you can copy the key manually:

```bash
cat ~/.ssh/ansible_pki.pub
```

Then add its content to:

```bash
~ansible-user/.ssh/authorized_keys
```

on the target machine, with correct permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

#### Use this key with Ansible

Example Ansible test with an explicit key:

```bash
ansible -i inventory <pki-server> -m ping --private-key ~/.ssh/ansible_pki
```

If you want to specify it in the inventory, you can add:

```yaml
<pki-server>:
  ansible_host: <SERVER_IP>
  ansible_user: ansible-user
  ansible_ssh_private_key_file: ~/.ssh/ansible_pki
```

### sudo privileges

The playbooks in this repository use `become`. The remote user must therefore be able to elevate privileges with `sudo`.

Two cases are supported:

- passwordless `sudo` for the remote user
- `sudo` with a password, by running Ansible with `--ask-become-pass`

Recommended check:

```bash
sudo -n true
```

If this command fails, it is not necessarily blocking, but you will need to run playbooks with `--ask-become-pass`.

#### Create a dedicated file in /etc/sudoers.d

If you want to allow `ansible-user` to use `sudo` without a password for Ansible, the cleanest approach is to create a dedicated file in `/etc/sudoers.d/`.

Simple command to run directly on the target machine with the relevant user:

```bash
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
sudo chmod 440 /etc/sudoers.d/$USER
sudo visudo -cf /etc/sudoers.d/$USER
```

This variant creates a sudoers file named after the current user.

On the target machine, as `root` or with an account already authorised to use `sudo`:

```bash
printf 'ansible-user ALL=(ALL) NOPASSWD:ALL\n' | sudo tee /etc/sudoers.d/ansible-user >/dev/null
sudo chmod 440 /etc/sudoers.d/ansible-user
sudo visudo -cf /etc/sudoers.d/ansible-user
```

If you prefer to require a sudo password, use instead:

```bash
printf 'ansible-user ALL=(ALL) ALL\n' | sudo tee /etc/sudoers.d/ansible-user >/dev/null
sudo chmod 440 /etc/sudoers.d/ansible-user
sudo visudo -cf /etc/sudoers.d/ansible-user
```

Quick check from the target:

```bash
sudo -l -U ansible-user
```

Check from the Ansible node:

```bash
ansible -i inventory <pki-server> -b -m command -a "id"
```

Important notes:

- always verify sudoers files with `visudo -cf`
- never edit `/etc/sudoers` directly if a dedicated file in `/etc/sudoers.d/` is sufficient
- on Debian, files in `/etc/sudoers.d/` must remain readable only by `root`, typically mode `440`

### Name resolution and machine identity

The machine hostname and DNS resolution must be consistent with the EJBCA and Apache configuration.

Check in particular:

1. The hostname of the target is consistent with the expected FQDN.
2. The PKI server FQDN resolves correctly from the target and from the machine accessing the service.
3. DNS or `/etc/hosts` does not return a wrong address.

Verification examples:

```bash
hostnamectl
getent hosts <pki-server>.domain.local
```

### Outbound network connectivity

The target machine must be able to download components if you are not using a local mirror or internal cache.

This applies to:

- EJBCA archives
- Debian packages
- certain Java or system dependencies

Simple check:

```bash
apt update
curl -I https://github.com/
```

### Useful system recommendations

These points are not strictly the only Ansible prerequisites, but they prevent many deployment failures:

1. A correct system clock via NTP or systemd-timesyncd.
2. Sufficient disk space in `/opt`, `/var`, `/tmp` and `/home`.
3. No process or local policy blocking `sudo`, `systemctl`, `apt` or writes to `/opt`.
4. Required ports are not already occupied by another service.

Verification examples:

```bash
timedatectl status
df -h
ss -tlnp | egrep ':80|:443|:8080|:8443|:9990|:9993'
```

### Minimal summary

If you just want the minimum checklist on the target side, verify at least:

1. `python3` is installed.
2. `sudo` is installed.
3. `sshd` is active.
4. The Ansible user can connect via SSH.
5. The Ansible user can use `sudo`.
6. The PKI server FQDN resolves correctly.
7. The machine has access to the Internet or your local repositories.

### Quick checklist before the first playbook run

Before running `deployCeNode.yml`, quickly validate this list:

1. The target responds to SSH on the correct IP.
2. The Ansible user exists on the target.
3. `python3`, `sudo` and `openssh-server` are installed.
4. `sudo -n true` works, or you plan to use `--ask-become-pass`.
5. The PKI server entry in `inventory` points to the correct address.
6. The PKI server FQDN matches the actual target server.
7. The target can resolve external names and reach the Internet.
8. No service already occupies ports `80`, `443`, `8080`, `8443`, `9990` or `9993`.

Quick control command from the Ansible node:

```bash
ansible -i inventory <pki-server> -m ping
ansible -i inventory <pki-server> -b -m command -a "python3 --version"
ansible -i inventory <pki-server> -b -m shell -a "sudo -n true || true"
```

### Full preparation example for a new Debian 13 target

Here is a simple, direct example for preparing a freshly installed Debian 13 machine so that Ansible can deploy this project.

#### 1. Install base prerequisites on the target

Connect to the target with an account that already has administrator rights, then run:

```bash
apt update
apt install -y openssh-server python3 sudo curl
systemctl enable --now ssh
```

#### 2. Create the remote user used by Ansible

If the Ansible user does not yet exist:

```bash
adduser ansible-user
```

Or in a more scriptable form:

```bash
useradd -m -s /bin/bash ansible-user
passwd ansible-user
```

#### 3. Prepare the SSH directory for the user

```bash
install -d -m 700 -o ansible-user -g ansible-user /home/ansible-user/.ssh
touch /home/ansible-user/.ssh/authorized_keys
chown ansible-user:ansible-user /home/ansible-user/.ssh/authorized_keys
chmod 600 /home/ansible-user/.ssh/authorized_keys
```

#### 4. Generate an SSH key on the Ansible node

From the Ansible control node:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_pki -C "ansible@<pki-server>"
```

#### 5. Copy the public key to the target

From the Ansible node:

```bash
ssh-copy-id -i ~/.ssh/ansible_pki.pub ansible-user@<pki-server>
```

If necessary, you can also add the key manually to:

```bash
/home/ansible-user/.ssh/authorized_keys
```

#### 6. Grant sudo rights via /etc/sudoers.d

On the target, create a dedicated file:

```bash
printf 'ansible-user ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/ansible-user
chmod 440 /etc/sudoers.d/ansible-user
visudo -cf /etc/sudoers.d/ansible-user
```

If you do not want `NOPASSWD`, use instead:

```bash
printf 'ansible-user ALL=(ALL) ALL\n' > /etc/sudoers.d/ansible-user
chmod 440 /etc/sudoers.d/ansible-user
visudo -cf /etc/sudoers.d/ansible-user
```

#### 7. Set the hostname and verify DNS resolution

On the target:

```bash
hostnamectl set-hostname <pki-server>.domain.local
hostnamectl
getent hosts <pki-server>.domain.local
```

If DNS is not yet in place, add a local entry as needed.

#### 8. Test the SSH connection with the new key

From the Ansible node:

```bash
ssh -i ~/.ssh/ansible_pki ansible-user@<pki-server>
```

#### 9. Verify the Ansible inventory

In this repository, verify that `inventory` contains something like:

```yaml
<pki-server>:
  ansible_host: <SERVER_IP>
  ansible_user: ansible-user
  ansible_ssh_private_key_file: ~/.ssh/ansible_pki
```

#### 10. Run basic Ansible tests

From the Ansible node:

```bash
ansible -i inventory <pki-server> -m ping
ansible -i inventory <pki-server> -b -m command -a "id"
ansible -i inventory <pki-server> -b -m command -a "python3 --version"
```

If these commands pass, the target is generally ready to run the main playbook:

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml
```

## Useful commands

### SSH test

```bash
ssh ansible-user@<pki-server>
```

### Ansible test

With SSH keys already installed:

```bash
ansible -i inventory <pki-server> -m ping
```

With an SSH password:

```bash
ansible -i inventory <pki-server> -m ping --ask-pass
```

### EJBCA Community deployment

With SSH keys and passwordless sudo:

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml
```

With SSH keys and sudo with a password:

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml --ask-become-pass
```

With SSH password and sudo password:

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml --ask-pass --ask-become-pass
```

### EJBCA Community deployment with remote database

For the remote database scenario, use the dedicated playbook with the engine explicitly chosen.

MariaDB remote example:

```bash
ansible-playbook -i inventory deployCeNodeExternalDB.yml -e "database_engine=mariadb database_deployment_mode=remote"
```

PostgreSQL remote example:

```bash
ansible-playbook -i inventory deployCeNodeExternalDB.yml -e "database_engine=postgresql database_deployment_mode=remote"
```

If `sudo` requires a password:

```bash
ansible-playbook -i inventory deployCeNodeExternalDB.yml -e "database_engine=<mariadb|postgresql> database_deployment_mode=remote" --ask-become-pass
```

If SSH also requires a password:

```bash
ansible-playbook -i inventory deployCeNodeExternalDB.yml -e "database_engine=<mariadb|postgresql> database_deployment_mode=remote" --ask-pass --ask-become-pass
```

### Force EJBCA re-download

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml -e force_ejbca_download=true
```

## Post-installation access

Once installation is complete, normal access is via HTTPS through Apache HTTPD on port `443`.

### Main URL

The expected main URL is:

```text
https://<pki-server>.domain.local/
```

The Apache vhost in this repository listens on `443` and generally redirects the root to the EJBCA RA interface.

### Useful EJBCA interfaces

- Main public port : `443`
- Root URL : `https://<pki-server>.domain.local/`
- RA interface : `https://<pki-server>.domain.local/ejbca/ra/`
- EJBCA Admin interface : `https://<pki-server>.domain.local/ejbca/adminweb/`
- EJBCA REST API : `https://<pki-server>.domain.local/ejbca/ejbca-rest-api`
- EJBCA SOAP web services : `https://<pki-server>.domain.local/ejbca/ejbcaws`

Notes:

- the `adminweb` interface requires a valid administrator certificate in practice for sensitive operations
- the root `/` is redirected to `/ejbca/ra/` by the Apache configuration in this repository
- if the PKI server name is not resolved from your workstation, add a DNS entry or `/etc/hosts` entry

Local example on your client machine:

```bash
echo "<SERVER_IP> <pki-server>.domain.local" | sudo tee -a /etc/hosts
```

### Useful internal ports

These ports exist mainly for the internal architecture. In normal use, traffic goes through Apache on `443`.

- WildFly application HTTP : `8080`
- WildFly application HTTPS : `8443`
- WildFly management HTTP : `9990`
- WildFly management HTTPS : `9993`

### WildFly management port

On the PKI server, the WildFly management port is bound to:

```text
127.0.0.1:9990
```

It is therefore not exposed publicly. It is only accessible from the target machine itself, or via an SSH tunnel.

Example SSH tunnel from your machine:

```bash
ssh -L 9990:127.0.0.1:9990 ansible-user@<pki-server>
```

Then in your browser:

```text
http://127.0.0.1:9990/
```

### Quick post-installation checks

From the target machine:

```bash
systemctl status wildfly --no-pager
systemctl status httpd --no-pager
ss -tlnp | egrep ':443|:8080|:8443|:9990|:9993'
```

From your client machine:

```bash
curl -kI https://<pki-server>.domain.local/
curl -kI https://<pki-server>.domain.local/ejbca/ra/
```

If `443` does not respond but `9990` responds locally on the server, this generally means WildFly is running but the Apache HTTPD layer or DNS/FQDN resolution is not yet correct.

## Key adapted variables

### Inventory

The `inventory` file contains only host aliases and groups. Connection parameters are placed in `host_vars` files.

```yaml
all:
  children:
    ceServers:
      hosts:
        <pki-server>:
    mariadbServers:
      hosts: {}
    postgresqlServers:
      hosts:
        <db-server>:
```

### Host vars

The `host_vars/<pki-server>.yml` file contains the node connection parameters. The `hsm_shared_library` key varies by OS family:

```yaml
ansible_host: <PKI_SERVER_IP>
ansible_user: <ansible-user>
ansible_common_remote_group: <ansible-user>
ejbca_supplement_groups: <user>,softhsm
# Debian/Ubuntu:
hsm_shared_library: /usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so
# RedHat/AlmaLinux/Rocky:
# hsm_shared_library: /usr/lib64/softhsm/libsofthsm2.so
```

To change the server name and domain, modify these variables in the node's `host_vars` file:

```yaml
pki_server_name: <pki-server>
pki_domain_name: domain.local
pki_server_fqdn: "{{ pki_server_name }}.{{ pki_domain_name }}"
organizationDomainName: "{{ pki_domain_name }}"
hostname: "{{ pki_server_fqdn }}"
```

Notes:

- the Community node inventory alias corresponds to the value of `pki_server_name`
- the system name, HTTPD certificate and generated URLs will use the configured FQDN
- to change the name later, it is sufficient in practice to modify `pki_server_name` and `pki_domain_name`

### EJBCA Community version

The `group_vars/ceServers.yml` file is aligned with:

```yaml
ejbca_version: 9.3.7
ejbca_software_url: https://github.com/Keyfactor/ejbca-ce/archive/refs/tags/r9.3.7.zip
ejbca_src_dir_name: ejbca-ce-r9.3.7
```

## EJBCA 9.3.7 specifics

On this version, two important points had to be taken into account:

1. `ejbca.sh ca init` must receive `--tokenPass` in non-interactive mode.
2. `ejbcaClientToolBox.sh CaIdGenerator` may display a log line before the CA ID. Only the last output line should be used.

## If the deployment fails

Check in priority:

1. SSH connectivity to the PKI server
2. sudo rights for the Ansible user
3. the FQDN of the target machine
4. Internet access from the target machine
5. WildFly logs on the target
6. EJBCA CLI commands run under the `wildfly` user

Examples:

```bash
ansible -i inventory <pki-server> -m ping
ansible -i inventory <pki-server> -b -m shell -a "systemctl status wildfly --no-pager"
ansible -i inventory <pki-server> -b -m shell -a "sudo -u wildfly /opt/ejbca/bin/ejbca.sh ca listcas"
```

## Note

The original upstream README in English remains the reference for the full set of playbooks.
