# Network Firewall Architecture

## Updated Architecture (Network Firewall in Public Subnets)

```
                                           VPC
+----------------+     +----------------------------------------------------------+
|                |     |  +----------------+                                      |
|                |     |  | Public Subnet  |                                      |
|                |     |  | (Firewall)     |                                      |
|                |     |  +--------+-------+                                      |
|                |     |           |                                              |
|                |     |           v                                              |
|                |     |  +--------+-------+     +----------------+               |
|                |     |  | Public Subnet  |     | Private Subnet |               |
| Internet       +-----+->| (ALB)          +---->| (ECS Tasks)    |               |
|                |     |  |                |     |                |               |
|                |     |  +----------------+     +----------------+               |
|                |     |                                                          |
+----------------+     +----------------------------------------------------------+

Traffic Flow:
1. Internet -> Internet Gateway
2. Internet Gateway -> Network Firewall (in public subnet)
3. Network Firewall -> ALB (in public subnet)
4. ALB -> ECS Tasks (in private subnet)
```

## Previous Architecture (Network Firewall in Private Subnets)

```
                                           VPC
+----------------+     +----------------------------------------------------------+
|                |     |  +----------------+     +----------------+               |
|                |     |  | Public Subnet  |     | Private Subnet |               |
|                |     |  | (ALB)          +---->| (Firewall)     |               |
|                |     |  |                |     |                |               |
|                |     |  +----------------+     +------+---------+               |
|                |     |                                |                         |
| Internet       +-----+->                              v                         |
|                |     |                         +------+---------+               |
|                |     |                         | Private Subnet |               |
|                |     |                         | (ECS Tasks)    |               |
|                |     |                         |                |               |
+----------------+     |                         +----------------+               |
                       +----------------------------------------------------------+

Traffic Flow:
1. Internet -> Internet Gateway
2. Internet Gateway -> ALB (in public subnet)
3. ALB -> Network Firewall (in private subnet)
4. Network Firewall -> ECS Tasks (in private subnet)
```

## Benefits of the New Architecture

1. **Improved Security**: All traffic from the internet is inspected by the Network Firewall before reaching any application components.
2. **Simplified Routing**: More straightforward traffic flow with the firewall at the edge.
3. **Better Protection**: ALB is now protected by the firewall, reducing the attack surface.
4. **Enhanced Visibility**: All traffic entering the VPC is inspected, providing better visibility into potential threats. 