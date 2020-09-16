# Backup OCP

`backup_all.yaml` should work, provided your user, and inventory is configured to sudo most all things on all nodes.

`backup_all.sh` demonstrates my use of aliasing for ansible commands to speed up operation from both a dedicated and shared controller node.

I run ansible-playbook `backup_all.yaml`.

## Backup format
Successful `backup_all.yaml` will result in following structure.

Control plane nodes will have most backups, with the first control plane having api `objects` as well.
Other control plane nodes will only have `etcds`, `controlplane`, `nodes`.
All compute nodes (including infra nodes) will have `nodes`.
```
/home/user/backupOCP/controlplane-host-0.foo.com
└── backupOCP
    └── 2020-09-15
        ├── etcds
        │   └── etcd.tgz
        ├── controlplane
        │   └── controlplane.tgz
        ├── nodes
        │   └── node.tgz
        └── objects
            └── objects.tgz
/home/user/backupOCP/app-node.foo.com
└── backupOCP
    └── 2020-09-15
        └── nodes
            └── node.tgz
```
