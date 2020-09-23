## Conventions
`es_util`  and `es_cluster_health` are helper commands inside the ocp-elasticsearch image.
Documentation and Red Hat Support will call out `curl --cert --key --ca ...`, but in most cases you may use `es_util` in its place.

## Utility: es_cluster_health
```
sh-4.2$ es_cluster_health
{
  "cluster_name" : "logging-es",
  "status" : "red",
  "timed_out" : false,
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3,
  "active_primary_shards" : 857,
  "active_shards" : 2571,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 996,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 72.07737594617325
}
```

## Utility: Capture point-in-time snapshot indices, shards, and nodes.
Indended to be single line.
Execute from within an ES container.
```
DATE=$(date +"%Y%m%d-%H%M%S") ; LAST_INDICES=/elasticsearch/persistent/indices.${DATE} ; LAST_SHARDS=/elasticsearch/persistent/shards.${DATE} ;LAST_NODES=/elasticsearch/persistent/nodes.${DATE}; es_util --query='_cat/indices' > $LAST_INDICES && es_util --query='_cat/shards' > $LAST_SHARDS && es_util --query='_cat/nodes?v&h=name,diskUsedPercent,heap.percent,load_1m,load_5m,load_15m,uptime,flushTotalTime,getTime,flushTotalTime,indexingIndexTime,searchQueryTime' > $LAST_NODES
```
### Capture indices
```
es_util --query='_cat/indices'
```
### Capture shards
```
es_util --query='_cat/shards'
```
### Capture nodes info
```
es_util --query='_cat/nodes?v&h=name,diskUsedPercent,heap.percent,load_1m,load_5m,load_15m,uptime,flushTotalTime,getTime,flushTotalTime,indexingIndexTime,searchQueryTime'
```

## Utility: Allocate red indices to ES node
Note: Accepts data loss, meaning the index will start from 0.
If the index is red, check the allocation explain for the reason, but it is likely all data is lost anyway.
There is little reason to distribute primaries[1](https://discuss.elastic.co/t/distributing-primary-shards/67804/2), so pick any master's deploymentconfig name to put as `node` value in the following.

Copied code MUST have backslashes '\\'
```
for i in $( cat $LAST_INDICES | grep "^red" | awk '{print $3}' ) ; do 
es_util --query='_cluster/reroute' -XPOST -d "{
  \"commands\" : [ {
    \"allocate_empty_primary\" :
      {
        \"node\" : \"logging-es-data-master-wxlrmvhd\",
        \"accept_data_loss\" : \"true\",
        \"index\" : \"${i}\",
        \"shard\" : 0
      }
    }
  ]
}"
done
```

## Explain why shards failed to allocate.
Execute from within an ES container.
```
es_util --query='_cluster/allocation/explain?pretty'
```
### Example: cluster allocation explain
```
sh-4.2$ es_util --query='_cluster/allocation/explain?pretty'
{
  "index" : "project.bcbsnc-web--ps--pr-797.826c9249-8efb-11ea-af3d-0050569e5fd6.2020.09.09",
  "shard" : 0,
  "primary" : true,
  "current_state" : "unassigned",
  "unassigned_info" : {
    "reason" : "CLUSTER_RECOVERED",
    "at" : "2020-09-11T21:22:33.663Z",
    "last_allocation_status" : "no_valid_shard_copy"
  },
  "can_allocate" : "no_valid_shard_copy",
  "allocate_explanation" : "cannot allocate because a previous copy of the primary shard existed but can no longer be found on the nodes in the cluster",
  "node_allocation_decisions" : [
    {
      "node_id" : "P53x-UeRSgKvDV1nVbPqsg",
      "node_name" : "logging-es-data-master-wxlrmvhd",
      "transport_address" : "10.42.18.79:9300",
      "node_decision" : "no",
      "store" : {
        "found" : false
      }
    },
    {
      "node_id" : "kYcF4wrhSMqJpTXKDm8I_Q",
      "node_name" : "logging-es-data-master-683d5c2c",
      "transport_address" : "10.40.18.35:9300",
      "node_decision" : "no",
      "store" : {
        "found" : false
      }
    },
    {
      "node_id" : "sMFTAjNtRoynj1mQpIjLsA",
      "node_name" : "logging-es-data-master-6hllvehf",
      "transport_address" : "10.41.18.46:9300",
      "node_decision" : "no",
      "store" : {
        "found" : false
      }
    }
  ]
}
```

## Check fluentd buffer buildup on nodes
```
ls /var/lib/fluentd | grep -c buffer-output ; ls /var/lib/fluentd | grep -c es-retry ; ls /var/lib/fluentd | wc -l '
```
## Procedure: Revive blocked fluentds
Fluentd build up buffer and retry files when it is unable to send to elasticsearch.
When fluentds reach max of 33 buffer and 33 retry files, they halt operation.
When they halt for long enough, they will not resume on their own.
Restarting fluentd containers will restore to service.
### Check which nodes have been stalled
When you see three lines as `33 33 66`, fluentd has stalled.
```
ansible nodes -m shell -a 'ls /var/lib/fluentd | grep -c buffer-output ; ls /var/lib/fluentd | grep -c es-retry ; ls /var/lib/fluentd | wc -l'
```
### Oldest and newest of the fluentd buffer files
If you check the timestamps of buffer files, you will likely not see current timestamps.
```
ls -lt /var/lib/fluentd | head ; ls -lt /var/lib/fluentd | tail ; ls /var/lib/fluentd | wc
```
### Stop the running fluentd container
```
docker stop $(docker ps -f label=io.kubernetes.container.name="fluentd-elasticsearch" -q)
```

### Query the fluentd container
```
docker ps -f label=io.kubernetes.container.name="fluentd-elasticsearch"
```

## Procedure: Migrate elasticsearch to larger PV
Perform the data migration in the middle of [full elasticsearch cluster restart](https://docs.openshift.com/container-platform/3.11/install_config/aggregate_logging.html#elasticsearch-full-restart), which gracefully terminates and restores elasticsearch masters.


## Disable cluster routing transiently, prior to shutdown
```
es_util --query='_cluster/settings' -d '{ "transient": { "cluster.routing.allocation.enable" : "none" } }' -XPUT
```

### Create the new PVs of specified size
```
for i in {0..2} ; do 
oc -n openshift-logging create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: logging-es-500gi-${i}
 namespace: openshift-logging
spec:
 accessModes:
  - ReadWriteOnce
 resources:
   requests:
     storage: 500Gi
 storageClassName: san
EOF
done
```

### Scale down es
```
for i in $(oc -n openshift-logging get dc -lcomponent=es -oname ) ; do oc  -n openshift-logging scale --replicas=0 $i ; done
```

### Create pods to copy data
```
for i in {0..2}
do
oc -n openshift-logging create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  generateName: efk-copy-${i}-
  labels:
    job: efk-copy
spec:
  containers:
  - name: pi
    image: rhel7
    command: ["sleep","1d"]
    volumeMounts:
    - mountPath: /old
      name: es-old
    - mountPath: /new
      name: es-new
  restartPolicy: Never
  volumes:
  - name: es-old
    persistentVolumeClaim:
      claimName: logging-es-${i}
  - name: es-new
    persistentVolumeClaim:
      claimName: logging-es-500gi-${i}
EOF
done
```

### Check permissions on the copied data
```
chown 1000110000:1000110000 -R /new/ ; chmod g+w -R /new/
sh-4.2# ls -l /new/
total 20
drwxr-xr-x. 4 root root  4096 Sep 22 23:12 logging-es
drwx------. 2 root root 16384 Sep 22 23:06 lost+found
sh-4.2# ls -l /old/
total 4
drwxrwsr-x. 4 1000110000 1000110000 4096 Sep 16 21:53 logging-es
h-4.2# ls -l /new/logging-es/
total 8
drwxr-xr-x. 3 root root 4096 Sep 22 23:12 data
drwxr-xr-x. 2 root root 4096 Sep 22 23:12 logs
sh-4.2# chown 1000110000:1000110000 -R /new/
sh-4.2# chmod g+w -R /new/
sh-4.2# ls -l /new/logging-es/
total 8
drwxrwxr-x. 3 1000110000 1000110000 4096 Sep 22 23:12 data
drwxrwxr-x. 2 1000110000 1000110000 4096 Sep 22 23:12 logs
```

### Edit ES DCs to change mounted PVC
```
for i in $(oc -n openshift-logging get dc -lcomponent=es -oname ) ; do oc  -n openshift-logging edit $i ; done
/persistentV
```

### Rollout latest ES DC configs.
Note: Does not scale up ES replicas
```
for i in $(oc -n openshift-logging get dc -lcomponent=es -oname ) ; do oc  -n openshift-logging rollout latest $i ; read ; done
```

### Stop copy pods
Volumes are RWO, so k8s will not schedule ES while the volumes are mounted by other pods.
```
[root@vlrhomq101 ~]# oc -n openshift-logging delete po -ljob=efk-copy
pod "efk-copy-0-9qqbc" deleted
pod "efk-copy-1-z9mjf" deleted
pod "efk-copy-2-dm6hw" deleted
```

### Scale up ES nodes
```
for i in $(oc -n openshift-logging get dc -lcomponent=es -oname ) ; do oc  -n openshift-logging scale --replicas=1 $i ; done
```

### Restore service traffic to the ES pods
```
oc -n openshift-logging patch svc/logging-es -p '{"spec":{"selector":{"component":"es","provider":"openshift"}}}'
```