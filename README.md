# hello-ecs-service-connect

Demo app of using ECS Service Connect on Fargate

- redis container/service - integrated as a server/client in Service Connect
- counter container/service - a demo app which connects to redis via Service Connect
  using internal `redis:6379` lookup (no load balancer)

## EC2 notes

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