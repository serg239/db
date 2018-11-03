Examples of cassandra database configuration
--------------------------------------------
1. SaltStack pillar, files, and states (including orchestration states) to configure cassandra database cluster.

Usage:
> $ salt-run state.orchestrate -l debug orch.stack saltenv=cassandra

2. Cassandra use cases:
[00](use_cases/00.txt) Preconditions for all Cassandra Images
[01](use_cases/01.txt) Initial deployment of a Cassandra Cluster
[02](use_cases/02.txt) Shutting down the Cassandra Cluster
[03](use_cases/03.txt) Deployment of a Single Seed Node to existing Cassandra Cluster
[04](use_cases/04.txt) Deployment of a Single Regular Node to an existing Cassandra Cluster
[05](use_cases/05.txt) Shutdown of a Single Seed Node of an Existing Cassandra Cluster
[06](use_cases/06.txt) Shutdown of a Single Regular Node of an existing Cassandra Cluster
[07](use_cases/07.txt) Replacing a Single Dead Node of an existing Cassandra Cluster
[08](use_cases/08.txt) Replacing a Single Running Node of an existing Cassandra Cluster
[09](use_cases/09.txt) Deployment of a Cassandra Cluster to be a backup of an Operational Cluster (mirror)
