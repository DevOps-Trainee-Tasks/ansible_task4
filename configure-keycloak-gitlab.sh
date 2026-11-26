#!/bin/bash
set -e

kc() {
  docker exec keycloak /opt/keycloak/bin/kcadm.sh "$@"
}

docker exec keycloak sh -c 'KC_CLI_PASSWORD="$KC_BOOTSTRAP_ADMIN_PASSWORD" /opt/keycloak/bin/kcadm.sh config credentials --server http://127.0.0.1:8080/auth --realm master --user admin'

if kc get identity-provider/instances/gitlab -r task4 >/dev/null 2>&1; then
  kc update identity-provider/instances/gitlab -r task4 \
    -s "config.clientId=$GITLAB_CLIENT_ID" \
    -s "config.clientSecret=$GITLAB_CLIENT_SECRET"
else
  kc create identity-provider/instances -r task4 \
    -s alias=gitlab -s providerId=gitlab -s enabled=true \
    -s "config.clientId=$GITLAB_CLIENT_ID" \
    -s "config.clientSecret=$GITLAB_CLIENT_SECRET"
fi

read -r execution config < <(
  kc get authentication/flows/browser/executions -r task4 |
    python3 -c 'import json,sys; x=next(i for i in json.load(sys.stdin) if i.get("providerId")=="identity-provider-redirector"); print(x["id"],x.get("authenticationConfig") or "-")'
)

if [ "$config" = "-" ]; then
  kc create "authentication/executions/$execution/config" -r task4 \
    -s alias=gitlab-default -s config.defaultProvider=gitlab
else
  kc update "authentication/config/$config" -r task4 \
    -s config.defaultProvider=gitlab
fi