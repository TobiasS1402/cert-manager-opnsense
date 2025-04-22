#!/bin/sh

token_path="/var/run/secrets/kubernetes.io/serviceaccount/token"
ca_cert_path="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
namespace_path="/var/run/secrets/kubernetes.io/serviceaccount/namespace"

BACKUPDIR="/tmp"

OPNSENSE_API="https://${OPNSENSE_HOST}/api/trust"

KUBE_TOKEN=`cat $token_path`
KUBE_NAMESPACE=`cat $namespace_path`

request_certs(){
  curl -u $API_KEY:$API_SECRET $OPNSENSE_API/cert/get/$CERT_UUID | jq --raw-output '.cert.crt_payload' >> "$BACKUPDIR/crt.pem"
  curl -u $API_KEY:$API_SECRET $OPNSENSE_API/cert/get/$CERT_UUID | jq --raw-output '.cert.prv_payload' >> "$BACKUPDIR/key.pem"
  curl -u $API_KEY:$API_SECRET $OPNSENSE_API/ca/get/$CA_UUID | jq --raw-output '.ca.crt_payload' >>  "$BACKUPDIR/cacert.pem" 

  cat "$BACKUPDIR/cacert.pem" >> "$BACKUPDIR/crt.pem"
}

send_to_k8s(){
SECRET_JSON=$(cat <<EOF
{
  "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {
    "name": "${SECRET_NAME}",
    "namespace": "${KUBE_NAMESPACE}"
  },
  "type": "kubernetes.io/tls",
  "data": {
    "tls.crt": "$(cat "$BACKUPDIR/crt.pem" | base64 | tr -d '\n')",
    "tls.key": "$(cat "$BACKUPDIR/key.pem" | base64 | tr -d '\n')"
  }
}
EOF
)

SECRET_EXISTS=$(curl -s --insecure -X -v GET "https://kubernetes.default.svc/api/v1/namespaces/$KUBE_NAMESPACE/secrets/$SECRET_NAME" \
    -H "Authorization: Bearer $KUBE_TOKEN")

echo $SECRET_EXISTS

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
}


if [ -n "${KUBE_TOKEN+x}" ] && [ -n "${KUBE_NAMESPACE+x}" ]; then
  if [ -n "${OPNSENSE_HOST+x}" ] && [ -n "${API_KEY+x}" ] && [ -n "${API_SECRET+x}" ] && [ -n "${CERT_UUID+x}" ] && [ -n "${CA_UUID+x}" ] && [ -n "${SECRET_NAME+x}" ]; then
    request_certs
    send_to_k8s
  else
    echo "Required variables not found, did you assign the rolebinding? Exiting."
    exit 1
  fi
else
  echo "Kubernetes variables not found, did you assign the rolebinding? Exiting."
  exit 1
fi



