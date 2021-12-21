#!/usr/bin/env bash

kind create cluster --name=0.22-1.5.0
kubectx kind-0.22-1.5.0
kubectl create ns crossplane-system
helm install crossplane --namespace crossplane-system crossplane-stable/crossplane --version 1.5.0 --wait

AWS_PROFILE=default && echo -e "[default]\naws_access_key_id = $(aws configure get aws_access_key_id --profile $AWS_PROFILE)\naws_secret_access_key = $(aws configure get aws_secret_access_key --profile $AWS_PROFILE)" > creds.conf
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=./creds.conf
rm creds.conf

p_yaml="$( cat <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: docker.io/crossplane/provider-aws:v0.22.0
EOF
)"

echo "${p_yaml}" | kubectl apply -f -
kubectl wait "provider.pkg.crossplane.io/provider-aws" --for=condition=healthy --timeout=180s

sleep 30
kubectl apply -f providerconfig.yaml
kubectl apply -f ./manifests/composition.yaml
kubectl apply -f ./manifests/definition.yaml
sleep 15
kubectl apply -f ./manifests/claim.yaml
sleep 60

# kubectl delete -f ./manifests/claim.yaml 
# kind delete cluster --name 0.22-1.5.0