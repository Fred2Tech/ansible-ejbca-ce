# Changelog

Version anglaise : [CHANGELOG.md](CHANGELOG.md)

## 2026-10-16 - Checklist de deploiement et noeud de test

### Ajoute

- `README.md` / `README.fr.md`: nouvelle section « Checklist de deploiement (pas a pas) » (poste Ansible, machine cible, pre-controle, commande de deploiement, verification apres deploiement).
- `.env.example`: modele reference par la documentation mais absent du depot.
- `host_vars/test_pki-server.yml` et entree `test_pki-server` dans `inventory`: noeud de test `192.168.210.50` (EJBCA + MariaDB sur la meme machine).

### Corrige

- `roles/ansible-ejbca-restart-wildfly`: l'attente du marqueur transitoire `ejbca.ear.isdeploying` expirait apres 180 s quand le deploiement se terminait plus vite que le controle, alors qu'EJBCA etait bien deploye. Cette attente n'est plus bloquante (`delay: 0`, `timeout: 60`), et une verification explicite fait echouer le play avec un message clair si `ejbca.ear.failed` existe apres le deploiement.

### Modifie

- `.gitignore`: `.env` et `host_vars/test_pki-server.yml` sont desormais ignores (la documentation indiquait deja que `.env` n'est pas versionne).
- Anonymisation: identifiants personnels retires de `README.fr.md` (`fenetre2000` remplace par `ansible-user`) et des valeurs par defaut de `group_vars/all.yml` (domaine `domain.local`, organisation `Organization`, utilisateur/groupe `ansible-user`, plus d'IP healthcheck en dur). Les valeurs restent surchargees via `.env`.

## 2026-10-16 - Mises a jour des dependances

### Modifie

| Composant | Avant | Apres | Fichier |
| --- | --- | --- | --- |
| Apache Ant | `1.10.15` | `1.10.18` | `group_vars/all.yml` |
| Driver JDBC MariaDB (EJBCA) | `3.5.2` | `3.5.10` | `group_vars/all.yml`, `group_vars/mariadbServers.yml` |
| Driver JDBC MariaDB (SignServer) | `3.5.2` | `3.5.10` | `group_vars/mariadbServers.yml` |
| Driver JDBC PostgreSQL | `42.7.5` | `42.7.14` | `group_vars/all.yml` |

Variables modifiees dans `group_vars/all.yml`:

- `apache_ant_remote_dir`, `ant_version`, `ant_url`, `ant_checksum`
- `mariadb_jdbc_driver`, `mariadb_jdbc_driver_checksum`
- `postgresql_jdbc_driver`, `postgresql_jdbc_driver_checksum`

Variables modifiees dans `group_vars/mariadbServers.yml`:

- `ejbca_jdbc_driver`, `ejbca_jdbc_driver_checksum`
- `signsrv_jdbc_driver`, `signsrv_jdbc_driver_checksum`

### Sources de telechargement

- Les drivers JDBC MariaDB et PostgreSQL sont desormais telecharges depuis Maven Central (`repo1.maven.org`) au lieu de `dlm.mariadb.com` et `jdbc.postgresql.org`. L'ancien checksum MariaDB `3.5.2` correspond au jar de Maven Central: c'est le meme binaire.
- Apache Ant est desormais telecharge depuis `archive.apache.org/dist/ant/binaries/` au lieu du miroir tiers `mirror.olnevhost.net`. L'archive conserve les anciennes versions, l'URL reste donc valide dans le temps.

### Checksums (SHA256)

| Artefact | SHA256 |
| --- | --- |
| `apache-ant-1.10.18-bin.tar.gz` | `b45db2fdd76d639301550930d33dd7bc672c9d4fdea0fe8cfd2e6a3518388d59` |
| `mariadb-java-client-3.5.10.jar` | `919b8c1c771d9ee3465811462f242c9543ab401e140c64988ddbf1d8abcb18b2` |
| `postgresql-42.7.14.jar` | `73914527305a40cce504b0d3d90b23caf565136912d607ae8ae7c5895512332c` |

Le checksum PostgreSQL etait vide auparavant: le telechargement n'etait donc pas verifie. Il est maintenant impose.

### Documentation

- `README.md` et `README.fr.md`: section "Versions des produits" mise a jour avec les nouvelles versions et une note sur les mises a jour.

### Volontairement non mis a jour

| Composant | Conserve | Derniere version | Raison |
| --- | --- | --- | --- |
| EJBCA CE | `9.3.7` | `9.6.3` | Des la 9.6, les crypto tokens HSM necessitent EJBCA Enterprise, alors que le projet fournit des roles SoftHSM/PKCS#11. La compatibilite avec WildFly 35 n'est pas non plus confirmee. |
| WildFly | `35.0.1.Final` | `41.0.1.Final` | Saut important: le template `standalone-35.xml.datasource.j2` et le checksum du client jboss sont a revoir. |
| WildFly Galleon | `6.0.5` | `7.0.11.Final` | Lie a la montee de version de WildFly. |
| MariaDB serveur | `11.8` | `11.8` est toujours LTS | Aucun changement necessaire. |

### Etat de validation

- `group_vars/all.yml` et `group_vars/mariadbServers.yml` sont du YAML valide.
- Pas encore valide par un deploiement complet (par exemple `deployCeNode.yml` avec MariaDB et PostgreSQL).
