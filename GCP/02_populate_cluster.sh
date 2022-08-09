#!/bin/bash
set -euo pipefail

source ./00_variables.sh

export YAML_BUNDLE="./echo_server_with_sidecar.yaml"

# Do not run this script if you didn't run '01_init.sh' script first!
kubectl create serviceaccount ${SECRET_MANAGER_SA_NAME} --namespace ${K8S_NAMESPACE}
gcloud iam service-accounts create ${SECRET_MANAGER_SA_NAME} --project=${PROJECT_ID}

gcloud iam service-accounts add-iam-policy-binding ${SECRET_MANAGER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${K8S_NAMESPACE}/${SECRET_MANAGER_SA_NAME}]"

# HINT: We allow directly at the RESOURCE level because ACG doesn't allow our USER ACCOUNTS to grant permissions at the PROJECT level.
gcloud secrets add-iam-policy-binding ${SECRET_NAME} \
    --member='serviceAccount:${SECRET_MANAGER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com' \
    --role='roles/secretmanager.secretAccessor'

# HINT: We allow directly at the RESOURCE level because ACG doesn't allow our USER ACCOUNTS to grant permissions at the PROJECT level.
gcloud secrets add-iam-policy-binding ${SECRET_NAME} \
    --member='serviceAccount:${SECRET_MANAGER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com' \
    --role='roles/secretmanager.viewer'

kubectl annotate serviceaccount ${SECRET_MANAGER_SA_NAME} \
    --namespace ${K8S_NAMESPACE} \
    iam.gke.io/gcp-service-account=${SECRET_MANAGER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

if [[ -f ${YAML_BUNDLE} ]]; then
  rm ${YAML_BUNDLE}
fi

# TODO: This should be a Helm.
for files in $(ls k8s/echo-server-with-sidecar); do
  echo "---" >> ${YAML_BUNDLE}
  sed \
    -e "s,MY_FACEBOOK_TOKEN_FILE,${FACEBOOK_TOKEN_FILE}," \
    -e "s,MY_FACEBOOK_TOKEN_PATH,${FACEBOOK_TOKEN_PATH}," \
    -e "s,MY_PROJECT_ID,${PROJECT_ID}," \
    -e "s,MY_SECRET_NAME,${SECRET_NAME}," \
    k8s/echo-server-with-sidecar/${files} >> ${YAML_BUNDLE}
  echo "" >> ${YAML_BUNDLE}
 done

echo "You should now run \"kubectl apply -f ./${YAML_BUNDLE}\" manually."