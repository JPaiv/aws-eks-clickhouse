# apps/ — GitOps territory

Everything under this directory is reconciled by Argo CD, starting from the
root Application that `stacks/admin/argocd` points at `apps/root`. Nothing
here ever appears in a `tofu plan`
([ADR-0009](../docs/adr/0009-gitops-bootstrap-boundary.md)).

AWS resources are created from here through the ACK controllers: IAM roles as
`iam.services.k8s.aws/Role` manifests (path `/ack/`, carrying the permissions
boundary), Pod Identity associations as `eks.services.k8s.aws/PodIdentityAssociation`
([ADR-0012](../docs/adr/0012-ack-identity-fixed-point.md)).

The fleet is hub-and-spoke
([ADR-0013](../docs/adr/0013-hub-and-spoke-fleet.md)): spoke clusters are
Git manifests here, created by the hub's ACK EKS controller. Copy a directory
under `spokes/` to add a spoke; delete it to retire one.

```
root/     Child Applications the root app-of-apps deploys (controllers, spokes, ApplicationSets)
hub/      ACK resources reconciled on the hub itself — e.g. identity for Git-onboarded controllers
spokes/   One directory per spoke cluster — cluster, access entries, Argo registration
fleet/    Workloads the spoke-baseline ApplicationSet lands on every fleet=spoke cluster
```

Onboarding a new ACK controller (s3, kms, …) is three manifests, no OpenTofu:
its Application under `root/`, and a `Role` + `PodIdentityAssociation` under
`hub/ack-identity/` — the IAM and EKS controllers reconcile the latter two into
the AWS role and Pod Identity binding the new controller needs
([ADR-0012](../docs/adr/0012-ack-identity-fixed-point.md)).
