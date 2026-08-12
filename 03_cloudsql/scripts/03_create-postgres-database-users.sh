#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

APP_PASSWORD_SECRET_VERSION=''
MIGRATION_PASSWORD_SECRET_VERSION=''
while (($#)); do
  case "$1" in
    --app-password-secret-version=*) APP_PASSWORD_SECRET_VERSION="${1#*=}" ;;
    --migration-password-secret-version=*) MIGRATION_PASSWORD_SECRET_VERSION="${1#*=}" ;;
    --help)
      printf 'Passwords come from stdin or Secret Manager version references.\n'
      exit 0
      ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

valid_name() { [[ "$1" =~ ^[a-z][a-z0-9_]{0,62}$ ]]; }
valid_secret_version() {
  [[ "$1" =~ ^projects/[a-z0-9-]+/secrets/[a-zA-Z0-9_-]+/versions/[a-zA-Z0-9_-]+$ ]]
}

if ! valid_name "${POSTGRES_DATABASE_NAME}" ||
  ! valid_name "${POSTGRES_APP_USER}" || ! valid_name "${POSTGRES_MIGRATION_USER}" ||
  [[ "${POSTGRES_APP_USER}" == "${POSTGRES_MIGRATION_USER}" ]] ||
  { [[ -n "${APP_PASSWORD_SECRET_VERSION}" ]] && ! valid_secret_version "${APP_PASSWORD_SECRET_VERSION}"; } ||
  { [[ -n "${MIGRATION_PASSWORD_SECRET_VERSION}" ]] && ! valid_secret_version "${MIGRATION_PASSWORD_SECRET_VERSION}"; }; then
  printf 'Invalid PostgreSQL database, user, or secret reference configuration\n' >&2
  exit 1
fi

if ! gcloud sql databases describe "${POSTGRES_DATABASE_NAME}" \
  --instance="${POSTGRES_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  gcloud sql databases create "${POSTGRES_DATABASE_NAME}" \
    --instance="${POSTGRES_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}"
fi

read_password() {
  local secret_version="$1" label="$2" password=''
  if [[ -n "${secret_version}" ]]; then
    password="$(gcloud secrets versions access "${secret_version}" \
      --project="${GOOGLE_PROJECT_ID}")"
  elif [[ -t 0 ]]; then
    read -r -s -p "${label} password: " password < /dev/tty
    printf '\n' >&2
  else
    IFS= read -r password || true
  fi
  [[ -n "${password}" && "${password}" != *$'\n'* ]] || {
    printf '%s password input is required\n' "${label}" >&2
    exit 1
  }
  printf '%s' "${password}"
}

create_user() {
  local user="$1" secret_version="$2" label="$3" password flags_file
  if gcloud sql users describe "${user}" --instance="${POSTGRES_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
    return
  fi
  password="$(read_password "${secret_version}" "${label}")"
  flags_file="$(mktemp)"
  chmod 600 "${flags_file}"
  trap 'rm -f "${flags_file}"' RETURN
  # gcloud receives a descriptor path, not a password-bearing argv value.
  escaped_password="${password//\'/\'\'}"
  printf -- "--password: '%s'\n" "${escaped_password}" >"${flags_file}"
  gcloud sql users create "${user}" --instance="${POSTGRES_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}" \
    --flags-file="${flags_file}"
  rm -f "${flags_file}"
  trap - RETURN
  unset password escaped_password
}

create_user "${POSTGRES_APP_USER}" "${APP_PASSWORD_SECRET_VERSION}" application
create_user "${POSTGRES_MIGRATION_USER}" "${MIGRATION_PASSWORD_SECRET_VERSION}" migration
