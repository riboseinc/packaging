#!/bin/bash -e

# GIT_REPO=/usr/local/yum
GIT_HTTPS_USERNAME="$1"
GIT_HTTPS_PASSWORD="$2"

urlencode() {
  # urlencode <string>
  old_lc_collate=$LC_COLLATE
  LC_COLLATE=C

  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-])
        printf "%s" "$c"
        ;;
      *)
        printf '%%%02X' "'$c"
        ;;
    esac
  done

  LC_COLLATE=$old_lc_collate
}

urldecode() {
  # urldecode <string>

  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

git config --global credential.helper store

encoded_username=$(urlencode "${GIT_HTTPS_USERNAME}")
encoded_password=$(urlencode "${GIT_HTTPS_PASSWORD}")

cat > ~/.git-credentials <<EOF
https://${encoded_username?}:${encoded_password?}@github.com
EOF
