# ADR-001: Identity and Access Strategy

## Status
Accepted

## Context

NovaPay is a payment processing platform with three categories of identities:

1. **Human users:** Engineers, support staff, executives
2. **Services:** Internal microservices communicating with each other
3. **External clients:** Merchants calling NovaPay APIs

Each category has different authentication needs, risk profiles, and compliance requirements.

Current state problems:
- Shared admin account used by multiple engineers
- Long-lived API keys stored in environment variables
- No service-to-service authentication (network location = trust)
- SSH access to production servers for debugging

PCI-DSS Requirements:
- **7.1:** Limit access to system components to only those individuals whose job requires access
- **8.2:** Use unique IDs for all users
- **8.3:** Secure all individual non-console administrative access with MFA
- **8.6:** Authentication mechanisms must not be shared

## Decision

### Human Identity: IAM Identity Center (SSO)
```
┌─────────────────────────────────────────────────────────────────┐
│                    IAM Identity Center                          │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ Engineering │  │  Support    │  │       Finance           │ │
│  │   Group     │  │   Group     │  │        Group            │ │
│  │             │  │             │  │                         │ │
│  │ • Dev access│  │ • Read-only │  │ • Billing only          │ │
│  │ • No prod   │  │ • Logs      │  │ • No technical          │ │
│  │   CDE       │  │ • Metrics   │  │   access                │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                                                                 │
│  MFA Required │ 12-hour session │ No persistent credentials    │
└─────────────────────────────────────────────────────────────────┘
```

**Key controls:**
- No IAM users with long-term credentials
- All human access via SSO with MFA
- Role assumption for cross-account access
- 12-hour maximum session duration
- Permission sets aligned to job function

### Service Identity: IAM Roles with IRSA/ECS Task Roles

Services authenticate using IAM roles, not credentials.
```
┌─────────────────────────────────────────────────────────────────┐
│                    Payment Service (ECS)                        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Task Role                             │   │
│  │                                                          │   │
│  │  Permissions:                                            │   │
│  │  • secrets:GetSecretValue (payment-processor/*)          │   │
│  │  • kms:Decrypt (payment-key)                             │   │
│  │  • sqs:SendMessage (payment-queue)                       │   │
│  │                                                          │   │
│  │  NO:                                                     │   │
│  │  • S3 access                                             │   │
│  │  • EC2 access                                            │   │
│  │  • IAM access                                            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Credentials: Automatic rotation │ 6-hour expiry               │
└─────────────────────────────────────────────────────────────────┘
```

**Key controls:**
- No hardcoded credentials in code or environment variables
- Credentials automatically rotated by AWS
- Least-privilege: each service only gets permissions it needs
- Service identities are auditable (CloudTrail shows which role did what)

### External Client Identity: API Keys with Scoping

Merchants authenticate via API keys with explicit scoping.
```
┌─────────────────────────────────────────────────────────────────┐
│                    API Key Structure                            │
│                                                                 │
│  Key: sk_live_abc123...                                        │
│                                                                 │
│  Metadata:                                                      │
│  ├── merchant_id: mer_xyz789                                   │
│  ├── environment: production                                    │
│  ├── scopes: [payments:write, refunds:write, customers:read]   │
│  ├── rate_limit: 1000/minute                                   │
│  ├── ip_whitelist: [203.0.113.0/24]                            │
│  └── created_at: 2024-01-15                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key controls:**
- API keys are scoped to specific permissions (not full access)
- Keys can be restricted by IP range
- Per-key rate limiting prevents abuse
- Key rotation without downtime (multiple active keys)
- Separate keys for test vs production

### Eliminating SSH Access

**Problem:** Engineers SSH into production to debug issues. This bypasses all access controls.

**Solution:** AWS Systems Manager Session Manager
```
┌─────────────────────────────────────────────────────────────────┐
│                    Before: SSH Access                           │
│                                                                 │
│  Engineer → SSH (port 22) → Production Server                  │
│                                                                 │
│  Problems:                                                      │
│  • Requires key management                                      │
│  • No audit trail of commands                                   │
│  • Firewall hole (port 22 open)                                │
│  • Shared keys common                                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    After: Session Manager                       │
│                                                                 │
│  Engineer → IAM Auth → Session Manager → Production Server     │
│                                                                 │
│  Benefits:                                                      │
│  • IAM-based access (SSO + MFA)                                │
│  • Full command audit trail in CloudTrail                      │
│  • No inbound ports required                                    │
│  • Session recording available                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Consequences

### Positive

- **PCI-DSS 8.x compliant:** Unique IDs, MFA, no shared accounts
- **Auditable:** Every access logged with identity attached
- **No credential sprawl:** No long-lived credentials to leak
- **Least privilege:** Each identity gets minimum required permissions
- **Breach containment:** Compromised service can't escalate

### Negative

- **Complexity:** IAM roles require careful design
- **Learning curve:** Engineers must understand role assumption
- **SSO dependency:** Identity Center outage = no access

### Cost

- IAM Identity Center: Free (included with AWS Organizations)
- Secrets Manager: $0.40/secret/month
- Session Manager: Free (CloudWatch Logs storage additional)

## Alternatives Considered

### Alternative 1: IAM Users with MFA

**Rejected because:**
- Long-lived credentials can leak
- Key rotation is manual
- Doesn't scale to service identities

### Alternative 2: Third-party Identity Provider (Okta, Auth0)

**Rejected because:**
- Additional cost and vendor dependency
- IAM Identity Center provides sufficient capability
- Can integrate third-party IdP later if needed

### Alternative 3: HashiCorp Vault for Service Identity

**Rejected because:**
- Operational overhead to run Vault
- IAM roles with IRSA/Task Roles provide native solution
- Vault can be added later for advanced use cases (dynamic database credentials)

## PCI-DSS Compliance Mapping

| PCI-DSS Requirement | Implementation |
|---------------------|----------------|
| 7.1 - Limit access to need-to-know | IAM permission sets by job function |
| 7.2 - Access control system | IAM policies with explicit deny |
| 8.1 - Unique user IDs | IAM Identity Center enforces unique IDs |
| 8.2 - Proper authentication | SSO + MFA for all human access |
| 8.3 - MFA for admin access | Enforced at Identity Center level |
| 8.4 - Password policies | Managed by Identity Center |
| 8.5 - No shared/generic accounts | Enforced by policy; shared accounts trigger alert |
| 8.6 - No shared authentication | Each service has unique IAM role |

## References

- [AWS IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/)
- [ECS Task IAM Roles](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)
- [Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [PCI-DSS v4.0 Requirements](https://www.pcisecuritystandards.org/)