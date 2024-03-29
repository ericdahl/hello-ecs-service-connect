# hello-ecs-service-connect

Demo app of using ECS Service Connect on Fargate

- redis container/service - integrated as a server/client in Service Connect
- counter container/service - a demo app which connects to redis via Service Connect
  using internal `redis:6379` lookup (no load balancer)

# Quick Start

Note: the "counter" web service doesn't use an ALB for simplicity/costs, so we'll directly
connect to the public IP of the ENIs

```
$ terraform apply

# either check AWS Console, or wait 3 minutes and run apply again, to query the IPs
$ terraform apply
...
Outputs:

counter_eni = [
  "54.167.248.26",
  "54.210.124.236",
  "54.164.101.118",
]

$ curl http://54.167.248.26:8080 ; echo
Hello from ip-10-0-0-73.ec2.internal (count is 8)

$ curl http://54.210.124.236:8080 ; echo
Hello from ip-10-0-0-121.ec2.internal (count is 9)

$ curl http://54.164.101.118:8080 ; echo
Hello from ip-10-0-0-44.ec2.internal (count is 10)
```


## EC2 notes

See branch `ec2`, converts from fargate

- app task has 3 containers:
  1. application container itself
    - uses network of container:pause (nothing in bridge network)
  2. ecs-service-connect-agent:interface-v1 container
     - /var/run/ecs/relay mount
     - Runs command `/usr/bin/envoy -c /tmp/envoy-config-554676961.yaml -l info --concurrency 2 --drain-time-s 20`
     - APPNET_AGENT_ADMIN_UDS_PATH=${APPNET_AGENT_ADMIN_UDS_PATH:-/var/run/ecs/appnet_admin.sock}
  3. amazon/amazon-ecs-pause:0.1.0 container
    - memory: 0 / cpu_shares: 2
    - uses a None network

### Network Flow

- Client hello-ecs `IP 10.0.0.124.37748 > 10.0.0.71.6379`
  - container f44a34d49ff0
  - task 62d171763ab948e7944dfd8d28915ad3
  - task IP  10.0.0.124
- Client Proxy
  - 127.0.0.1.33136
- Server redis 
  - container 9d1725aaf4c6
  - task bcb73ca91bb24101994f4f0b2a0c8bf2
  - task IP `10.0.0.71`

#### Simpler Flow

- Client (counter)
  - Task `bfb026242fa44d449dd3ada391542029`
    - Private IP `10.0.0.177`  (`eni-0956e45909ba07928`)
      - Containers
        - `00c22f22c6a2` - app
          - uses NetworkMode: `container:254ae45343f9` (pause container)
          - outgoing connection to `redis` goes to `127.255.0.2` (/etc/hosts)
            - ```
              bash-4.2# cat /etc/hosts
              127.0.0.1	localhost
              ::1	localhost ip6-localhost ip6-loopback
              fe00::0	ip6-localnet
              ff00::0	ip6-mcastprefix
              ff02::1	ip6-allnodes
              ff02::2	ip6-allrouters
              10.0.0.177	ip-10-0-0-177.ec2.internal
              127.255.0.1	counter
              2600:f0f0:0:0:0:0:0:1	counter
              127.255.0.2	redis
              2600:f0f0:0:0:0:0:0:2	redis
              ```
        - iptables inside of container, redir to port 34365 (envoy)
          ```
          nsenter --net -t 10711 iptables-save
          # Generated by iptables-save v1.8.4 on Sun Apr 16 18:52:29 2023
          *nat
          :PREROUTING ACCEPT [0:0]
          :INPUT ACCEPT [114803:6888180]
          :OUTPUT ACCEPT [2033:122735]
          :POSTROUTING ACCEPT [3984:239795]
          :ECS_SERVICE_CONNECT_INGRESS - [0:0]
          -A PREROUTING -p tcp -m addrtype ! --src-type LOCAL -j ECS_SERVICE_CONNECT_INGRESS
          -A OUTPUT -d 127.255.0.0/16 -p tcp -j REDIRECT --to-ports 34365
          -A ECS_SERVICE_CONNECT_INGRESS -p tcp -m tcp --dport 8080 -j REDIRECT --to-ports 39566
          COMMIT
          # Completed on Sun Apr 16 18:52:29 2023
          ```
          - netstat listening ports in this namespace
          ```
          [root@ip-10-0-0-44 ~]# nsenter --net -t 10711 netstat -anlp | grep LISTEN
          tcp        0      0 0.0.0.0:39566           0.0.0.0:*               LISTEN      10152/envoy         
          tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      10711/java          
          tcp        0      0 127.0.0.1:34365         0.0.0.0:*               LISTEN      10152/envoy         
          tcp6       0      0 :::39566                :::*                    LISTEN      10152/envoy
          ```
        - 5e05c7038479 - ecs-connect-interface
          - uses NetworkMode: none (null network)
        - `254ae45343f9` - ecs-connect-pause
          - uses NetworkMode: none (null network)
- Server (redis)
  - Task `079d834355314a3eae5ce58804da7adb`
    - Private IP `10.0.0.231` (`eni-00f8a22f3fd27cffc`)
    - Containers
      - `d77e693dbeec` - app
        - `/etc/hosts` only has redis (no client)
          - ??
      - `37b2e7b4a686` - ecs-connect-interface
      - `f02bdf8b3fff` - ecs-connect-pause
- "Hidden" relay
  - Task `service-connect-relay-bd03af74-dc7f-11ed-95fc-0ea8a5673e0f` (non-standard)
    - Containers
      - `e6be397e7753` - ecs-connect-interface

### Envoy Config

```
cat /tmp/envoy-config-554676961.yaml
admin:
  accessLog:
  - typedConfig:
      '@type': type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
      path: /tmp/envoy_admin_access.log
  address:
    pipe:
      mode: 384
      path: /tmp/envoy_admin.sock
clusterManager:
  outlierDetection:
    eventLogPath: /dev/stdout
dynamicResources:
  adsConfig:
    apiType: GRPC
    grpcServices:
    - googleGrpc:
        channelArgs:
          args:
            grpc.http2.max_pings_without_data:
              intValue: "0"
            grpc.keepalive_time_ms:
              intValue: "10000"
            grpc.keepalive_timeout_ms:
              intValue: "20000"
        statPrefix: ads
        targetUri: unix:///var/run/ecs/relay/envoy_xds.sock
    transportApiVersion: V3
  cdsConfig:
    ads: {}
    initialFetchTimeout: 0s
    resourceApiVersion: V3
  ldsConfig:
    ads: {}
    initialFetchTimeout: 0s
    resourceApiVersion: V3
layeredRuntime:
  layers:
  - name: static_layer_0
    staticLayer:
      envoy.features.enable_all_deprecated_features: true
      envoy.reloadable_features.http_set_tracing_decision_in_request_id: true
      envoy.reloadable_features.no_extension_lookup_by_name: true
      envoy.reloadable_features.tcp_pool_idle_timeout: true
      re2.max_program_size.error_level: 1000
  - adminLayer: {}
    name: admin_layer
node:
  cluster: arn:aws:ecs:us-east-1:ACCOUNT_ID:task-set/hello-ecs-service-connect/counter/ecs-svc/3760500105188579977
  id: arn:aws:ecs:us-east-1:ACCOUNT_ID:task-set/hello-ecs-service-connect/counter/ecs-svc/3760500105188579977
  metadata:
    aws.appmesh.metric_filter:
      level: "1"
    aws.appmesh.platformInfo:
      AvailabilityZone: us-east-1a
      ecsPlatformInfo:
        CPU: "2"
        Memory: "0"
        ecsClusterArn: hello-ecs-service-connect
        ecsContainerInstanceArn: arn:aws:ecs:us-east-1:ACCOUNT_ID:container-instance/hello-ecs-service-connect/97011e38d0fc4d8290a4d9c493e8edde
        ecsLaunchType: AWS_ECS_EC2
        ecsTaskArn: arn:aws:ecs:us-east-1:ACCOUNT_ID:task/hello-ecs-service-connect/39ddaf309a0641dfb623ae5385ad1800
      supportedIPFamilies: IPv4_ONLY
      systemInfo:
        systemKernelVersion: 4.14.309-231.529.amzn2.x86_64
        systemPlatform: x86_64
    aws.appmesh.task.interfaces:
      ipv4:
        ecs-eth0:
        - 169.254.172.2/22
        eth0:
        - 10.0.0.141/24
        lo:
        - 127.0.0.1/8
    aws.ecs.serviceconnect.ListenerPortMapping:
      egress: 42304
      ingress-counter: 33914
statsConfig:
  statsTags:
  - regex: ^appmesh(?:\..+?\..+?)*(\.ServiceName\.(.+?))(?:\..+?\..+?)*\.(?:.+)$
    tagName: ServiceName
  - regex: ^appmesh(?:\..+?\..+?)*(\.ClusterName\.(.+?))(?:\..+?\..+?)*\.(?:.+)$
    tagName: ClusterName
  - regex: ^appmesh(?:\..+?\..+?)*(\.Direction\.(.+?))(?:\..+?\..+?)*\.(?:.+)$
    tagName: Direction
  - regex: ^appmesh(?:\..+?\..+?)*(\.DiscoveryName\.((?:(?!\.(ClusterName|ServiceName|Direction)).)+))(?:\..+?\..+?)*\.(?:.+)$
    tagName: DiscoveryName
  - regex: ^appmesh(?:\..+?\..+?)*(\.TargetDiscoveryName\.((?:(?!\.(ClusterName|ServiceName|Direction)).)+))(?:\..+?\..+?)*\.(?:.+)$
    tagName: TargetDiscoveryName
```

## TODO

- trace through DNS flow for Service Connect
- swap with normal network mode for comparison