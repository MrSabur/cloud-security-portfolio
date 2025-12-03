# ADR-003: Data Protection and Tokenization

## Status
Accepted

## Context

NovaPay processes credit card transactions for merchants. Card data (PAN, expiry, CVV) is the most sensitive data in the system. PCI-DSS has strict requirements for protecting cardholder data.

Current state problems:
- Card numbers stored encrypted in PostgreSQL, but multiple services can decrypt
- Card numbers logged in application logs (discovered during security review)
- Developers can query production database and see card data
- No data classification—all data treated the same

PCI-DSS Data Protection Requirements:
- **3.1:** Keep cardholder data storage to a minimum
- **3.2:** Do not store sensitive authentication data after authorization (CVV)
- **3.4:** Render PAN unreadable anywhere it is stored
- **3.5:** Protect keys used to secure cardholder data
- **3.6:** Fully document key management procedures

### The Goal: Minimize Exposure

Every system that touches card data is in PCI scope. The solution: make sure almost nothing touches card data.
```
Before tokenization:
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ API GW   │→ │ Merchant │→ │ Payment  │→ │ Database │
│          │  │ Service  │  │ Service  │  │          │
│ CARD     │  │ CARD     │  │ CARD     │  │ CARD     │
│ IN SCOPE │  │ IN SCOPE │  │ IN SCOPE │  │ IN SCOPE │
└──────────┘  └──────────┘  └──────────┘  └──────────┘

After tokenization:
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ API GW   │→ │Tokenizer │→ │ Merchant │→ │ Payment  │
│          │  │          │  │ Service  │  │ Service  │
│ CARD     │  │ CARD     │  │ TOKEN    │  │ CARD     │
│ IN SCOPE │  │ IN SCOPE │  │ OUT      │  │ IN SCOPE │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
                              │
                              └── 50% of services now out of scope
```

## Decision

### Implement Tokenization at Point of Entry

Card numbers are tokenized immediately upon receipt. The token replaces the card number for all downstream processing.
```
┌─────────────────────────────────────────────────────────────────┐
│                    TOKENIZATION FLOW                            │
│                                                                 │
│  Merchant Request                                               │
│  ────────────────                                               │
│  POST /v1/payments                                              │
│  {                                                              │
│    "card_number": "4111111111111111",                          │
│    "exp_month": 12,                                             │
│    "exp_year": 2027,                                            │
│    "cvv": "123",                                                │
│    "amount": 5000                                               │
│  }                                                              │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              TOKENIZATION SERVICE                        │   │
│  │                                                          │   │
│  │  1. Validate card (Luhn algorithm)                      │   │
│  │  2. Generate token: tok_live_a8b7c6d5e4                 │   │
│  │  3. Encrypt PAN with KMS (AES-256-GCM)                  │   │
│  │  4. Store: token → encrypted_pan + metadata             │   │
│  │  5. Hash CVV for verification (never stored)            │   │
│  │  6. Return token to caller                              │   │
│  │                                                          │   │
│  │  CVV is used once for initial verification,             │   │
│  │  then IMMEDIATELY discarded (PCI 3.2)                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│       │                                                         │
│       ▼                                                         │
│  Response to Merchant Service                                   │
│  ────────────────────────────                                   │
│  {                                                              │
│    "payment_token": "tok_live_a8b7c6d5e4",                     │
│    "card_brand": "visa",                                        │
│    "last_four": "1111",                                         │
│    "amount": 5000                                               │
│  }                                                              │
│                                                                 │
│  Note: last_four is safe to return (not considered PAN)        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Token Format

Tokens are designed to be:
- Clearly identifiable (prefix)
- Environment-aware (live vs test)
- Random (no relationship to card)
- URL-safe (no special characters)
```
tok_live_a8b7c6d5e4f3g2h1
│   │    │
│   │    └── Random alphanumeric (16 chars)
│   └─────── Environment (live/test)
└─────────── Prefix (identifies as token)
```

**Why prefixes matter:**
- Developers immediately know it's a token, not a card number
- Log scanning can detect accidental card number exposure
- Test tokens can't be used in production (different prefix)

### Card Vault Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                       CARD VAULT                                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  PostgreSQL (RDS)                        │   │
│  │                                                          │   │
│  │  Table: card_tokens                                      │   │
│  │  ┌─────────────────────────────────────────────────────┐│   │
│  │  │ token (PK)          │ tok_live_a8b7c6d5e4           ││   │
│  │  │ encrypted_pan       │ AQICAHh...== (KMS encrypted)  ││   │
│  │  │ key_id              │ alias/card-encryption-key     ││   │
│  │  │ card_brand          │ visa                          ││   │
│  │  │ last_four           │ 1111                          ││   │
│  │  │ exp_month           │ 12 (encrypted)                ││   │
│  │  │ exp_year            │ 2027 (encrypted)              ││   │
│  │  │ fingerprint         │ fp_xyz... (for dedup)         ││   │
│  │  │ created_at          │ 2024-12-03T10:00:00Z          ││   │
│  │  │ merchant_id         │ mer_abc123                    ││   │
│  │  └─────────────────────────────────────────────────────┘│   │
│  │                                                          │   │
│  │  Encryption: Column-level (PAN, exp) not full-disk      │   │
│  │  Access: Tokenization + Payment services ONLY           │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    AWS KMS                               │   │
│  │                                                          │   │
│  │  Key: alias/card-encryption-key                         │   │
│  │  Type: Symmetric (AES-256-GCM)                          │   │
│  │  Rotation: Automatic annual                             │   │
│  │  Policy: Only tokenization-role can encrypt/decrypt     │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### KMS Key Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowTokenizationService",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/tokenization-service-role"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "rds.us-east-1.amazonaws.com"
        }
      }
    },
    {
      "Sid": "AllowPaymentService",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/payment-service-role"
      },
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyAllOthers",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "kms:*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalArn": [
            "arn:aws:iam::123456789012:role/tokenization-service-role",
            "arn:aws:iam::123456789012:role/payment-service-role",
            "arn:aws:iam::123456789012:root"
          ]
        }
      }
    }
  ]
}
```

**Key controls:**
- Only tokenization service can encrypt (create new tokens)
- Only tokenization + payment services can decrypt
- Explicit deny for all other principals
- ViaService condition ensures key only used through RDS

### Card Fingerprinting (Deduplication)

When the same card is tokenized twice, we want to recognize it without storing the actual number:
```
Card: 4111-1111-1111-1111
               │
               ▼
Fingerprint: SHA-256(card_number + merchant_id + salt)
               │
               ▼
Result: fp_a1b2c3d4e5f6...

Same card + same merchant = same fingerprint
Same card + different merchant = different fingerprint (privacy)
```

**Why fingerprint?**
- Detect duplicate charges (fraud prevention)
- Allow "use saved card" without storing card number
- Merchant A can't see if customer uses same card at Merchant B

### CVV Handling: Never Store
```
┌─────────────────────────────────────────────────────────────────┐
│                    CVV LIFECYCLE                                │
│                                                                 │
│  1. CVV received: "123"                                        │
│                                                                 │
│  2. Immediate validation with card network                     │
│     POST to Visa/Mastercard: Verify CVV matches card           │
│                                                                 │
│  3. Result stored: cvv_verified = true                         │
│                                                                 │
│  4. CVV discarded (zeroed from memory)                         │
│                                                                 │
│  ⚠️  CVV NEVER written to:                                     │
│     • Database                                                  │
│     • Logs                                                      │
│     • Cache                                                     │
│     • Disk                                                      │
│                                                                 │
│  PCI-DSS 3.2: "Do not store sensitive authentication data      │
│               after authorization"                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Data Classification

| Data Element | Classification | Storage | Encryption | Retention |
|--------------|----------------|---------|------------|-----------|
| Full PAN | Restricted | Vault only | KMS (AES-256) | Until expiry + 7 years |
| Last 4 digits | Internal | Application DB | At rest (RDS) | Transaction lifetime |
| Expiry date | Restricted | Vault only | KMS (AES-256) | Until expiry + 7 years |
| CVV | Prohibited | NEVER stored | N/A | Seconds (memory only) |
| Token | Internal | Application DB | At rest (RDS) | Transaction lifetime |
| Fingerprint | Internal | Vault | At rest | Card lifetime |
| Card brand | Public | Application DB | At rest | Transaction lifetime |

### Detokenization: Controlled Access
```
┌─────────────────────────────────────────────────────────────────┐
│                  DETOKENIZATION FLOW                            │
│                                                                 │
│  Payment Service needs actual card number to charge             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                PAYMENT SERVICE                           │   │
│  │                                                          │   │
│  │  Request:                                                │   │
│  │  POST /internal/detokenize                               │   │
│  │  {                                                       │   │
│  │    "token": "tok_live_a8b7c6d5e4",                      │   │
│  │    "purpose": "charge",                                  │   │
│  │    "amount": 5000,                                       │   │
│  │    "request_id": "req_xyz789"                           │   │
│  │  }                                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│       │                                                         │
│       │ mTLS (mutual TLS - both sides authenticate)            │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              TOKENIZATION SERVICE                        │   │
│  │                                                          │   │
│  │  1. Verify caller identity (mTLS certificate)           │   │
│  │  2. Check caller is in allowed list                     │   │
│  │  3. Log detokenization request (audit trail)            │   │
│  │  4. Lookup token in vault                               │   │
│  │  5. Decrypt PAN with KMS                                │   │
│  │  6. Return card data (over mTLS only)                   │   │
│  │  7. Log success (without card data)                     │   │
│  │                                                          │   │
│  │  Response:                                               │   │
│  │  {                                                       │   │
│  │    "card_number": "4111111111111111",                   │   │
│  │    "exp_month": 12,                                      │   │
│  │    "exp_year": 2027                                      │   │
│  │  }                                                       │   │
│  │                                                          │   │
│  │  ⚠️  Card number returned ONLY over mTLS                │   │
│  │  ⚠️  Response NEVER logged                              │   │
│  │  ⚠️  Only payment service can detokenize                │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Consequences

### Positive

- **80% PCI scope reduction:** Only tokenization + payment services handle card data
- **Defense in depth:** Token + encryption + network isolation
- **Audit trail:** Every tokenization and detokenization logged
- **Breach impact reduced:** Stolen tokens are worthless
- **Developer safety:** Developers can't accidentally see card numbers

### Negative

- **Latency:** Tokenization adds ~10-20ms per transaction
- **Complexity:** Two-phase flow (tokenize, then process)
- **Single point of failure:** Tokenization service must be highly available
- **Key management:** KMS key rotation requires planning

### Cost

| Component | Monthly Cost |
|-----------|--------------|
| KMS key | $1 |
| KMS API calls (~1M/month) | $3 |
| RDS storage for vault | ~$20 |
| **Total** | **~$25/month** |

## Alternatives Considered

### Alternative 1: Encryption Only (No Tokenization)

**Rejected because:**
- Encrypted card numbers are still in PCI scope
- Any service with decrypt access has full card data
- Key compromise exposes all cards

### Alternative 2: Third-Party Tokenization (Stripe, Braintree)

**Considered for future:**
- Offloads PCI scope entirely
- Higher per-transaction cost
- Less control over data
- Viable if NovaPay pivots to non-payment core business

### Alternative 3: Hardware Security Module (HSM)

**Deferred:**
- CloudHSM costs ~$1,500/month
- KMS provides sufficient security for current scale
- Will implement HSM at $100M+ monthly volume

## PCI-DSS Compliance Mapping

| Requirement | Implementation |
|-------------|----------------|
| 3.1 - Minimize CHD storage | Tokenization replaces CHD in most systems |
| 3.2 - No SAD after auth | CVV never stored, verified and discarded |
| 3.3 - Mask PAN when displayed | Only last_four available to applications |
| 3.4 - Render PAN unreadable | KMS encryption (AES-256-GCM) |
| 3.5 - Protect encryption keys | KMS with strict key policy |
| 3.6 - Key management procedures | Automatic annual rotation |
| 3.7 - Security policies | Documented in this ADR |

## Implementation Notes

### Luhn Validation (Card Number Check)

Before tokenizing, validate the card number format:
```python
def luhn_check(card_number: str) -> bool:
    """Validate card number using Luhn algorithm."""
    digits = [int(d) for d in card_number if d.isdigit()]
    odd_digits = digits[-1::-2]
    even_digits = digits[-2::-2]
    
    total = sum(odd_digits)
    for digit in even_digits:
        doubled = digit * 2
        total += doubled if doubled < 10 else doubled - 9
    
    return total % 10 == 0
```

### Token Generation
```python
import secrets

def generate_token(environment: str = "live") -> str:
    """Generate a cryptographically random token."""
    random_part = secrets.token_hex(8)  # 16 characters
    return f"tok_{environment}_{random_part}"
```

## References

- [PCI-DSS Tokenization Guidelines](https://www.pcisecuritystandards.org/documents/Tokenization_Guidelines_Info_Supplement.pdf)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [Stripe's Tokenization Approach](https://stripe.com/docs/security)