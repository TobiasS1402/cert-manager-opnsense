#!/bin/bash

token_path="/var/run/secrets/kubernetes.io/serviceaccount/token"
ca_cert_path="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
namespace_path="/var/run/secrets/kubernetes.io/serviceaccount/namespace"

BACKUPDIR="/tmp"

OPNSENSE_API="https://${OPNSENSE_HOST}/api/trust"

KUBE_TOKEN=`cat namespace_path`
KUBE_NAMESPACE=`cat token_path`


curl -u $API_KEY:$API_SECRET 'Authorization:Basic $test' $OPNSENSE_API/cert/get/$CERT_UUID | jq --raw-output '.cert.crt' >> "$BACKUPDIR/key.pem"
curl -u $API_KEY:$API_SECRET $OPNSENSE_API/cert/get/$CERT_UUID | jq --raw-output '.cert.prv' >> "$BACKUPDIR/cert.pem"
curl -u $API_KEY:$API_SECRET $OPNSENSE_API/ca/get/$CA_UUID | jq --raw-output '.ca.crt' >>  "$BACKUPDIR/cacert.pem" 

cat "$BACKUPDIR/cacert.pem" >> "$BACKUPDIR/cert.pem"

SECRET_JSON=$(cat <<EOF
{
  "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {
    "name": "${SECRET_NAME}",
    "namespace": "${NAMESPACE:-default}"
  },
  "type": "kubernetes.io/tls",
  "data": {
    "tls.crt": "$(cat "$BACKUPDIR/cert.pem" | base64 -w 0)",
    "tls.key": "$(cat "$BACKUPDIR/key.pem" | base64 -w 0)"
  }
}
EOF
)

# unsure if this will work
curl --insecure -X POST "https://kubernetes.default.svc/api/v1/namespaces/$namespace_path/secrets" \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SECRET_JSON" \