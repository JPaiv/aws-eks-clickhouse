# null-label components for every stack of the ACK admin cluster:
# per-en1-admin-ack. Defined once at the directory level so the network and
# eks stacks can never disagree on the cluster name.

globals {
  stage = "admin"
  name  = "ack"
}
