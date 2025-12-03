# ADR-004: API Security

## Status
Accepted

## Context

NovaPay exposes REST APIs for merchants to process payments. These APIs are the primary attack surface—every endpoint is accessible from the internet, handling sensitive financial data at machine speed.

Current state problems:
- No Web Application Firewall (WAF)
- Rate limiting implemented inconsistently across services
- API keys are long-lived (never expire)
- No request signing (keys can be replayed if intercepted)
- Error messages leak internal details (stack traces, database errors)

PCI-DSS API Security Requirements:
- **6.4:** Protect web-facing applications against attacks
- **6.5:** Address common coding vulnerabilities
- **8.3:** Secure API authentication
- **10.2:** Log all access to cardholder data

### Threat Model for Payment APIs

| Threat              | Impact                    | Likelihood |
|---------------------|---------------------------|------------|
| Credential stuffing | Unauthorized transactions | High |
| API key theft       | Full account takeover     | Medium |
| Injection attacks   | Data breach, system compromise | Medium |
| DDoS                | Service unavailability    | High |
| Enumeration         | Customer data exposure    | Medium |
| Man-in-the-middle   | Transaction interception  | Low (TLS mitigates) |

## Decision

### Defense in Depth: Four Layers
```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 1: AWS WAF                             │
│                                                                 │
│  • AWS Managed Rules (SQLi, XSS, known bad inputs)            │
│  • IP reputation filtering                                      │
│  • Geo-blocking (if required)                                  │
│  • Request size limits                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 2: API GATEWAY                         │
│                                                                 │
│  • TLS 1.2+ termination                                        │
│  • Request validation (schema enforcement)                      │
│  • Rate limiting (per API key)                                 │
│  • Usage plans and throttling                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   LAYER 3: AUTHENTICATION                       │
│                                                                 │
│  • API key validation                                          │
│  • Key scope verification                                       │
│  • Request signing (HMAC) for sensitive operations             │
│  • Idempotency key validation                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   LAYER 4: APPLICATION                          │
│                                                                 │
│  • Input validation and sanitization                           │
│  • Output encoding                                              │
│  • Error handling (no information leakage)                     │
│  • Audit logging                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 1: AWS WAF Configuration
```hcl
resource "aws_wafv2_web_acl" "api" {
  name        = "novapay-api-waf"
  description = "WAF for NovaPay payment APIs"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rule: Common attacks (SQLi, XSS, etc.)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: Known bad inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action { none {} }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: SQL injection protection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3
    override_action { none {} }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting: Block IPs with > 2000 requests in 5 minutes
  rule {
    name     = "RateLimitRule"
    priority = 4
    action { block {} }
    
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # Block requests > 8KB (payment requests should be small)
  rule {
    name     = "SizeRestrictionRule"
    priority = 5
    action { block {} }
    
    statement {
      size_constraint_statement {
        field_to_match {
          body {}
        }
        comparison_operator = "GT"
        size                = 8192
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SizeRestrictionMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "NovapayAPIWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Environment = "production"
    PCI_Scope   = "true"
  }
}
```

### Layer 2: API Gateway with Rate Limiting
```hcl
resource "aws_api_gateway_rest_api" "payments" {
  name        = "novapay-payments-api"
  description = "NovaPay Payment Processing API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Usage plan for rate limiting
resource "aws_api_gateway_usage_plan" "standard" {
  name        = "standard-plan"
  description = "Standard merchant rate limits"

  api_stages {
    api_id = aws_api_gateway_rest_api.payments.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  # Rate limits
  throttle_settings {
    burst_limit = 100   # Max concurrent requests
    rate_limit  = 1000  # Requests per second
  }

  # Monthly quota
  quota_settings {
    limit  = 1000000  # 1M requests/month
    period = "MONTH"
  }
}

# Enterprise plan with higher limits
resource "aws_api_gateway_usage_plan" "enterprise" {
  name        = "enterprise-plan"
  description = "Enterprise merchant rate limits"

  api_stages {
    api_id = aws_api_gateway_rest_api.payments.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  throttle_settings {
    burst_limit = 500
    rate_limit  = 5000
  }

  quota_settings {
    limit  = 10000000  # 10M requests/month
    period = "MONTH"
  }
}
```

### Layer 3: API Key Authentication with Scoping
```
┌─────────────────────────────────────────────────────────────────┐
│                    API KEY STRUCTURE                            │
│                                                                 │
│  Key Format: sk_live_abc123def456...                           │
│              │  │    │                                          │
│              │  │    └── Random (32 chars)                     │
│              │  └─────── Environment (live/test)               │
│              └────────── Type (sk=secret, pk=publishable)      │
│                                                                 │
│  Database Record:                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ key_hash      │ SHA256(sk_live_abc123...)               │   │
│  │ merchant_id   │ mer_xyz789                              │   │
│  │ environment   │ live                                     │   │
│  │ scopes        │ ["payments:write", "refunds:write"]     │   │
│  │ rate_limit    │ 1000                                     │   │
│  │ ip_whitelist  │ ["203.0.113.0/24"]                      │   │
│  │ created_at    │ 2024-01-15T10:00:00Z                    │   │
│  │ last_used_at  │ 2024-12-03T14:30:00Z                    │   │
│  │ expires_at    │ 2025-01-15T10:00:00Z (optional)         │   │
│  │ status        │ active                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ⚠️  Key itself is NEVER stored—only the hash                  │
│  ⚠️  If merchant loses key, they must generate a new one       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Scope Enforcement:**

| Scope            | Allows |
|------------------|--------|
| `payments:write` | Create charges |
| `payments:read` | View charge status |
| `refunds:write` | Create refunds |
| `refunds:read` | View refund status |
| `customers:write` | Create/update customers |
| `customers:read` | View customer data |
```python
# Scope validation middleware
def require_scope(required_scope: str):
    def decorator(func):
        def wrapper(request, *args, **kwargs):
            api_key = request.headers.get("Authorization")
            key_record = validate_api_key(api_key)
            
            if required_scope not in key_record.scopes:
                raise ForbiddenError(
                    code="insufficient_scope",
                    message=f"This action requires the '{required_scope}' scope"
                )
            
            return func(request, *args, **kwargs)
        return wrapper
    return decorator

@require_scope("payments:write")
def create_charge(request):
    # Process payment
    pass
```

### Request Signing for Sensitive Operations

For high-risk operations (large refunds, account changes), require HMAC signature:
```
┌─────────────────────────────────────────────────────────────────┐
│                    REQUEST SIGNING                              │
│                                                                 │
│  Merchant Request:                                              │
│  ─────────────────                                              │
│  POST /v1/refunds                                               │
│  Authorization: Bearer sk_live_abc123...                        │
│  X-Request-Timestamp: 1701619800                               │
│  X-Request-Signature: sha256=a1b2c3d4...                       │
│                                                                 │
│  {                                                              │
│    "charge_id": "ch_xyz789",                                   │
│    "amount": 50000,                                             │
│    "reason": "customer_request"                                 │
│  }                                                              │
│                                                                 │
│  Signature Calculation:                                         │
│  ──────────────────────                                         │
│  payload = timestamp + "." + request_body                       │
│  signature = HMAC-SHA256(payload, webhook_secret)               │
│                                                                 │
│  Server Validation:                                             │
│  ──────────────────                                             │
│  1. Check timestamp is within 5 minutes (replay protection)    │
│  2. Recalculate signature with stored webhook_secret           │
│  3. Compare signatures (constant-time comparison)              │
│  4. If mismatch → reject with 401                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Idempotency Keys

Payment APIs must handle retries safely. Double-charging is unacceptable.
```
┌─────────────────────────────────────────────────────────────────┐
│                    IDEMPOTENCY                                  │
│                                                                 │
│  Request 1:                                                     │
│  POST /v1/charges                                               │
│  Idempotency-Key: idem_abc123                                  │
│  { "amount": 5000, "card": "tok_xyz" }                         │
│                                                                 │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Server checks: Is idem_abc123 in cache/database?         │   │
│  │                                                          │   │
│  │ NO → Process payment, store result with key              │   │
│  │      Return: { "id": "ch_new123", "status": "succeeded" }│   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Request 2 (retry, same key):                                  │
│  POST /v1/charges                                               │
│  Idempotency-Key: idem_abc123                                  │
│  { "amount": 5000, "card": "tok_xyz" }                         │
│                                                                 │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Server checks: Is idem_abc123 in cache/database?         │   │
│  │                                                          │   │
│  │ YES → Return cached result (NO new charge)               │   │
│  │       Return: { "id": "ch_new123", "status": "succeeded" }│   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ⚠️  Same key + same request = same response (no side effects) │
│  ⚠️  Same key + different request = 409 Conflict error         │
│  ⚠️  Keys expire after 24 hours                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 4: Application Security

**Error Handling: No Information Leakage**
```python
# BAD: Leaks internal details
{
  "error": "psycopg2.errors.UniqueViolation: duplicate key value violates unique constraint \"cards_pkey\"\nDETAIL: Key (card_id)=(card_123) already exists.\n at /app/services/cards.py:147"
}

# GOOD: Safe error response
{
  "error": {
    "type": "invalid_request_error",
    "code": "card_already_exists",
    "message": "A card with this token already exists.",
    "request_id": "req_abc123"  # For support lookup
  }
}
```

**Input Validation:**
```python
from pydantic import BaseModel, validator, constr
from decimal import Decimal

class ChargeRequest(BaseModel):
    amount: int  # In cents, no decimals
    currency: constr(min_length=3, max_length=3, regex="^[A-Z]{3}$")
    payment_token: constr(regex="^tok_(live|test)_[a-zA-Z0-9]{16}$")
    description: constr(max_length=500) = None
    idempotency_key: constr(min_length=10, max_length=64)
    
    @validator('amount')
    def amount_must_be_positive(cls, v):
        if v <= 0:
            raise ValueError('Amount must be positive')
        if v > 99999999:  # $999,999.99 max
            raise ValueError('Amount exceeds maximum')
        return v
    
    @validator('currency')
    def currency_must_be_supported(cls, v):
        supported = ['USD', 'EUR', 'GBP', 'CAD']
        if v not in supported:
            raise ValueError(f'Currency must be one of: {supported}')
        return v
```

### Audit Logging

Every API request is logged (without sensitive data):
```json
{
  "timestamp": "2024-12-03T14:30:00.123Z",
  "request_id": "req_abc123",
  "merchant_id": "mer_xyz789",
  "api_key_id": "key_def456",
  "method": "POST",
  "path": "/v1/charges",
  "ip_address": "203.0.113.50",
  "user_agent": "NovaPay-Python/1.0",
  "request_body_size": 256,
  "response_status": 200,
  "response_time_ms": 145,
  "idempotency_key": "idem_abc123",
  "charge_id": "ch_new123",
  "amount": 5000,
  "currency": "USD",
  
  "NEVER_LOGGED": ["card_number", "cvv", "api_key_secret"]
}
```

## Consequences

### Positive

- **Defense in depth:** Four layers, each stopping different attacks
- **PCI-DSS 6.x compliant:** WAF, input validation, secure error handling
- **Abuse resistant:** Rate limiting prevents DDoS and enumeration
- **Audit trail:** Every request logged for forensics
- **Replay protection:** Request signing + idempotency

### Negative

- **Latency:** Each layer adds ~5-10ms
- **Complexity:** Multiple systems to monitor and maintain
- **False positives:** WAF rules may block legitimate requests (requires tuning)

### Cost

| Component | Monthly Cost |
|-----------|--------------|
| AWS WAF | ~$25 + $1/million requests |
| API Gateway | ~$3.50/million requests |
| CloudWatch Logs | ~$10 (depends on volume) |
| **Total** | **~$50-150/month** |

## Alternatives Considered

### Alternative 1: Self-Managed WAF (ModSecurity)

**Rejected because:**
- Operational overhead to maintain and tune rules
- No automatic updates for new attack patterns
- AWS WAF integrates natively with ALB/API Gateway

### Alternative 2: Third-Party API Gateway (Kong, Apigee)

**Considered for future:**
- More features (advanced analytics, developer portal)
- Higher cost and operational complexity
- AWS API Gateway sufficient for current scale

### Alternative 3: API Keys Only (No Request Signing)

**Rejected because:**
- Intercepted keys can be replayed
- No protection against MITM adding extra refunds
- High-value operations need additional verification

## PCI-DSS Compliance Mapping

| Requirement | Implementation |
|-------------|----------------|
| 6.4.1 - WAF for public-facing apps | AWS WAF with managed rule sets |
| 6.4.2 - Review WAF rules | Quarterly rule review process |
| 6.5.1 - Injection flaws | WAF SQLi rules + input validation |
| 6.5.4 - Insecure direct object references | Scope-based authorization |
| 6.5.7 - XSS | WAF XSS rules + output encoding |
| 6.5.10 - Broken auth | API key validation + signing |
| 8.3.1 - Unique authentication | Per-merchant API keys |
| 10.2.1 - Log user access | Request logging with merchant ID |
| 10.2.2 - Log actions by admins | All API actions logged |

## References

- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [AWS WAF Documentation](https://docs.aws.amazon.com/waf/)
- [Stripe API Design](https://stripe.com/docs/api)
- [PCI-DSS v4.0 Requirement 6](https://www.pcisecuritystandards.org/)