# API Gateway Module

REST API Gateway with WAF, rate limiting, and comprehensive logging.

## Features

- AWS WAF with managed rule sets (SQLi, XSS, known bad inputs)
- IP-based rate limiting
- Request size restrictions
- Usage plans for throttling (standard and enterprise tiers)
- Access logging with custom format
- X-Ray tracing enabled

## Security Controls
```
Internet → WAF → API Gateway → Backend
              │
              ├── SQLi protection
              ├── XSS protection
              ├── Rate limiting
              ├── Size restrictions
              └── Request logging
```

## Usage
```hcl
module "api_gateway" {
  source = "../../modules/api-gateway"

  name        = "novapay"
  environment = "production"
  description = "NovaPay Payment Processing API"

  # WAF configuration
  enable_waf     = true
  waf_rate_limit = 2000  # Per 5 minutes per IP
  waf_block_mode = true

  # Throttling
  throttle_burst_limit = 100
  throttle_rate_limit  = 1000
  quota_limit          = 1000000  # Monthly

  # Logging
  enable_access_logs = true
  log_retention_days = 365
}
```

## PCI-DSS Compliance

| Requirement | Implementation |
|-------------|----------------|
| 6.4.1 - WAF protection | AWS managed rules |
| 6.5.1 - Injection flaws | SQLi rule set |
| 6.5.7 - XSS | Common rule set |
| 10.2 - Log access | Access logs with request details |