# ADR-001: Multi-Account Strategy

## Status
Accepted

## Context

MedFlow is a healthcare startup processing PHI (Protected Health Information) for 50,000+ patients across 12 regional clinics. The company has grown from 10 to 50 employees in 18 months, and the AWS environment has not kept pace with security requirements.

Current state:
- Single AWS account containing all environments (dev, staging, prod)
- Shared IAM credentials among multiple team members
- No separation between security tooling and application workloads
- Recent incident: accidental deletion of production S3 bucket (9-hour recovery)
- Upcoming requirement: HIPAA compliance certification within 6 months

The organization needs a multi-account structure that provides:
1. Blast radius containment (dev mistakes don't affect prod)
2. Clear security boundaries for HIPAA compliance
3. Separation of duties (security team vs. development team)
4. Cost visibility per environment/team
5. Scalability for 5-8 applications without excessive account sprawl

## Decision

Implement AWS Organizations with the following account structure:
```
Organization Root (Management Account)
│
├── Security OU
│   └── security-prod
│       - CloudTrail (organization trail)
│       - GuardDuty (delegated administrator)
│       - Security Hub (aggregated findings)
│       - Config (aggregated rules)
│       - Log Archive (S3 buckets for all audit logs)
│
├── Infrastructure OU
│   └── shared-services-prod
│       - Transit Gateway (network hub)
│       - Route 53 (centralized DNS)
│       - GitHub Actions runners (CI/CD)
│       - Bastion/Session Manager infrastructure
│
└── Workloads OU
    ├── Dev OU
    │   └── workloads-dev
    │       - All development environments
    │       - All test/staging environments
    │       - Developer sandboxes (tagged, time-limited)
    │
    └── Prod OU
        └── workloads-prod
            - Production applications only
            - Stricter change management
            - Enhanced monitoring
```

### Service Control Policies

| SCP Name | Attached To | Effect |
|----------|-------------|--------|
| DenyLeaveOrganization | Root | Prevents any account from leaving the organization |
| DenyRootUserAccess | All OUs except Management | Blocks root user for all actions except billing |
| RequireIMDSv2 | Workloads OU | Requires EC2 Instance Metadata Service v2 |
| DenyPublicS3 | Workloads OU | Prevents creation of public S3 buckets |
| RestrictRegions | All OUs | Limits deployment to us-east-1 and us-west-2 |
| ProtectSecurityResources | Security OU | Prevents deletion of CloudTrail, GuardDuty, Config |

### Cross-Account Access Pattern

- No IAM users with long-term credentials
- All human access via IAM Identity Center (SSO)
- Workload accounts assume roles in other accounts via trust policies
- Security account has read-only access to all accounts for audit purposes

## Consequences

### Positive
- **Blast radius containment**: Incidents in workloads-dev cannot affect workloads-prod
- **HIPAA alignment**: Clear boundaries satisfy audit requirements for access controls and separation of duties
- **Cost visibility**: AWS Cost Explorer can report per-account spending
- **Scalable foundation**: Structure supports growth to 20+ applications without redesign
- **Credential isolation**: Compromised credentials in one account cannot access others

### Negative
- **Operational complexity**: Teams must understand cross-account access patterns
- **Initial setup effort**: ~2 weeks to implement Organization, accounts, and SCPs
- **Networking complexity**: Transit Gateway required for cross-account communication

### Neutral
- **Account count**: 5 accounts is manageable; revisit if exceeding 10 applications
- **Cost**: AWS Organizations and accounts are free; only resources incur charges

## Alternatives Considered

### Alternative 1: Single Account with Strict IAM
- **Rejected because**: IAM policies cannot fully contain blast radius; resource tags can be modified; auditors prefer account-level separation for HIPAA

### Alternative 2: Account per Application per Environment
- **Rejected because**: Would result in 16+ accounts for 8 applications; excessive overhead for current team size; revisit at 50+ applications

### Alternative 3: Separate Staging Account
- **Rejected because**: Current team size (50) doesn't require dedicated QA environment isolation; can be added later if needed

## Compliance Mapping

| HIPAA Requirement | How This Decision Addresses It |
|-------------------|-------------------------------|
| Access Controls (§164.312(a)(1)) | Account boundaries enforce access separation; SCPs prevent privilege escalation |
| Audit Controls (§164.312(b)) | Centralized logging in Security account; immutable via SCP |
| Person or Entity Authentication (§164.312(d)) | IAM Identity Center with MFA; no shared credentials |

| NIST CSF Control | How This Decision Addresses It |
|------------------|-------------------------------|
| PR.AC-4 (Access permissions managed) | Account-level boundaries + IAM + SCPs |
| PR.DS-1 (Data-at-rest protected) | Can enforce encryption via SCPs |
| DE.CM-7 (Monitoring for unauthorized activity) | GuardDuty aggregated to Security account |

## References

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [AWS Security Reference Architecture](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/welcome.html)
- [HIPAA on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)
