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

## TODO

- seems to randomly not work. Timing issues or DNS caching?