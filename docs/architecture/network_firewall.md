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
4. ALB -> Network Firewall -> ECS Tasks (in private subnet)
5. ECS Tasks -> Network Firewall -> ALB (for return traffic)
6. ALB -> Network Firewall -> Internet Gateway -> Internet (for return traffic)
```

## Routing Tables Configuration

### Edge Route Table (Internet Gateway)
- Routes traffic to public subnets through Network Firewall endpoints
- Routes traffic to private subnets through Network Firewall endpoints
- Uses specific subnet routes rather than VPC-wide routes to avoid conflicts with AWS default local routes

### Public Subnet Route Tables
- Routes to private subnets go through Network Firewall
- Default route (0.0.0.0/0) goes through Network Firewall

### Firewall Subnet Route Tables
- Default route (0.0.0.0/0) goes directly to Internet Gateway

### Private Subnet Route Tables
- Routes to public subnets go through Network Firewall
- Default route (0.0.0.0/0) goes through Network Firewall

This configuration ensures:
1. All incoming traffic is inspected by the Network Firewall before reaching ALB
2. All traffic between ALB and ECS tasks is inspected by the Network Firewall
3. All outgoing traffic is inspected by the Network Firewall before leaving the VPC

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