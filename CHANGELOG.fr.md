# Changelog

Version anglaise : [CHANGELOG.md](CHANGELOG.md)

## 2026-10-17 - EJBCA Community 9.6.3

### Modifie

- EJBCA CE `9.3.7` -> `9.6.3` dans `group_vars/ceServers.yml` (`ejbca_version`, `ejbca_remote_dir`, `ejbca_software_url`, `ejbca_src_dir_name`, `ejbca_upgrade_version`) et dans les deux README.
- WildFly `35.0.1.Final` est conserve: il est toujours liste comme supporte par EJBCA 9.6.

### Corrige

- `roles/ansible-ejbca-complete-upgrade`: `ant upgrade` s'executait en environ une seconde sans rien afficher, et l'avertissement de post-migration restait dans l'Admin UI (« Post upgrade is required... »). Le role appelle maintenant directement `ejbca.sh upgrade` (meme operation que le menu « System Upgrade »), qui affiche son resultat et renvoie un code retour. La tache echoue sur `Post Upgrade not performed`, `failed` ou `was interrupted`, et est `changed` sur `Post Upgrade completed`.
- `roles/ansible-ejbca-upgrade`: apres la copie du nouvel EAR, le role attend maintenant que WildFly l'ait redeploye (le marqueur `ejbca.ear.deployed` est rafraichi) et echoue clairement si `ejbca.ear.failed` apparait. Auparavant `ant upgrade` (role `ansible-ejbca-complete-upgrade`) s'executait juste apres la copie, peut-etre avant que le nouvel EAR ne tourne.

### Notes de compatibilite

- EJBCA CE 9.6 impose l'edition Enterprise pour les crypto tokens HSM. Les CA de ce projet utilisent `SoftCryptoToken`, elles ne sont donc pas concernees. Ne pas utiliser `tokentype: PKCS11CryptoToken` avec CE 9.6+.
- Java 21.0.5 ou superieur est requis (le noeud de test utilise 21.0.10).
- Pas encore valide sur un noeud reel: faire un deploiement neuf, ou `upgradeEjbca.yml` sur un noeud existant. Les contournements 9.3.7 (`--tokenPass`, derniere ligne de `CaIdGenerator`) sont conserves et restent a reverifier.

## 2026-10-16 - Checklist de deploiement et noeud de test

### Ajoute

- `deployCodeSigning.yml` et role `ansible-ejbca-code-signing`: import d'un profil de certificat `CodeSigning` (EKU Code Signing, RSA 3072/4096, SHA-256) et creation d'end entities signataires qui s'enrollent depuis le RA web avec username et code d'enrollment. Nouvelle variable `PKI_CODESIGNING_ENROLLMENT_CODE` (`.env.example`, `group_vars/all.yml`). Documente dans `README.md` / `README.fr.md`. Pas encore valide sur un noeud reel.
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
| WildFly | `35.0.1.Final` | `41.0.1.Final` | Toujours supporte par EJBCA 9.6. Passer en 39/41 demande de revoir le template `standalone-35.xml.datasource.j2`, la version de Galleon et le checksum du client jboss. |
| WildFly Galleon | `6.0.5` | `7.0.11.Final` | Lie a la montee de version de WildFly. |
| MariaDB serveur | `11.8` | `11.8` est toujours LTS | Aucun changement necessaire. |

### Etat de validation

- `group_vars/all.yml` et `group_vars/mariadbServers.yml` sont du YAML valide.
- Pas encore valide par un deploiement complet (par exemple `deployCeNode.yml` avec MariaDB et PostgreSQL).
