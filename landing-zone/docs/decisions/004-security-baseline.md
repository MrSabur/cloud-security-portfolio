# ADR-004: Security Baseline Architecture

## Status
Accepted

## Context

MedFlow processes Protected Health Information (PHI) for 50,000+ patients and must achieve HIPAA compliance certification within 6 months. The CISO identified three unanswered questions:

1. **Threat Detection:** How do we know if someone is attacking our systems?
2. **Compliance Monitoring:** How do we prove our configurations meet security standards?
3. **Audit Trail:** Where is the complete record of who did what, when?

Current state: No centralized security tooling. Logs are scattered. Compliance is checked manually (if at all). Incident detection relies on users reporting issues.

We need automated, centralized security controls that satisfy HIPAA requirements and provide continuous visibility.

## Decision

### Implement Four Core Security Services

Deploy AWS-native security services in the Security account, aggregating findings from all accounts:
```
┌─────────────────────────────────────────────────────────────────────┐
│                        SECURITY ACCOUNT                             │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │ CloudTrail  │  │ AWS Config  │  │  GuardDuty  │  │Security Hub│ │
│  │             │  │             │  │             │  │            │ │
│  │ "Who did    │  │ "Is config  │  │ "Is someone │  │ "Show me   │ │
│  │  what?"     │  │  compliant?"│  │  attacking?"│  │ everything"│ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘ │
│         │                │                │                │        │
│         ▼                ▼                ▼                ▼        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Centralized Dashboard                     │   │
│  │              (Security Hub aggregates all findings)          │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Service Selection Rationale

| Service | Question Answered | HIPAA Requirement | Alternative Considered |
|---------|-------------------|-------------------|----------------------|
| CloudTrail | Who performed what API call? | §164.312(b) Audit controls | Splunk (cost prohibitive) |
| GuardDuty | Is malicious activity occurring? | §164.308(a)(6) Security incidents | Third-party SIEM (complexity) |
| AWS Config | Are resources configured correctly? | §164.308(a)(8) Evaluation | Manual audits (doesn't scale) |
| Security Hub | What's our overall posture? | §164.308(a)(1) Risk analysis | Custom dashboards (maintenance) |

### CloudTrail Configuration
```hcl
is_multi_region_trail         = true   # Capture API calls in all regions
include_global_service_events = true   # IAM, CloudFront, Route53
enable_log_file_validation    = true   # Tamper-evident hash chain
```

**Log file validation:** Creates SHA-256 hash chain. If any log is modified or deleted, the chain breaks—providing cryptographic proof of tampering. Required for HIPAA audit defensibility.

**Storage:** S3 bucket with:
- Versioning enabled (cannot permanently delete)
- Encryption at rest (AES-256)
- Public access blocked
- Lifecycle policy: Standard → Standard-IA (90 days) → Glacier (365 days) → Expire (2555 days)

### Retention Decision: 7 Years

HIPAA requires covered entities to retain documentation for **6 years from creation or last effective date**. We chose 7 years (2555 days) to provide margin for:

- Audit timing variations
- Legal discovery requests
- Investigation lookback requirements

**Cost implication:** Glacier storage costs ~$0.004/GB/month. A 7-year archive of ~100GB costs ~$34 total—negligible compared to compliance risk.

### GuardDuty Configuration

Enable all protection features:

| Feature | Purpose |
|---------|---------|
| S3 Protection | Detect suspicious access patterns to S3 buckets |
| EKS Audit Logs | Monitor Kubernetes control plane (future) |
| EBS Malware Protection | Scan volumes attached to compromised instances |
| RDS Login Events | Detect brute force or suspicious database access |
| Lambda Network Logs | Identify compromised functions calling malicious endpoints |

**Finding frequency:** 15 minutes (fastest available). Healthcare requires rapid detection—a ransomware attack can encrypt systems in under an hour.

### AWS Config Rules

Deploy managed rules mapping to HIPAA controls:

| Rule | HIPAA Mapping | What It Checks |
|------|---------------|----------------|
| `S3_BUCKET_PUBLIC_READ_PROHIBITED` | §164.312(e)(1) | No public S3 buckets |
| `S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED` | §164.312(a)(2)(iv) | S3 encryption at rest |
| `ENCRYPTED_VOLUMES` | §164.312(a)(2)(iv) | EBS encryption at rest |
| `RDS_STORAGE_ENCRYPTED` | §164.312(a)(2)(iv) | RDS encryption at rest |
| `RDS_INSTANCE_PUBLIC_ACCESS_CHECK` | §164.312(e)(1) | No public RDS instances |
| `ROOT_ACCOUNT_MFA_ENABLED` | §164.312(d) | Root account protected |
| `IAM_USER_MFA_ENABLED` | §164.312(d) | IAM users have MFA |
| `VPC_FLOW_LOGS_ENABLED` | §164.312(b) | Network traffic logged |

### Security Hub Standards

Enable three compliance frameworks:

1. **AWS Foundational Security Best Practices** — AWS-recommended controls
2. **CIS AWS Foundations Benchmark v1.4** — Industry standard hardening
3. **NIST 800-53 Rev 5** — Federal security controls (maps closely to HIPAA)

Security Hub automatically checks resources against these standards and generates findings for violations.

### Centralized vs. Distributed

**Decision:** Security tooling centralized in Security account; member accounts have local detectors that report to central aggregator.

**Rationale:**
- Security team has single pane of glass
- Workload account admins cannot disable or tamper with security logging
- Audit evidence is in account that workload teams cannot access
- Cost allocation is clearer (security spend in one account)

## Consequences

### Positive

- **HIPAA audit-ready:** Can demonstrate controls for §164.308, §164.312
- **Continuous compliance:** Config rules check 24/7, not just during audits
- **Rapid detection:** GuardDuty findings in 15 minutes vs. days/weeks for manual detection
- **Tamper-evident:** CloudTrail log validation proves integrity
- **Centralized visibility:** Security Hub aggregates all findings in one dashboard
- **AWS-native:** No third-party agents, no additional infrastructure

### Negative

- **Cost:** ~$50-150/month depending on resource count and events
- **Alert fatigue risk:** Must tune findings to avoid noise
- **AWS lock-in:** Services are AWS-specific (acceptable given AWS commitment)

### Cost Analysis

| Service | Estimated Monthly Cost |
|---------|----------------------|
| CloudTrail | Free (first trail) + ~$5 S3 |
| GuardDuty | ~$30-50 (based on events) |
| AWS Config | ~$20-30 (based on rules/resources) |
| Security Hub | ~$10 (first 10K findings free) |
| **Total** | **~$70-100/month** |

**vs. Risk:** Single HIPAA breach: $100K-$1.5M in fines + notification costs + reputation damage. Security baseline is insurance.

## Alternatives Considered

### Alternative 1: Third-Party SIEM (Splunk, Datadog)

**Rejected because:**
- Significantly higher cost ($500-2000+/month)
- Additional infrastructure to manage
- Data egress charges for shipping logs
- AWS-native services integrate better with AWS resources

**When to reconsider:** If MedFlow grows to multi-cloud or needs advanced correlation/SOAR capabilities.

### Alternative 2: Manual Compliance Audits

**Rejected because:**
- Point-in-time snapshots miss configuration drift
- Doesn't scale with resource growth
- Cannot detect threats in real-time
- Auditor costs exceed tooling costs

### Alternative 3: Open Source Stack (OSSEC, Wazuh)

**Rejected because:**
- Operational overhead to deploy and maintain
- Requires dedicated security engineering resources
- No native AWS integration for Config-style compliance checking
- Support burden falls on internal team

## HIPAA Compliance Mapping

| HIPAA Section | Requirement | Implementation |
|---------------|-------------|----------------|
| §164.308(a)(1)(i) | Risk analysis | Security Hub compliance dashboard |
| §164.308(a)(1)(ii)(D) | Information system activity review | CloudTrail + GuardDuty |
| §164.308(a)(5)(ii)(C) | Log-in monitoring | GuardDuty console login findings |
| §164.308(a)(6)(ii) | Response and reporting | GuardDuty → Security Hub → SNS alerts |
| §164.308(a)(8) | Evaluation | AWS Config continuous compliance |
| §164.312(a)(2)(iv) | Encryption | Config rules for encryption at rest |
| §164.312(b) | Audit controls | CloudTrail with log validation |
| §164.312(d) | Authentication | Config rules for MFA |
| §164.312(e)(1) | Transmission security | Config rules for public access |

## Operational Procedures

### Daily
- Review Security Hub dashboard for critical/high findings
- Triage new GuardDuty findings

### Weekly
- Review Config compliance percentage
- Address non-compliant resources

### Monthly
- Review CloudTrail for anomalous API patterns
- Update Config rules if new resource types deployed
- Review and tune GuardDuty finding thresholds

### Incident Response
1. GuardDuty finding triggers SNS notification
2. Security team triages finding severity
3. CloudTrail provides forensic evidence (who, what, when)
4. Config shows current and historical resource state
5. Document incident per HIPAA §164.308(a)(6)

## References

- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [AWS CloudTrail Documentation](https://docs.aws.amazon.com/cloudtrail/)
- [AWS GuardDuty Documentation](https://docs.aws.amazon.com/guardduty/)
- [AWS Config Documentation](https://docs.aws.amazon.com/config/)
- [AWS Security Hub Documentation](https://docs.aws.amazon.com/securityhub/)
- [NIST 800-53 Control Mappings](https://docs.aws.amazon.com/audit-manager/latest/userguide/NIST800-53r5.html)