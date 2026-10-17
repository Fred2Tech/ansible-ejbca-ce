# Changelog

French version: [CHANGELOG.fr.md](CHANGELOG.fr.md)

## 2026-10-16 - Deployment checklist and test node

### Added

- `README.md` / `README.fr.md`: new "Deployment checklist (step by step)" section (Ansible node, target node, pre-flight, deployment command, post-deployment verification).
- `.env.example`: template referenced by the documentation but missing from the repository.
- `host_vars/test_pki-server.yml` and `test_pki-server` entry in `inventory`: test node `192.168.210.50` (EJBCA + MariaDB on the same host).

### Fixed

- `roles/ansible-ejbca-restart-wildfly`: the wait for the transient `ejbca.ear.isdeploying` marker timed out after 180 s when the deployment finished faster than the check, even though EJBCA was deployed correctly. That wait is now non-fatal (`delay: 0`, `timeout: 60`), and an explicit check fails the play with a clear message if `ejbca.ear.failed` exists after the deployment.

### Changed

- `.gitignore`: `.env` and `host_vars/test_pki-server.yml` are now ignored (the documentation already stated that `.env` is not versioned).
- Anonymisation: personal identifiers removed from `README.fr.md` (`fenetre2000` replaced by `ansible-user`) and from the defaults in `group_vars/all.yml` (domain `domain.local`, organisation `Organization`, user/group `ansible-user`, no hardcoded healthcheck IP). Values are still overridden through `.env`.

## 2026-10-16 - Dependency updates

### Changed

| Component | Before | After | File |
| --- | --- | --- | --- |
| Apache Ant | `1.10.15` | `1.10.18` | `group_vars/all.yml` |
| MariaDB JDBC driver (EJBCA) | `3.5.2` | `3.5.10` | `group_vars/all.yml`, `group_vars/mariadbServers.yml` |
| MariaDB JDBC driver (SignServer) | `3.5.2` | `3.5.10` | `group_vars/mariadbServers.yml` |
| PostgreSQL JDBC driver | `42.7.5` | `42.7.14` | `group_vars/all.yml` |

Variables touched in `group_vars/all.yml`:

- `apache_ant_remote_dir`, `ant_version`, `ant_url`, `ant_checksum`
- `mariadb_jdbc_driver`, `mariadb_jdbc_driver_checksum`
- `postgresql_jdbc_driver`, `postgresql_jdbc_driver_checksum`

Variables touched in `group_vars/mariadbServers.yml`:

- `ejbca_jdbc_driver`, `ejbca_jdbc_driver_checksum`
- `signsrv_jdbc_driver`, `signsrv_jdbc_driver_checksum`

### Download sources

- MariaDB and PostgreSQL JDBC drivers are now downloaded from Maven Central (`repo1.maven.org`) instead of `dlm.mariadb.com` and `jdbc.postgresql.org`. The previous MariaDB `3.5.2` checksum matches the Maven Central jar, so it is the same binary.
- Apache Ant is now downloaded from `archive.apache.org/dist/ant/binaries/` instead of the third-party mirror `mirror.olnevhost.net`. The archive keeps old releases, so the URL stays valid over time.

### Checksums (SHA256)

| Artifact | SHA256 |
| --- | --- |
| `apache-ant-1.10.18-bin.tar.gz` | `b45db2fdd76d639301550930d33dd7bc672c9d4fdea0fe8cfd2e6a3518388d59` |
| `mariadb-java-client-3.5.10.jar` | `919b8c1c771d9ee3465811462f242c9543ab401e140c64988ddbf1d8abcb18b2` |
| `postgresql-42.7.14.jar` | `73914527305a40cce504b0d3d90b23caf565136912d607ae8ae7c5895512332c` |

The PostgreSQL checksum was previously empty, so the download was not verified. It is now enforced.

### Documentation

- `README.md` and `README.fr.md`: "Product versions" section updated with the new versions and a note about the updates.

### Intentionally not updated

| Component | Kept | Latest available | Reason |
| --- | --- | --- | --- |
| EJBCA CE | `9.3.7` | `9.6.3` | As of 9.6, HSM crypto tokens require EJBCA Enterprise, while this project ships SoftHSM/PKCS#11 roles. Compatibility with WildFly 35 is also unconfirmed. |
| WildFly | `35.0.1.Final` | `41.0.1.Final` | Large jump: the `standalone-35.xml.datasource.j2` template and the jboss-client checksum must be reviewed. |
| WildFly Galleon | `6.0.5` | `7.0.11.Final` | Tied to the WildFly upgrade. |
| MariaDB server | `11.8` | `11.8` is still LTS | No change needed. |

### Validation status

- `group_vars/all.yml` and `group_vars/mariadbServers.yml` parse as valid YAML.
- Not yet validated by a full deployment (for example `deployCeNode.yml` with MariaDB and PostgreSQL).
