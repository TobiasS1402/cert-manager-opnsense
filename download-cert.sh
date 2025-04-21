#!/bin/bash

token_path="/var/run/secrets/kubernetes.io/serviceaccount/token"
ca_cert_path="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
namespace_path="/var/run/secrets/kubernetes.io/serviceaccount/namespace"

BACKUPDIR="/tmp"

OPNSENSE_API="https://${OPNSENSE_HOST}/api/trust"

KUBE_TOKEN=`cat $token_path`
KUBE_NAMESPACE=`cat $namespace_path`


curl -u $API_KEY:$API_SECRET $OPNSENSE_API/cert/get/$CERT_UUID | jq --raw-output '.cert.crt' >> "$BACKUPDIR/crt.pem"
curl -u $API_KEY:$API_SECRET $OPNSENSE_API/cert/get/$CERT_UUID | jq --raw-output '.cert.prv' >> "$BACKUPDIR/key.pem"
curl -u $API_KEY:$API_SECRET $OPNSENSE_API/ca/get/$CA_UUID | jq --raw-output '.ca.crt' >>  "$BACKUPDIR/cacert.pem" 

cat "$BACKUPDIR/cacert.pem" >> "$BACKUPDIR/cert.pem"

SECRET_JSON=$(cat <<EOF
{
  "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {
    "name": "${SECRET_NAME}",
    "namespace": "${KUBE_NAMESPACE}"
  },
  "annotations": {
    "reflector.v1.k8s.emberstack.com/reflection-allowed": "true",
    "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces": ""
  },
  "type": "kubernetes.io/tls",
  "data": {
    "tls.crt": "$(cat "$BACKUPDIR/cert.pem")",
    "tls.key": "$(cat "$BACKUPDIR/key.pem")"
  }
}
EOF
)

SECRET_EXISTS=$(curl -s --insecure -X -v GET "https://kubernetes.default.svc/api/v1/namespaces/$KUBE_NAMESPACE/secrets/customcert" \
    -H "Authorization: Bearer $KUBE_TOKEN" | jq -r '.kind')

cat $SECRET_EXISTS

if [[ "$SECRET_EXISTS" == "Secret" ]]; then
    echo "Secret customcert already exists, patching."
    curl -v --insecure -X PATCH "https://kubernetes.default.svc/api/v1/namespaces/$KUBE_NAMESPACE/secrets" \
    -H "Authorization: Bearer $KUBE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SECRET_JSON"
else
    echo "Secret does not exist, creating..."
    curl -v --insecure -X POST "https://kubernetes.default.svc/api/v1/namespaces/$KUBE_NAMESPACE/secrets" \
        -H "Authorization: Bearer $KUBE_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$SECRET_JSON"
fi