# hello-ecs-service-connect

Demo app of using ECS Service Connect on Fargate

- redis container/service - integrated as a server/client in Service Connect
- counter container/service - a demo app which connects to redis via Service Connect
  using internal `redis:6379` lookup (no load balancer)

## TODO

- seems to randomly not work. Timing issues or DNS caching?