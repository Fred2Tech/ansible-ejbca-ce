#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-${REPO_DIR}/requirements-galaxy.yml}"
COLLECTIONS_DIR="${COLLECTIONS_DIR:-${REPO_DIR}/.ansible/collections}"
ROLES_DIR="${ROLES_DIR:-${REPO_DIR}/.ansible/roles}"

if ! command -v ansible-galaxy >/dev/null 2>&1; then
  echo "ansible-galaxy is not installed or not in PATH" >&2
  exit 1
fi

if [[ ! -f "${REQUIREMENTS_FILE}" ]]; then
  echo "Requirements file not found: ${REQUIREMENTS_FILE}" >&2
  exit 1
fi

mkdir -p "${COLLECTIONS_DIR}" "${ROLES_DIR}"

echo "Using requirements file: ${REQUIREMENTS_FILE}"
echo "Installing collections into: ${COLLECTIONS_DIR}"
ansible-galaxy collection install \
  --upgrade \
  --requirements-file "${REQUIREMENTS_FILE}" \
  --collections-path "${COLLECTIONS_DIR}"

if awk '
  BEGIN { in_roles = 0; found = 0 }
  /^roles:/ { in_roles = 1; next }
  in_roles && /^[^[:space:]-]/ { in_roles = 0 }
  in_roles && /^[[:space:]]*-[[:space:]]/ { found = 1 }
  END { exit(found ? 0 : 1) }
' "${REQUIREMENTS_FILE}"; then
  echo "Installing roles into: ${ROLES_DIR}"
  ansible-galaxy role install \
    --force \
    --role-file "${REQUIREMENTS_FILE}" \
    --roles-path "${ROLES_DIR}"
fi

echo
echo "Installed collection versions:"
ANSIBLE_COLLECTIONS_PATH="${COLLECTIONS_DIR}:${HOME}/.ansible/collections:/usr/share/ansible/collections" \
ansible-galaxy collection list \
  | grep -E '^(# |ansible\.posix|community\.general|community\.mysql|community\.postgresql)' || true

echo
echo "Done. The repository is configured to prefer collections from ${COLLECTIONS_DIR}."