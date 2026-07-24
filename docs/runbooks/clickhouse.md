# Runbook — Verify the ClickHouse data plane

End-to-end check that the dev spoke's ClickHouse cluster is up, authenticating
to S3 with Pod Identity, and replicating across both replicas. See
[ADR-0015](../adr/0015-clickhouse-data-plane.md).

The pieces reconcile as a dependency chain — **bucket → role → association →
pods** — asynchronously, so on a fresh apply the pods may crashloop until their
Pod Identity association is ACTIVE, then recover. Work top to bottom; each
section gates the next.

## 1. Hub side — the ACK resources exist and synced

Context = hub (the default kubeconfig):

```bash
task k8s:kubeconfig                     # hub: per-en1-admin-ack

# The new Argo apps are healthy
kubectl -n argocd get application ack-s3-controller
kubectl -n argocd get applicationset spoke-clickhouse

# The three ACK CRs report ACK.ResourceSynced=True (they live in ns "spokes")
for kind in \
  buckets.s3.services.k8s.aws/per-en1-dev-clickhouse-data \
  roles.iam.services.k8s.aws/per-en1-dev-clickhouse-s3 \
  podidentityassociations.eks.services.k8s.aws/per-en1-dev-clickhouse-s3 ; do
  echo -n "$kind -> "
  kubectl -n spokes get "$kind" \
    -o jsonpath='{.status.conditions[?(@.type=="ACK.ResourceSynced")].status}{"\n"}'
done
```

Confirm the same three exist in AWS:

```bash
aws s3api head-bucket --bucket per-en1-dev-clickhouse-data && echo "bucket OK"
aws eks list-pod-identity-associations \
  --cluster-name per-en1-dev-clickhouse \
  --query "associations[?serviceAccount=='clickhouse']"
```

## 2. Spoke side — pods running and holding S3 credentials

Switch to the spoke:

```bash
task k8s:kubeconfig CLUSTER=per-en1-dev-clickhouse

# CHI reconciled, and the pods scheduled across two zones
kubectl -n clickhouse get chi dev
kubectl -n clickhouse get pods -l clickhouse.altinity.com/chi=dev \
  -o custom-columns=NAME:.metadata.name,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone,STATUS:.status.phase
kubectl -n clickhouse get pvc
```

`kubectl get chi dev` should reach `status ... Completed` and two pods —
`chi-dev-default-0-0-0` and `chi-dev-default-0-1-0` — should be `Running` in
different zones (plus the three `chk-keeper-*` pods from the baseline).

Confirm Pod Identity actually injected credentials (this is what
`use_environment_credentials` reads):

```bash
kubectl -n clickhouse exec chi-dev-default-0-0-0 -c clickhouse -- \
  sh -c 'echo $AWS_CONTAINER_CREDENTIALS_FULL_URI'
# non-empty => the association is live
```

## 3. End-to-end — write, replicate, and land in S3

Create a replicated table on the cluster (`default`), insert on replica 0, read
it back from replica 1. The default storage policy is `s3_main`, so the parts
go to S3.

```bash
CH() { kubectl -n clickhouse exec -i "$1" -c clickhouse -- clickhouse-client "${@:2}"; }

# Create on both replicas at once
CH chi-dev-default-0-0-0 -q "
  CREATE TABLE IF NOT EXISTS default.verify ON CLUSTER default (
    id UInt64, at DateTime DEFAULT now()
  ) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{cluster}/{shard}/verify', '{replica}')
  ORDER BY id;"

# Insert on replica 0
CH chi-dev-default-0-0-0 -q "INSERT INTO default.verify (id) SELECT number FROM numbers(1000);"

# Read from replica 1 — replication worked if this prints 1000
CH chi-dev-default-0-1-0 -q "SELECT count() FROM default.verify;"

# Confirm the storage policy really is S3, and parts live on the s3 disk
CH chi-dev-default-0-0-0 -q "
  SELECT name, disk_name, storage_policy
  FROM system.parts WHERE table='verify' AND active FORMAT PrettyCompact;"
```

Then confirm the objects exist in the bucket (back on the hub kubeconfig or any
shell with AWS creds):

```bash
aws s3 ls s3://per-en1-dev-clickhouse-data/clickhouse/ --recursive | head
```

Non-empty output under the `clickhouse/` prefix = ClickHouse is writing to S3
with its Pod Identity role.

## 4. Clean up the probe

```bash
CH chi-dev-default-0-0-0 -q "DROP TABLE default.verify ON CLUSTER default SYNC;"
```

## Troubleshooting

- **Pods `CrashLoopBackOff` early on.** Expected while the association is still
  reconciling. Check `aws eks list-pod-identity-associations` (§1); once the
  status is `ACTIVE`, `kubectl -n clickhouse rollout restart sts -l
  clickhouse.altinity.com/chi=dev` and they recover (the one-restart caveat from
  ADR-0013).
- **S3 403 / `no credentials`.** The pod is on the wrong service account or the
  association isn't active. Verify `kubectl -n clickhouse get pod
  chi-dev-default-0-0-0 -o jsonpath='{.spec.serviceAccountName}'` prints
  `clickhouse`, and re-check §2's env probe.
- **`CreateBucket` failing on the hub.** The global S3 name is taken — see
  ADR-0015; append a suffix to the bucket name in `s3-bucket.yaml`, the CHI
  endpoint, and the role's resource ARNs.
- **Replica count stuck below 2 / pods `Pending`.** `minDomains: 2` needs two
  AZs available; check `kubectl -n clickhouse describe pod` for the topology
  spread message and that Karpenter provisioned nodes in two zones.
