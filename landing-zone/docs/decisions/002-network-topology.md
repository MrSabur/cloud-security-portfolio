# ADR-002: Network Topology

## Status
Accepted

## Context

Following ADR-001, MedFlow's AWS environment will span five accounts:
- Management (Organization root)
- Security (logging, threat detection)
- Shared Services (networking hub, CI/CD)
- Workloads-Dev (development/test)
- Workloads-Prod (production)

These accounts are isolated by default. We need a network architecture that enables:
1. Controlled connectivity between accounts (e.g., workloads → shared services)
2. Hard isolation where required (prod ↔ dev must never communicate)
3. Centralized egress for cost efficiency and monitoring
4. Auditability of all network traffic for HIPAA compliance
5. Defense in depth with multiple security layers

## Decision

### Transit Gateway Hub-and-Spoke

Implement AWS Transit Gateway as the central network hub with route table-based isolation.
```
                    ┌─────────────────────────────┐
                    │       Transit Gateway       │
                    │                             │
                    │  ┌───────────┬───────────┐  │
                    │  │  Prod RT  │   Dev RT  │  │
                    │  └───────────┴───────────┘  │
                    └──────────────┬──────────────┘
           ┌───────────┬──────────┴─────┬───────────┐
           ▼           ▼                ▼           ▼
      Security    Shared Svcs     Workloads    Workloads
        VPC          VPC          Dev VPC      Prod VPC
```

**Route table isolation:**
- Prod RT: Routes to Security, Shared Services, and egress. No route to Dev.
- Dev RT: Routes to Security, Shared Services, and egress. No route to Prod.

### VPC CIDR Allocation

| Account | VPC Name | CIDR | Notes |
|---------|----------|------|-------|
| Security | security-vpc | 10.0.0.0/16 | Log archive, GuardDuty |
| Shared Services | shared-vpc | 10.1.0.0/16 | Transit Gateway hub, NAT, DNS |
| Workloads-Dev | dev-vpc | 10.10.0.0/16 | All dev/test workloads |
| Workloads-Prod | prod-vpc | 10.20.0.0/16 | Production workloads |

### Three-Tier Subnet Architecture

Each workload VPC uses three tiers across two availability zones:

| Tier | Subnets | Purpose | Internet Access |
|------|---------|---------|-----------------|
| Public | 10.x.0.0/24, 10.x.1.0/24 | ALB, NAT Gateway | Inbound via IGW (ALB only) |
| Private | 10.x.10.0/24, 10.x.11.0/24 | Application servers | Outbound via NAT |
| Data | 10.x.20.0/24, 10.x.21.0/24 | RDS, ElastiCache | None |

### Centralized Egress

All internet-bound traffic routes through NAT Gateway in Shared Services VPC:
```
Workload VPC → Transit Gateway → Shared Services VPC → NAT Gateway → Internet
```

Benefits:
- Cost reduction: 1 NAT Gateway pair vs. 4
- Centralized monitoring and filtering
- Single point for future egress firewall

### Security Groups Pattern

Security groups reference other security groups, not CIDR blocks:
```
Internet → [ALB SG: 443] → [App SG: 8080 from ALB SG] → [Data SG: 5432 from App SG]
```

### VPC Flow Logs

All VPCs send flow logs to centralized S3 bucket in Security account:
- Format: Parquet (cost-efficient, queryable via Athena)
- Retention: 365 days (HIPAA requirement)
- Fields: All available fields including traffic path

## Consequences

### Positive
- **Hard isolation**: Prod and Dev cannot communicate at the network layer
- **Cost efficiency**: Centralized NAT reduces monthly costs by ~$100
- **Auditability**: All traffic logged to immutable Security account
- **Scalability**: Adding VPCs requires only new TGW attachment + route
- **Defense in depth**: Network isolation + security groups + NACLs available

### Negative
- **Transit Gateway cost**: ~$36/month per attachment ($144/month for 4 VPCs)
- **Egress latency**: Additional hop through Shared Services (~1ms)
- **Complexity**: Cross-account networking requires careful route management

### Neutral
- **Data transfer costs**: $0.02/GB through Transit Gateway (same as NAT Gateway processing)

## Alternatives Considered

### VPC Peering
Rejected: Does not scale beyond 5-10 VPCs; no transitive routing; management overhead of n² connections.

### AWS PrivateLink Only
Rejected: Suitable for service-to-service, not general network connectivity; would require endpoint per service.

### NAT Gateway per VPC
Rejected: Higher cost ($128/month vs. ~$64/month); distributed monitoring complexity.

## Compliance Mapping

| Requirement | Implementation |
|-------------|----------------|
| HIPAA §164.312(e)(1) - Transmission security | TLS enforced at ALB; data tier has no internet route |
| HIPAA §164.312(b) - Audit controls | VPC Flow Logs retained 365 days in Security account |
| NIST PR.AC-5 - Network integrity | Transit Gateway route tables enforce segmentation |
| NIST PR.DS-5 - Data leak protection | Egress centralized; can add filtering |

## References

- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [AWS Network Architecture Guide](https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/welcome.html)
