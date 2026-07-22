# apps/ — GitOps territory

Everything under this directory is reconciled by Argo CD, starting from the
root Application that `stacks/admin/argocd` points at `apps/root`. Nothing
here ever appears in a `tofu plan`
([ADR-0009](../docs/adr/0009-gitops-bootstrap-boundary.md)).

AWS resources are created from here through the ACK controllers: IAM roles as
`iam.services.k8s.aws/Role` manifests (path `/ack/`, carrying the permissions
boundary), Pod Identity associations as `eks.services.k8s.aws/PodIdentityAssociation`
([ADR-0012](../docs/adr/0012-ack-identity-fixed-point.md)).

```
root/   Child Applications the root app-of-apps deploys
```
