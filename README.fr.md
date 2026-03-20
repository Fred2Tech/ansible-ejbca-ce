# README FR

Ce depot permet de deployer EJBCA Community avec Ansible.

Ce fichier est une version francaise pratique du README principal, avec un accent mis sur le cas le plus simple dans ce workspace:

- deploiement EJBCA Community
- hote cible configurable via `pki_server_name` dans `host_vars`
- connexion SSH avec l'utilisateur defini dans `.env` via `PKI_ANSIBLE_USER`
- machine cible Debian 13

Le workspace contient aussi plusieurs fichiers `host_vars` pour les noeuds Community et les noeuds de base distante utilises dans les exemples et validations.

## Vue d'ensemble

Le playbook Community principal est `deployCeNode.yml`.

Pour le cas avec base distante, le playbook a utiliser dans cette copie est `deployCeNodeExternalDB.yml`.

Il installe et configure notamment:

- MariaDB ou PostgreSQL
- WildFly
- SoftHSM
- EJBCA Community
- Apache HTTPD
- une Management CA
- une Root CA
- une Sub CA
- le compte SuperAdmin

## Comportement apres installation

Dans cette copie du projet, l'installation Community fait maintenant aussi les actions suivantes automatiquement:

- ajoute les regles necessaires dans le `Public Access Role` pour que la Management CA, la Root CA et la Sub CA apparaissent dans la page RA `CA Certificates and CRLs`
- rend donc les CA visibles directement dans `https://<fqdn>/ejbca/ra/cas.xhtml`
- exporte les certificats CA sur le controleur Ansible dans le repertoire `ejbcaCaCerts/`
- exporte aussi le fichier PKCS#12 du Super Administrator dans ce meme repertoire

Apres un deploiement reussi, on doit donc retrouver typiquement:

- `ejbcaCaCerts/ManagementCA.crt`
- `ejbcaCaCerts/<Organisation>-Root-CA.crt`
- `ejbcaCaCerts/<Organisation>-Sub-CA.crt`
- `ejbcaCaCerts/<Organisation>-SuperAdministrator.p12`

Avec des valeurs anonymisees comme dans `.env.example`, cela correspond par exemple a:

- `ejbcaCaCerts/ManagementCA.crt`
- `ejbcaCaCerts/Organization-RootCA.crt`
- `ejbcaCaCerts/Organization-SubCA.crt`
- `ejbcaCaCerts/Organization-SuperAdministrator.p12`

## Upgrade WildFly et EJBCA

Cette copie du workspace contient aussi des playbooks d'upgrade dedies au perimetre Community:

- `upgradeWildfly.yml` : relance l'installation/configuration WildFly puis recompile et redeploie EJBCA
- `upgradeEjbca.yml` : prepare la nouvelle source EJBCA sur tous les noeuds `ceServers`, puis execute `ant upgrade` sur le premier noeud du groupe

Commandes minimales:

```bash
ansible-playbook -i inventory -l <pki-server> upgradeWildfly.yml
ansible-playbook -i inventory -l <pki-server> upgradeEjbca.yml
```

Pour valider les playbooks sans nouvelle version disponible, le plus sur est de commencer par:

```bash
ansible-playbook -i inventory --syntax-check upgradeWildfly.yml
ansible-playbook -i inventory --syntax-check upgradeEjbca.yml
ansible-playbook -i inventory -l <pki-server> --list-hosts upgradeWildfly.yml
ansible-playbook -i inventory -l <pki-server> --list-hosts upgradeEjbca.yml
```

Pour un test plus proche du reel sans changer de version de production, l'astuce recommandee est de travailler sur une VM restauree depuis backup ou snapshot, puis de fournir temporairement un paquet EJBCA rezippe dans un nouveau repertoire source via:

- `ejbca_upgrade_software_url`
- `ejbca_upgrade_src_dir`

Cela permet de valider le flux Ansible complet sans dependre d'une vraie release plus recente.

## Fichiers importants

- `inventory` : inventaire Ansible et utilisateur SSH utilise pour chaque hote
- `inventory.example` : modele d'inventaire annote — copier vers `inventory` et remplir vos hotes
- `host_vars/<pki-server>.yml` : variables d'un noeud Community (un fichier par noeud, adapte a l'OS cible)
- `host_vars/<db-server>.yml` : variables d'un serveur DB distant (un fichier par serveur)
- `group_vars/ceServers.yml` : variables du deploiement Community
- `group_vars/mariadbServers.yml` et `group_vars/postgresqlServers.yml` : variables du serveur DB distant selon le moteur
- `deployCeNode.yml` : playbook principal pour EJBCA Community
- `deployCeNodeExternalDB.yml` : playbook Community avec base distante
- `.env.example` : reference des variables centralisees pour users, groups et passwords cote controleur
- `scripts/with-env.sh` : script utilitaire pour charger `.env` avant d'executer Ansible
- `requirements-galaxy.yml` : liste des collections Ansible Galaxy utilisees par ce depot
- `scripts/update-galaxy-deps.sh` : script pour installer ou mettre a jour ces dependances localement dans le depot
- `ansible.cfg` : configuration Ansible locale

## Liste de verification avant deploiement

Tableau recapitulatif des points a valider avant de lancer un playbook. Cocher chaque ligne avant le premier lancement.

### Poste de controle Ansible

| # | Verification | Commande | Resultat attendu |
|---|---|---|---|
| 1 | Fichier `.env` cree depuis `.env.example` | `cat .env` | Variables remplies (domaine, org, users, passwords) |
| 2 | Fichier `inventory` configure | `cat inventory` | L'alias du noeud cible apparait dans `ceServers` |
| 3 | `host_vars/<pki-server>.yml` renseigne | `cat host_vars/<pki-server>.yml` | IP reelle, user SSH, `pki_server_name` |
| 4 | `host_vars/<db-server>.yml` renseigne *(remote uniquement)* | `cat host_vars/<db-server>.yml` | IP reelle, user SSH, `hostname` |
| 5 | Dependances Galaxy installees | `./scripts/update-galaxy-deps.sh` | Aucune erreur |
| 6 | Cle SSH generee sur le poste Ansible | `ssh-keygen -t ed25519 -f ~/.ssh/ansible_pki` | Fichiers `~/.ssh/ansible_pki` et `~/.ssh/ansible_pki.pub` presents |
| 7 | Cle publique copiee sur le noeud PKI | `ssh-copy-id -i ~/.ssh/ansible_pki.pub <user>@<pki-server>` | Aucune erreur |
| 8 | Cle publique copiee sur le noeud DB *(remote uniquement)* | `ssh-copy-id -i ~/.ssh/ansible_pki.pub <user>@<db-server>` | Aucune erreur |
| 9 | Connexion SSH sans mot de passe | `ssh -i ~/.ssh/ansible_pki <user>@<pki-server> exit` | Connexion directe, exit 0 |

### Machine cible (noeud PKI)

| # | Verification | Commande sur la cible | Resultat attendu |
|---|---|---|---|
| 10 | `python3` installe | `python3 --version` | Version affichee |
| 11 | `sudo` installe | `sudo -V \| head -n 1` | Version affichee |
| 12 | `sshd` actif | `systemctl is-active ssh \|\| systemctl is-active sshd` | `active` |
| 13 | Fichier sudoers cree dans `/etc/sudoers.d/` | `printf '<user> ALL=(ALL) NOPASSWD:ALL\n' \| sudo tee /etc/sudoers.d/<user> && sudo chmod 440 /etc/sudoers.d/<user> && sudo visudo -cf /etc/sudoers.d/<user>` | `...parsed OK` |
| 14 | Droits sudo sans mot de passe | `sudo -n true` | Aucune erreur |
| 15 | FQDN resolu | `getent hosts <pki-server>.domain.local` | IP correcte |
| 16 | Acces Internet ou depot local | `curl -sI https://github.com/ \| head -1` | `HTTP/2 200` ou `301` |
| 17 | Ports libres | `ss -tlnp \| grep -E ':80\|:443\|:8080\|:8443\|:9990\|:9993'` | Vide (aucun service en conflit) |
| 18 | Espace disque suffisant | `df -h /opt /var /tmp` | Au moins 5 Go disponibles dans `/opt` |
| 19 | Horloge synchronisee | `timedatectl status` | `synchronized: yes` |

### Validation depuis le poste Ansible

| # | Verification | Commande | Resultat attendu |
|---|---|---|---|
| 20 | Ping Ansible vers le noeud PKI | `ansible -i inventory <pki-server> -m ping` | `pong` |
| 21 | Ping Ansible vers le noeud DB *(remote uniquement)* | `ansible -i inventory <db-server> -m ping` | `pong` |
| 22 | Elevation sudo fonctionne | `ansible -i inventory <pki-server> -b -m command -a "id"` | `uid=0(root)` |

## Scenario base distante

Cette copie `ansible_ejbca-ce` supporte deux modes principaux:

- `deployCeNode.yml` : EJBCA Community avec base locale sur le meme noeud
- `deployCeNodeExternalDB.yml` : EJBCA Community sur `<pki-server>` avec base distante sur l'hote `<db-server>`

Dans le mode base distante:

- `<pki-server>` porte WildFly, EJBCA et Apache
- `<db-server>` porte le serveur DB distant
- le datasource WildFly prend automatiquement l'hote defini pour le groupe DB correspondant au moteur choisi
- les parametres de connexion SSH sont definis dans `host_vars/<pki-server>.yml` et `host_vars/<db-server>.yml`

Exemple minimal de structure attendue:

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

Et dans les `host_vars`:

```yaml
# host_vars/<pki-server>.yml
ansible_host: <IP_DU_SERVEUR_PKI>
ansible_user: fenetre2000
pki_server_name: <pki-server>
pki_domain_name: "{{ domain_name }}"
```

```yaml
# host_vars/<db-server>.yml
ansible_host: <IP_DU_SERVEUR_DB>
ansible_user: fenetre2000
hostname: <db-server>.domain.local
```

Ordre d'execution recommande:

1. Verifier l'acces SSH et sudo sur `<pki-server>` et `<db-server>`.
2. Verifier la resolution du FQDN applicatif `<pki-server>.domain.local`.
3. Lancer `deployCeNodeExternalDB.yml`.

## Etat actuel du workspace

Le workspace a deja ete adapte pour:

- utiliser un utilisateur SSH configurable via `.env` sur le serveur PKI
- utiliser des fichiers `host_vars/<db-server>.yml` pour les parametres de connexion des serveurs de base distants
- prendre en charge Debian 13 pour MariaDB, PostgreSQL, WildFly et SoftHSM
- prendre en charge AlmaLinux 10 et plus largement les variantes Red Hat pour MariaDB, PostgreSQL, WildFly et SoftHSM
- valider aussi Rocky Linux 10.1 sur `<pki-server>` et `<db-server>` pour MariaDB et PostgreSQL, en local et en remote
- valider aussi Red Hat Enterprise Linux 10.1 sur `<pki-server>` et `<db-server>` pour MariaDB et PostgreSQL, en local et en remote
- valider aussi Ubuntu 24.04 sur `<pki-server>` et `<db-server>` pour MariaDB et PostgreSQL, en local et en remote
- corriger trois problemes de timing specifiques a Ubuntu 24.04: persistance en base apres `ra addendentity`, disponibilite du bean `GlobalConfigurationSessionBean` avant les commandes `config protocols`, et race condition systemd lors de l'arret de WildFly en toute premiere installation
- pointer vers EJBCA CE `9.3.7`

## Matrice de validation

Le tableau ci-dessous resume les combinaisons OS, moteur de base et mode de deploiement couvertes dans ce workspace.

| OS du noeud EJBCA | OS du noeud DB distant | Base de donnees | Mode local DB | Mode remote DB | Statut |
| --- | --- | --- | --- | --- | --- |
| Debian 13 | Debian 13 | MariaDB | ✅ valide | ✅ valide | ✅ valide |
| Debian 13 | Debian 13 | PostgreSQL | ✅ valide | ✅ valide | ✅ valide |
| AlmaLinux 10.1 | AlmaLinux 10.1 | MariaDB | ✅ valide | ✅ valide | ✅ valide |
| AlmaLinux 10.1 | AlmaLinux 10.1 | PostgreSQL | ✅ valide | ✅ valide | ✅ valide |
| Rocky Linux 10.1 | Rocky Linux 10.1 | MariaDB | ✅ valide | ✅ valide | ✅ valide |
| Rocky Linux 10.1 | Rocky Linux 10.1 | PostgreSQL | ✅ valide | ✅ valide | ✅ valide |
| Red Hat Enterprise Linux 10.1 | Red Hat Enterprise Linux 10.1 | MariaDB | ✅ valide | ✅ valide | ✅ valide |
| Red Hat Enterprise Linux 10.1 | Red Hat Enterprise Linux 10.1 | PostgreSQL | ✅ valide | ✅ valide | ✅ valide |
| Ubuntu 24.04 | Ubuntu 24.04 | MariaDB | ✅ valide | ✅ valide | ✅ valide |
| Ubuntu 24.04 | Ubuntu 24.04 | PostgreSQL | ✅ valide | ✅ valide | ✅ valide |

Lecture rapide:

- `local` signifie que le moteur de base tourne sur le meme noeud que WildFly et EJBCA
- `remote` signifie que le moteur de base tourne sur un serveur DB dedie
- `✅ valide` signifie que le scenario a ete execute et valide
- `n/a` signifie que le mode n'est pas applicable a la combinaison deployee

## Versions des produits

Voici les versions principales visees ou observees sur le serveur PKI.

- EJBCA Community : `9.3.7`
- WildFly : `35.0.1.Final`
- WildFly Galleon : `6.0.5`
- OpenJDK runtime detecte : `21.0.10`
- Paquet Java Debian utilise : `default-jdk-headless` version `2:1.21-76`
- Paquet OpenJDK Debian : `openjdk-21-jdk-headless` version `21.0.10+7-1~deb13u1`
- MariaDB serveur : `11.8.3-0+deb13u1`
- Driver JDBC PostgreSQL configure : `42.7.5`
- SoftHSM : `2.6.1-3`
- Apache Ant : `1.10.15`
- Driver JDBC MariaDB : `3.5.2`

Informations utiles:

- le repertoire WildFly observe sur la cible est `/opt/wildfly-35.0.1.Final`
- le repertoire source EJBCA observe sur la cible est `/opt/ejbca-ce-r9.3.7`
- le driver JDBC deploie dans WildFly depend du moteur choisi: `mariadb-java-client.jar` ou `postgresql.jar`

## Centralisation des users, groups et passwords

Ce depot peut maintenant centraliser les variables les plus sensibles ou les plus repetitives dans un fichier `.env` a la racine du repository.

Les variables chargees couvrent notamment:

- le domaine PKI, le nom d'organisation et le code pays
- le nom de la Management CA et le CN du SuperAdmin
- la liste des IPs autorisees pour le healthcheck
- l'utilisateur SSH Ansible
- le groupe distant commun
- les groupes supplementaires EJBCA
- l'utilisateur et le groupe applicatifs `wildfly`
- le nom, l'utilisateur et les passwords de base de donnees
- les passwords CLI EJBCA, HTTPD, SuperAdmin et les PIN de crypto tokens

Le fichier `.env` n'est pas lu automatiquement par Ansible. Pour charger proprement ce fichier avant une commande, utiliser:

```bash
./scripts/with-env.sh ansible-playbook -i inventory -l <pki-server> deployCeNode.yml -e 'database_engine=mariadb database_deployment_mode=local'
```

Le depot fournit:

- `.env.example` : liste des variables supportees
- `.env` : fichier local ignore par git pour vos valeurs courantes
- `scripts/with-env.sh` : wrapper qui charge `.env` puis execute la commande demandee

Extrait anonymise coherent avec `.env.example`:

```dotenv
PKI_DOMAIN_NAME=doamin.local
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

Les ajouts les plus pertinents dans `.env` sont donc maintenant:

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

Exemples utiles:

```bash
./scripts/with-env.sh ansible -i inventory <pki-server> -m ping
./scripts/with-env.sh ansible-playbook -i inventory -l <pki-server> deployCeNode.yml -e 'database_engine=postgresql database_deployment_mode=local'
./scripts/with-env.sh ansible-playbook -i inventory -l <pki-server>,<db-server> deployCeNodeExternalDB.yml -e 'database_engine=mariadb database_deployment_mode=remote database_server_inventory_name=<db-server>'
```

## Dependances Ansible Galaxy sur le poste de controle

Ce depot utilise plusieurs collections Ansible Galaxy externes, notamment:

- `ansible.posix`
- `community.general`
- `community.mysql`
- `community.postgresql`

La liste de reference est maintenue dans `requirements-galaxy.yml`.

Pour eviter de dependre uniquement des collections installees globalement sur le poste de controle, ce depot est configure pour preferer des dependances locales dans `.ansible/collections` et `.ansible/roles`.

Avant un premier lancement, ou apres une mise a jour d'Ansible ou du poste de controle, executer:

```bash
./scripts/update-galaxy-deps.sh
```

Ce script:

- installe ou met a jour les collections definies dans `requirements-galaxy.yml`
- les place dans `.ansible/collections`
- installe aussi d'eventuels roles Galaxy dans `.ansible/roles`
- s'appuie sur `ansible.cfg`, deja configure pour preferer ces chemins locaux

En cas de probleme de module, de collection ou de version sur le poste de controle, commencer par relancer ce script puis verifier la configuration chargee par Ansible:

```bash
./scripts/update-galaxy-deps.sh
ansible-config dump --only-changed | egrep 'COLLECTIONS_PATHS|DEFAULT_ROLES_PATH'
```

## Prerequis pour qu'Ansible fonctionne correctement sur la machine cible

Avant de lancer le deploiement, verifier les points suivants sur la machine cible Debian 13.

### Paquets minimaux a avoir sur la cible

Ansible a besoin au minimum de ces composants cote cible:

- `openssh-server` installe et demarre
- `python3` installe
- `sudo` installe
- un shell standard utilisable par l'utilisateur distant

Exemple de verification directe sur la cible:

```bash
dpkg -l openssh-server python3 sudo
systemctl status ssh --no-pager
python3 --version
sudo -V | head -n 1
```

### Acces SSH

Le controleur Ansible doit pouvoir se connecter en SSH avec l'utilisateur defini dans l'inventaire.

Dans ce workspace, c'est actuellement:

- utilisateur SSH : `fenetre2000`
- hote cible : valeur de `pki_server_name` dans `host_vars`
- FQDN applicatif : `<pki-server>.<domain_name>`

Verifications conseillees:

1. La connexion SSH fonctionne sans blocage interactif inattendu.
2. La cle publique du controleur est bien presente dans `~fenetre2000/.ssh/authorized_keys` si vous utilisez des cles.
3. Si vous utilisez un mot de passe SSH, vous lancez Ansible avec `--ask-pass`.

Test simple:

```bash
ssh fenetre2000@<pki-server>
```

#### Creer une paire de cles SSH sur le poste Ansible

Si vous n'avez pas encore de cle dediee pour Ansible, vous pouvez en creer une sur le poste de controle:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_pki -C "ansible@<pki-server>"
```

Cela genere en general:

- la cle privee `~/.ssh/ansible_pki`
- la cle publique `~/.ssh/ansible_pki.pub`

Si vous voulez eviter toute invite de passphrase pour les executions automatiques, laissez la passphrase vide au moment de la creation.

#### Copier la cle publique sur la machine cible

La methode la plus simple est `ssh-copy-id`:

```bash
ssh-copy-id -i ~/.ssh/ansible_pki.pub fenetre2000@<pki-server>
```

Ensuite, tester explicitement la cle:

```bash
ssh -i ~/.ssh/ansible_pki fenetre2000@<pki-server>
```

Si `ssh-copy-id` n'est pas disponible, vous pouvez copier la cle manuellement:

```bash
cat ~/.ssh/ansible_pki.pub
```

Puis ajouter son contenu dans:

```bash
~fenetre2000/.ssh/authorized_keys
```

sur la machine cible, avec des permissions correctes:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

#### Utiliser cette cle avec Ansible

Exemple de test Ansible avec une cle explicite:

```bash
ansible -i inventory <pki-server> -m ping --private-key ~/.ssh/ansible_pki
```

Si vous voulez l'indiquer dans l'inventaire, vous pouvez ajouter:

```yaml
<pki-server>:
  ansible_host: <IP_DU_SERVEUR>
  ansible_user: fenetre2000
  ansible_ssh_private_key_file: ~/.ssh/ansible_pki
```

### Privileges sudo

Les playbooks de ce depot utilisent `become`. L'utilisateur distant doit donc pouvoir elever ses privileges avec `sudo`.

Deux cas sont supportes:

- `sudo` sans mot de passe pour l'utilisateur distant
- `sudo` avec mot de passe, en lancant Ansible avec `--ask-become-pass`

Verification conseillee:

```bash
sudo -n true
```

Si cette commande echoue, ce n'est pas forcement bloquant, mais il faudra lancer les playbooks avec `--ask-become-pass`.

#### Creer un fichier dedie dans /etc/sudoers.d

Si vous voulez autoriser `fenetre2000` a utiliser `sudo` sans mot de passe pour Ansible, le plus propre est de creer un fichier dedie dans `/etc/sudoers.d/`.

Commande simple a executer directement sur la machine cible avec l'utilisateur concerne:

```bash
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
sudo chmod 440 /etc/sudoers.d/$USER
sudo visudo -cf /etc/sudoers.d/$USER
```

Cette variante cree un fichier sudoers portant le nom de l'utilisateur courant.

Sur la machine cible, en tant que `root` ou avec un compte deja autorise a utiliser `sudo`:

```bash
printf 'fenetre2000 ALL=(ALL) NOPASSWD:ALL\n' | sudo tee /etc/sudoers.d/fenetre2000-ansible >/dev/null
sudo chmod 440 /etc/sudoers.d/fenetre2000-ansible
sudo visudo -cf /etc/sudoers.d/fenetre2000-ansible
```

Si vous preferez exiger un mot de passe sudo, utilisez plutot:

```bash
printf 'fenetre2000 ALL=(ALL) ALL\n' | sudo tee /etc/sudoers.d/fenetre2000-ansible >/dev/null
sudo chmod 440 /etc/sudoers.d/fenetre2000-ansible
sudo visudo -cf /etc/sudoers.d/fenetre2000-ansible
```

Verification rapide depuis la cible:

```bash
sudo -l -U fenetre2000
```

Verification depuis le poste Ansible:

```bash
ansible -i inventory <pki-server> -b -m command -a "id"
```

Remarque importante:

- toujours verifier les fichiers sudoers avec `visudo -cf`
- ne jamais modifier directement `/etc/sudoers` si un fichier dedie dans `/etc/sudoers.d/` suffit
- sur Debian, les fichiers dans `/etc/sudoers.d/` doivent rester lisibles uniquement par `root`, typiquement en mode `440`

### Resolution de nom et identite machine

Le nom de machine et la resolution DNS doivent etre coherents avec la configuration EJBCA et Apache.

Verifier en particulier:

1. Le hostname de la cible est coherent avec le FQDN attendu.
2. Le FQDN du serveur PKI se resout correctement depuis la cible et depuis le poste qui accede au service.
3. Le DNS ou `/etc/hosts` ne renvoie pas une mauvaise adresse.

Exemples de verification:

```bash
hostnamectl
getent hosts <pki-server>.domain.local
```

### Connectivite reseau sortante

La machine cible doit pouvoir telecharger les composants si vous n'utilisez pas de miroir local ou de cache interne.

Cela concerne notamment:

- les archives EJBCA
- les paquets Debian
- certaines dependances Java ou systeme

Verification simple:

```bash
apt update
curl -I https://github.com/
```

### Recommandations systeme utiles

Ces points ne sont pas strictement les seuls prerequis Ansible, mais ils evitent beaucoup d'echecs pendant le deploiement:

1. Une horloge systeme correcte via NTP ou systemd-timesyncd.
2. Suffisamment d'espace disque dans `/opt`, `/var`, `/tmp` et `/home`.
3. Aucun processus ou politique locale ne bloque `sudo`, `systemctl`, `apt` ou l'ecriture dans `/opt`.
4. Les ports necessaires ne sont pas deja occupes par un autre service.

Exemples de verification:

```bash
timedatectl status
df -h
ss -tlnp | egrep ':80|:443|:8080|:8443|:9990|:9993'
```

### Resume minimal

Si vous voulez juste la checklist minimum cote cible, verifier au moins ceci:

1. `python3` est installe.
2. `sudo` est installe.
3. `sshd` est actif.
4. `fenetre2000` se connecte en SSH.
5. `fenetre2000` peut utiliser `sudo`.
6. Le FQDN du serveur PKI se resout correctement.
7. La machine a acces a Internet ou a vos depots locaux.

### Checklist rapide avant premier lancement du playbook

Avant d'executer `deployCeNode.yml`, valider rapidement cette liste:

1. La cible repond en SSH sur la bonne IP.
2. L'utilisateur `fenetre2000` existe sur la cible.
3. `python3`, `sudo` et `openssh-server` sont installes.
4. `sudo -n true` fonctionne, ou bien vous prevoyez `--ask-become-pass`.
5. L'entree du serveur PKI dans `inventory` pointe vers la bonne adresse.
6. Le FQDN du serveur PKI correspond bien au serveur cible.
7. La cible peut resoudre les noms externes et sortir sur Internet.
8. Aucun service n'occupe deja les ports `80`, `443`, `8080`, `8443`, `9990` ou `9993`.

Commande de controle rapide depuis le poste Ansible:

```bash
ansible -i inventory <pki-server> -m ping
ansible -i inventory <pki-server> -b -m command -a "python3 --version"
ansible -i inventory <pki-server> -b -m shell -a "sudo -n true || true"
```

### Exemple complet de preparation d'une cible Debian 13 neuve

Voici un exemple simple et direct pour preparer une machine Debian 13 fraichement installee afin qu'Ansible puisse deployer ce projet.

#### 1. Installer les prerequis de base sur la cible

Se connecter sur la cible avec un compte ayant deja les droits d'administration, puis executer:

```bash
apt update
apt install -y openssh-server python3 sudo curl
systemctl enable --now ssh
```

#### 2. Creer l'utilisateur distant utilise par Ansible

Si l'utilisateur `fenetre2000` n'existe pas encore:

```bash
adduser fenetre2000
```

Ou en mode plus scriptable:

```bash
useradd -m -s /bin/bash fenetre2000
passwd fenetre2000
```

#### 3. Preparer le repertoire SSH de l'utilisateur

```bash
install -d -m 700 -o fenetre2000 -g fenetre2000 /home/fenetre2000/.ssh
touch /home/fenetre2000/.ssh/authorized_keys
chown fenetre2000:fenetre2000 /home/fenetre2000/.ssh/authorized_keys
chmod 600 /home/fenetre2000/.ssh/authorized_keys
```

#### 4. Generer une cle SSH sur le poste Ansible

Depuis le poste de controle Ansible:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_pki -C "ansible@<pki-server>"
```

#### 5. Copier la cle publique vers la cible

Depuis le poste Ansible:

```bash
ssh-copy-id -i ~/.ssh/ansible_pki.pub fenetre2000@<pki-server>
```

Si necessaire, vous pouvez aussi ajouter la cle manuellement dans:

```bash
/home/fenetre2000/.ssh/authorized_keys
```

#### 6. Donner les droits sudo via /etc/sudoers.d

Sur la cible, creer un fichier dedie:

```bash
printf 'fenetre2000 ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/fenetre2000-ansible
chmod 440 /etc/sudoers.d/fenetre2000-ansible
visudo -cf /etc/sudoers.d/fenetre2000-ansible
```

Si vous ne voulez pas de `NOPASSWD`, utilisez a la place:

```bash
printf 'fenetre2000 ALL=(ALL) ALL\n' > /etc/sudoers.d/fenetre2000-ansible
chmod 440 /etc/sudoers.d/fenetre2000-ansible
visudo -cf /etc/sudoers.d/fenetre2000-ansible
```

#### 7. Verifier le hostname et la resolution DNS

Sur la cible:

```bash
hostnamectl set-hostname <pki-server>.domain.local
hostnamectl
getent hosts <pki-server>.domain.local
```

Si le DNS n'est pas encore en place, ajouter une entree locale au besoin.

#### 8. Tester la connexion SSH avec la nouvelle cle

Depuis le poste Ansible:

```bash
ssh -i ~/.ssh/ansible_pki fenetre2000@<pki-server>
```

#### 9. Verifier l'inventaire Ansible

Dans ce depot, verifier que `inventory` contient bien quelque chose de ce type:

```yaml
<pki-server>:
  ansible_host: <IP_DU_SERVEUR>
  ansible_user: fenetre2000
  ansible_ssh_private_key_file: ~/.ssh/ansible_pki
```

#### 10. Lancer les tests Ansible de base

Depuis le poste Ansible:

```bash
ansible -i inventory <pki-server> -m ping
ansible -i inventory <pki-server> -b -m command -a "id"
ansible -i inventory <pki-server> -b -m command -a "python3 --version"
```

Si ces commandes passent, la cible est en general prete pour lancer le playbook principal:

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml
```

## Commandes utiles

### Test SSH

```bash
ssh fenetre2000@<pki-server>
```

### Test Ansible

Si vous utilisez les cles SSH deja installees:

```bash
ansible -i inventory <pki-server> -m ping
```

Si vous utilisez un mot de passe SSH:

```bash
ansible -i inventory <pki-server> -m ping --ask-pass
```

### Deploiement EJBCA Community

Avec cles SSH et sudo sans mot de passe:

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml
```

Avec cles SSH et sudo avec mot de passe:

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml --ask-become-pass
```

Avec mot de passe SSH et mot de passe sudo:

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml --ask-pass --ask-become-pass
```

### Deploiement EJBCA Community avec base distante

Pour le scenario avec base distante, utiliser le playbook dedie avec le moteur explicitement choisi.

Exemple MariaDB distant:

```bash
ansible-playbook -i inventory deployCeNodeExternalDB.yml -e "database_engine=mariadb database_deployment_mode=remote"
```

Exemple PostgreSQL distant:

```bash
ansible-playbook -i inventory deployCeNodeExternalDB.yml -e "database_engine=postgresql database_deployment_mode=remote"
```

Si `sudo` demande un mot de passe:

```bash
ansible-playbook -i inventory deployCeNodeExternalDB.yml -e "database_engine=<mariadb|postgresql> database_deployment_mode=remote" --ask-become-pass
```

Si SSH demande aussi un mot de passe:

```bash
ansible-playbook -i inventory deployCeNodeExternalDB.yml -e "database_engine=<mariadb|postgresql> database_deployment_mode=remote" --ask-pass --ask-become-pass
```

### Forcer le retelechargement d'EJBCA

```bash
ansible-playbook -i inventory -l <pki-server> deployCeNode.yml -e force_ejbca_download=true
```

## Acces apres installation

Une fois l'installation terminee, l'acces normal se fait en HTTPS via Apache HTTPD, en facade, sur le port `443`.

### URL principale

L'URL principale attendue est:

```text
https://<pki-server>.domain.local/
```

Le vhost Apache de ce depot ecoute sur `443` et redirige en general la racine vers l'interface RA EJBCA.

### Interfaces EJBCA utiles

- Port public principal : `443`
- URL racine : `https://<pki-server>.domain.local/`
- Interface RA : `https://<pki-server>.domain.local/ejbca/ra/`
- Interface Admin EJBCA : `https://<pki-server>.domain.local/ejbca/adminweb/`
- API REST EJBCA : `https://<pki-server>.domain.local/ejbca/ejbca-rest-api`
- Web services SOAP EJBCA : `https://<pki-server>.domain.local/ejbca/ejbcaws`

Remarques:

- l'interface `adminweb` demande en pratique un certificat administrateur valide pour les operations sensibles
- la racine `/` est redirigee vers `/ejbca/ra/` par la configuration Apache de ce depot
- si le nom du serveur PKI n'est pas resolu depuis ton poste, il faut ajouter une entree DNS ou `/etc/hosts`

Exemple local sur ton poste client:

```bash
echo "<IP_DU_SERVEUR> <pki-server>.domain.local" | sudo tee -a /etc/hosts
```

### Ports internes utiles

Ces ports existent surtout pour l'architecture interne. En usage normal, on passe par Apache sur `443`.

- WildFly HTTP applicatif : `8080`
- WildFly HTTPS applicatif : `8443`
- WildFly management HTTP : `9990`
- WildFly management HTTPS : `9993`

### Port de management WildFly

Sur le serveur PKI, le port de management WildFly est:

```text
127.0.0.1:9990
```

Donc il n'est pas expose publiquement. Il n'est accessible que depuis la machine cible, ou via un tunnel SSH.

Exemple de tunnel SSH depuis ta machine:

```bash
ssh -L 9990:127.0.0.1:9990 fenetre2000@<pki-server>
```

Puis dans ton navigateur:

```text
http://127.0.0.1:9990/
```

### Verifications rapides apres installation

Depuis la machine cible:

```bash
systemctl status wildfly --no-pager
systemctl status httpd --no-pager
ss -tlnp | egrep ':443|:8080|:8443|:9990|:9993'
```

Depuis ton poste client:

```bash
curl -kI https://<pki-server>.domain.local/
curl -kI https://<pki-server>.domain.local/ejbca/ra/
```

Si `443` ne repond pas mais que `9990` repond en local sur le serveur, cela signifie en general que WildFly tourne mais que la couche Apache HTTPD ou la resolution DNS/FQDN n'est pas encore correcte.

## Variables principales deja adaptees

### Inventory

Le fichier `inventory` ne contient plus que les alias d'hotes et les groupes. Les parametres de connexion sont places dans les fichiers `host_vars`.

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

Le fichier `host_vars/<pki-server>.yml` contient les parametres de connexion du noeud. La cle `hsm_shared_library` varie selon la famille d'OS:

```yaml
ansible_host: <IP_DU_SERVEUR_PKI>
ansible_user: <ansible-user>
ansible_common_remote_group: <ansible-user>
ejbca_supplement_groups: <user>,softhsm
# Debian/Ubuntu:
hsm_shared_library: /usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so
# RedHat/AlmaLinux/Rocky:
# hsm_shared_library: /usr/lib64/softhsm/libsofthsm2.so
```

Pour changer le nom du serveur et le domaine, modifier ces variables dans le fichier `host_vars` du noeud:

```yaml
pki_server_name: <pki-server>
pki_domain_name: domain.local
pki_server_fqdn: "{{ pki_server_name }}.{{ pki_domain_name }}"
organizationDomainName: "{{ pki_domain_name }}"
hostname: "{{ pki_server_fqdn }}"
```

Remarque:

- l'alias d'inventaire du noeud Community correspond a la valeur de `pki_server_name`
- le nom systeme, le certificat HTTPD et les URLs generees utiliseront le FQDN configure
- pour changer de nom plus tard, il suffit en pratique de modifier `pki_server_name` et `pki_domain_name`

### Version EJBCA Community

Le fichier `group_vars/ceServers.yml` est aligne sur:

```yaml
ejbca_version: 9.3.7
ejbca_software_url: https://github.com/Keyfactor/ejbca-ce/archive/refs/tags/r9.3.7.zip
ejbca_src_dir_name: ejbca-ce-r9.3.7
```

## Particularites EJBCA 9.3.7

Sur cette version, deux points importants ont du etre pris en compte:

1. `ejbca.sh ca init` doit recevoir `--tokenPass` en non interactif.
2. `ejbcaClientToolBox.sh CaIdGenerator` peut afficher une ligne de log avant l'ID de CA. Il faut utiliser uniquement la derniere ligne en sortie.

## Si le deploiement echoue

Verifier en priorite:

1. la connectivite SSH vers le serveur PKI
2. les droits sudo de `fenetre2000`
3. le FQDN de la machine cible
4. l'acces Internet de la machine cible
5. les logs WildFly sur la cible
6. les commandes EJBCA CLI lancees sous l'utilisateur `wildfly`

Exemples:

```bash
ansible -i inventory <pki-server> -m ping
ansible -i inventory <pki-server> -b -m shell -a "systemctl status wildfly --no-pager"
ansible -i inventory <pki-server> -b -m shell -a "sudo -u wildfly /opt/ejbca/bin/ejbca.sh ca listcas"
```

## Remarque

Le README original en anglais reste la reference upstream pour l'ensemble des playbooks.
Ce fichier `README.fr.md` sert surtout de guide de travail local et de guide rapide pour un deploiement Community en francais.