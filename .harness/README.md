# Harness deployment for hello-python

This folder contains ready-to-import Harness YAML to deploy the Kubernetes manifests in `k8s/` to your existing EKS cluster using the image from ECR.

## What you'll set up
- Service: `hello_python` using ECR artifact and k8s manifests from this repo
- Environment + Infra: `prod` with `eks_hello` (KubernetesDirect to your EKS)
- Pipeline: `hello_python_deploy` with an `IMAGE_TAG` variable (default `latest`)
- InputSet: `latest-tag` for quick manual runs

## Prereqs
- EKS cluster created and kubeconfig working (already done in this project)
- ECR repo with an image tag (e.g., `latest`): `186463824337.dkr.ecr.us-east-1.amazonaws.com/ecr_kareem_repo:latest`
- This repo pushed to a Git provider that Harness can read (GitHub/GitLab/Bitbucket)

## Steps
1) Create a free Harness account at https://app.harness.io
2) Create a Project (e.g., `default_project`) in the `default` Org or adjust identifiers in YAML.
3) Add Connectors:
   - AWS connector: identifier `aws_ecr` with permissions to ECR (us-east-1).
   - Kubernetes connector: identifier `k8s_eks` that uses your local kubeconfig or cluster credentials. Easiest path: install a Delegate in the EKS cluster and have the K8s connector use that delegate.
   - Git connector: identifier `repo_git` pointing to this repo; default branch `main`.
4) (Recommended) Install a Delegate in your EKS cluster: Project Setup -> Delegates -> New -> Kubernetes YAML. Apply the YAML to the cluster and wait until status is Healthy.
5) Import these YAMLs: Project Setup -> Pipelines (or YAML) -> Remote -> Import YAML -> select files in `.harness/`.
6) Open Pipeline `hello_python_deploy`, click Run, choose the InputSet `latest-tag` or set `IMAGE_TAG` to a specific tag.

## What the pipeline does
- Resolves the ECR image tag from the `aws_ecr` connector and substitutes it into the manifests.
- Fetches `k8s/` directory from Git and applies via a Rolling Deploy to namespace `hello` on your EKS cluster.

## Verify
- In Harness, watch the stage logs until success.
- From your terminal, you can validate:
  - `kubectl -n hello get deploy,pods`
  - `kubectl -n hello logs deploy/hello-python --tail=20`

## Troubleshooting
- 403/AccessDenied on ECR: ensure the AWS connector has permissions and region `us-east-1`.
- Image tag not found: push the tag to ECR or change `IMAGE_TAG`.
- K8s connector fails: ensure the delegate is online and has network access to the cluster.

## Customization
- Update `orgIdentifier`, `projectIdentifier`, and connector refs to match your setup.
- Use immutable tags (e.g., Git SHA) by running your push script with a versioned tag and supplying it via `IMAGE_TAG` when you run the pipeline.