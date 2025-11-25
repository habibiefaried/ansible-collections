#!/bin/bash
sudo snap alias microk8s.kubectl kubectl
set -euo pipefail

# Usage: ./generate-kafka-tls.sh
# Requirements: keytool (from JDK), openssl, kubectl
#
# This script:
#  - creates namespace kafka-secure
#  - creates a CA (ca.key, ca.crt)
#  - for each broker creates keystore.jks, csr, signed cert, and truststore.jks
#  - creates a single Kubernetes secret kafka-tls-secret with each broker's keystore/truststore + ca
#  - creates a secret kafka-superadmin-secret with username/password (used by brokers as a reference)
#
# install:  sudo apt install openjdk-21-jdk openssl -y
# IMPORTANT: In production, use proper CA and stronger passwords. This script uses 'changeit' defaults.

NAMESPACE="kafka-secure"
OUTDIR="kafka-tls-artifacts"
BROKERS=( "broker-1" "broker-2" "broker-3" )

# Passwords (change these!)
KS_PASS="changeit"
TS_PASS="changeit"
SUPERADMIN_USER="superadmin"
SUPERADMIN_PASS="superpassword123"

mkdir -p "$OUTDIR"
cd "$OUTDIR"

echo "==> Creating namespace $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Clean old broker-specific files ONLY
rm -f broker-*.keystore.jks broker-*.truststore.jks broker-*.csr broker-*.crt

echo "==> Generating CA key/cert"
openssl req -new -x509 -days 3650 -nodes -subj "/CN=Kafka-CA" -out ca.crt -keyout ca.key

for b in "${BROKERS[@]}"; do
  echo "==> Generating keystore for $b"
  keytool -genkeypair -alias "$b" \
    -keyalg RSA -keysize 2048 \
    -keystore "${b}.keystore.jks" \
    -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -dname "CN=${b}" -validity 3650

  echo "==> Creating CSR for $b"
  keytool -certreq -alias "$b" \
    -keystore "${b}.keystore.jks" -storepass "$KS_PASS" \
    -file "${b}.csr"

  echo "==> Signing CSR with CA for $b"
  openssl x509 -req -in "${b}.csr" -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out "${b}.crt" -days 3650 -sha256

  echo "==> Import CA then certificate back into ${b}.keystore.jks"
  # import CA
  keytool -import -noprompt -trustcacerts -alias CARoot \
    -file ca.crt -keystore "${b}.keystore.jks" -storepass "$KS_PASS"
  # import signed cert
  keytool -import -noprompt -alias "$b" -file "${b}.crt" \
    -keystore "${b}.keystore.jks" -storepass "$KS_PASS"

  echo "==> Creating truststore for $b (contains CA)"
  keytool -import -noprompt -trustcacerts -alias CARoot \
    -file ca.crt -keystore "${b}.truststore.jks" -storepass "$TS_PASS"
done

echo "==> Prepare jaas.conf (server-side minimal; SCRAM stored in metadata)"
cat > jaas.conf <<'EOF'
KafkaServer {
  org.apache.kafka.common.security.scram.ScramLoginModule required;
};
EOF

# Remove existing secret if exists (avoid conflict)
kubectl -n "$NAMESPACE" delete secret kafka-tls-secret --ignore-not-found
kubectl -n "$NAMESPACE" delete secret kafka-superadmin-secret --ignore-not-found

echo "==> Creating Kubernetes secret kafka-tls-secret in namespace $NAMESPACE"
# Build --from-file args
args=()
args+=( "--from-file=ca.crt=ca.crt" )
args+=( "--from-file=ca.key=ca.key" )
args+=( "--from-file=jaas.conf=jaas.conf" )
for b in "${BROKERS[@]}"; do
  args+=( "--from-file=${b}.keystore.jks=${b}.keystore.jks" )
  args+=( "--from-file=${b}.truststore.jks=${b}.truststore.jks" )
done

# Create the secret and include pw as literals (stringData-like)
kubectl -n "$NAMESPACE" create secret generic kafka-tls-secret "${args[@]}" \
  --from-literal=keystore.password="$KS_PASS" \
  --from-literal=truststore.password="$TS_PASS"

echo "==> Creating kafka-superadmin-secret (contains desired SCRAM password reference)"
kubectl -n "$NAMESPACE" create secret generic kafka-superadmin-secret \
  --from-literal=username="${SUPERADMIN_USER}" \
  --from-literal=password="${SUPERADMIN_PASS}"

echo "==> Files generated in $OUTDIR:"
ls -1

echo "==> DONE. Secrets created:"
kubectl -n "$NAMESPACE" get secrets kafka-tls-secret kafka-superadmin-secret -o wide

echo ""
echo "Next steps:"
echo " 1) Apply the Kubernetes manifest (kafka-secure-full.yaml) which references kafka-tls-secret and kafka-superadmin-secret."
echo " 2) Wait for pods to become Ready."
echo " 3) Exec into any broker pod and run kafka-configs.sh to create the SCRAM user (example provided in README below)."
