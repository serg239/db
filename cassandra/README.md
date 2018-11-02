Examples of cassandra database configuration
--------------------------------------------
1. SaltStack pillar, files, and states (including orchestration states) to configure cassandra database cluster.
> Usage:
> $ salt-run state.orchestrate -l debug orch.stack saltenv=cassandra

2. Cassandra use cases:
- Preconditions for all Cassandra VM Images
- Initial deployment of a Cassandra Cluster
- Shutting down the Cassandra Cluster
- Deployment of a Single Seed Node to existing Cassandra Cluster
- Deployment of a Single Regular Node to an existing Cassandra Cluster
- Shutdown of a Single Seed Node of an Existing Cassandra Cluster
- Shutdown of a Single Regular Node of an existing Cassandra Cluster
- Replacing a Single Dead Node of an existing Cassandra Cluster
- Replacing a Single Running Node of an existing Cassandra Cluster
- Deployment of a Cassandra Cluster to be a backup of an Operational Cluster (mirror)
