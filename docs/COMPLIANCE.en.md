# Compliance Guide - ibmi-audit-trail

**[🇫🇷 Version française](COMPLIANCE.md)** | **🇬🇧 English version**

This document explains how to use `ibmi-audit-trail` to meet the requirements of various regulations.

## 📋 Table of Contents

- [GDPR (General Data Protection Regulation)](#gdpr)
- [SOX (Sarbanes-Oxley Act)](#sox)
- [ISO 27001 (Information Security)](#iso-27001)
- [Best Practices](#best-practices)

---

## GDPR

### Article 30: Register of Processing Activities

**Requirement:** Maintain a register of processing activities.

**Solution with ibmi-audit-trail:**
```rpgle
// Enable audit on all tables containing personal data
AuditLog_Init(*ON);

// Audit operations
AuditLog_Insert('CONTACTS' : %addr(contact));
AuditLog_Update('CONTACTS' : %addr(new) : %addr(old));
AuditLog_Delete('CONTACTS' : %addr(contact));
```

**Compliance Report:**
```sql
-- List of operations on personal data
SELECT 
  TABLE_NAME,
  OPERATION,
  USER_NAME,
  TIMESTAMP,
  IP_ADDRESS
FROM AUDITLOG
WHERE TABLE_NAME IN ('CONTACTS', 'CUSTOMERS', 'EMPLOYEES')
ORDER BY TIMESTAMP DESC;
```

---

### Article 17: Right to Erasure

**Requirement:** Ability to delete all data of a person.

**Solution:**
```rpgle
// 1. Log the deletion
AuditLog_Delete('CUSTOMERS' : %addr(customer));

// 2. Perform the deletion
exec sql DELETE FROM CUSTOMERS WHERE ID = :customerId;

// 3. Generate a deletion report
dcl-ds history likeds(AUDIT_HISTORY_T) dim(100);
count = AuditLog_GetHistory('CUSTOMERS' : %char(customerId) : history);

// 4. Keep proof of deletion (legal retention period)
// The audit remains in AUDITLOG with OLD_VALUES
```

---

### Article 33: Breach Notification

**Requirement:** Detect and notify data breaches within 72 hours.

**Solution:**
```sql
-- Detection of suspicious access
SELECT 
  USER_NAME,
  COUNT(*) as NB_ACCESS,
  MIN(TIMESTAMP) as FIRST_ACCESS,
  MAX(TIMESTAMP) as LAST_ACCESS
FROM AUDITLOG
WHERE TABLE_NAME = 'CUSTOMERS'
  AND TIMESTAMP >= CURRENT_TIMESTAMP - 24 HOURS
GROUP BY USER_NAME
HAVING COUNT(*) > 1000;  -- Alert threshold

-- Access outside business hours
SELECT * FROM AUDITLOG
WHERE HOUR(TIMESTAMP) NOT BETWEEN 8 AND 18
  AND DAYOFWEEK(TIMESTAMP) BETWEEN 2 AND 6;
```

---

### Article 35: Data Protection Impact Assessment (DPIA)

**Requirement:** Documentation of high-risk processing.

**Automatic Report:**
```sql
-- Analysis of operations by type
SELECT 
  TABLE_NAME,
  OPERATION,
  COUNT(*) as TOTAL,
  COUNT(DISTINCT USER_NAME) as NB_USERS,
  MIN(TIMESTAMP) as FIRST_OP,
  MAX(TIMESTAMP) as LAST_OP
FROM AUDITLOG
WHERE TIMESTAMP >= CURRENT_DATE - 90 DAYS
GROUP BY TABLE_NAME, OPERATION
ORDER BY TOTAL DESC;
```

---

## SOX

### Section 302: Certification of Financial Reports

**Requirement:** Complete audit trail of financial data.

**Solution:**
```rpgle
// Audit all financial tables
AuditLog_Init(*ON);

// Example: Invoices
AuditLog_Insert('INVOICES' : %addr(invoice));
AuditLog_Update('INVOICES' : %addr(new) : %addr(old));

// Example: Payments
AuditLog_Insert('PAYMENTS' : %addr(payment));
```

**SOX Compliance Report:**
```sql
-- All modifications to financial data
CREATE VIEW SOX_AUDIT_TRAIL AS
SELECT 
  A.ID,
  A.TABLE_NAME,
  A.RECORD_KEY,
  A.OPERATION,
  A.USER_NAME,
  A.TIMESTAMP,
  A.OLD_VALUES,
  A.NEW_VALUES,
  A.PROGRAM_NAME
FROM AUDITLOG A
WHERE A.TABLE_NAME IN (
  'INVOICES', 'PAYMENTS', 'JOURNAL_ENTRIES', 
  'ACCOUNTS', 'TRANSACTIONS'
)
ORDER BY A.TIMESTAMP DESC;
```

---

### Section 404: Internal Controls

**Requirement:** Documentation of controls and changes.

**Segregation of Duties:**
```sql
-- Verify that a user cannot both create AND approve
WITH user_ops AS (
  SELECT 
    RECORD_KEY,
    USER_NAME,
    OPERATION
  FROM AUDITLOG
  WHERE TABLE_NAME = 'INVOICES'
)
SELECT 
  RECORD_KEY,
  STRING_AGG(DISTINCT USER_NAME, ', ') as USERS
FROM user_ops
GROUP BY RECORD_KEY
HAVING COUNT(DISTINCT USER_NAME) = 1;  -- Alert: same user
```

---

### Section 802: Document Retention

**Requirement:** Retain audits for 7 years.

**Configuration:**
```rpgle
dcl-ds config likeds(AUDIT_CONFIG_T);

config.active = *ON;
config.maxRetentionDays = 2555;  // 7 years

AuditLog_SetConfig(config);
```

**Automatic Purge:**
```rpgle
// Monthly purge job
dcl-s deleted int(10);

// Keep only 7 years
deleted = AuditLog_Purge(2555);

dsply ('Purged audits: ' + %char(deleted));
```

---

## ISO 27001

### A.9: Access Control

**Requirement:** Traceability of information access.

**Solution:**
```sql
-- Access report by user
SELECT 
  USER_NAME,
  TABLE_NAME,
  COUNT(*) as NB_ACCESS,
  MIN(TIMESTAMP) as FIRST_ACCESS,
  MAX(TIMESTAMP) as LAST_ACCESS
FROM AUDITLOG
WHERE TIMESTAMP >= CURRENT_DATE - 30 DAYS
GROUP BY USER_NAME, TABLE_NAME
ORDER BY NB_ACCESS DESC;
```

---

### A.12: Operations Security

**Requirement:** Event logging.

**Complete Configuration:**
```rpgle
dcl-ds config likeds(AUDIT_CONFIG_T);

config.active = *ON;
config.captureIP = *ON;      // Trace IP
config.captureJob = *ON;     // Trace job
config.asyncMode = *OFF;     // Synchronous to ensure write

AuditLog_SetConfig(config);
```

---

### A.16: Incident Management

**Requirement:** Investigation capability.

**Incident Investigation:**
```sql
-- Example: Who modified this customer on December 15?
SELECT 
  USER_NAME,
  OPERATION,
  TIMESTAMP,
  IP_ADDRESS,
  JOB_NAME,
  OLD_VALUES,
  NEW_VALUES
FROM AUDITLOG
WHERE TABLE_NAME = 'CUSTOMERS'
  AND RECORD_KEY = '12345'
  AND DATE(TIMESTAMP) = '2025-12-15'
ORDER BY TIMESTAMP;
```

---

## Best Practices

### 1. Selective Activation

```rpgle
// Audit only sensitive tables
dcl-s auditTables varchar(50) dim(10);

auditTables(1) = 'CUSTOMERS';
auditTables(2) = 'INVOICES';
auditTables(3) = 'PAYMENTS';
auditTables(4) = 'EMPLOYEES';
auditTables(5) = 'CONTRACTS';

// Audit only these tables
if %lookup(tableName : auditTables) > 0;
  AuditLog_Insert(tableName : %addr(record));
endif;
```

---

### 2. Regular Reports

**Monthly Report Job:**
```rpgle
// Generate a monthly report for management
dcl-s report varchar(1000);

exec sql 
  SELECT JSON_OBJECT(
    'total_operations': COUNT(*),
    'nb_users': COUNT(DISTINCT USER_NAME),
    'nb_tables': COUNT(DISTINCT TABLE_NAME),
    'period': 'last_30_days'
  )
  INTO :report
  FROM AUDITLOG
  WHERE TIMESTAMP >= CURRENT_DATE - 30 DAYS;

// Send by email or save to IFS
```

---

### 3. Automatic Alerts

```sql
-- Create a view for alerts
CREATE VIEW AUDIT_ALERTS AS
SELECT 
  'VOLUME_ANORMAL' as ALERT_TYPE,
  USER_NAME,
  COUNT(*) as NB_OPERATIONS,
  CURRENT_TIMESTAMP as ALERT_TIME
FROM AUDITLOG
WHERE TIMESTAMP >= CURRENT_TIMESTAMP - 1 HOUR
GROUP BY USER_NAME
HAVING COUNT(*) > 100;  -- Configurable threshold
```

---

### 4. Audit Table Protection

```sql
-- Create a dedicated role for audit
CREATE ROLE AUDIT_ADMIN;

-- Read-only access for others
GRANT SELECT ON AUDITLOG TO PUBLIC;

-- Only AUDIT_ADMIN can modify
GRANT ALL ON AUDITLOG TO AUDIT_ADMIN;
REVOKE DELETE, UPDATE ON AUDITLOG FROM PUBLIC;
```

---

### 5. Long-term Archiving

```rpgle
// Archive audits older than 1 year to an archive table
exec sql 
  INSERT INTO AUDITLOG_ARCHIVE
  SELECT * FROM AUDITLOG
  WHERE TIMESTAMP < CURRENT_DATE - 365 DAYS;

// Then purge the main table
AuditLog_Purge(365);
```

---

## Compliance Checklist

### GDPR
- ✅ Complete traceability of operations (Article 30)
- ✅ Proof of deletion (Article 17)
- ✅ Breach detection (Article 33)
- ✅ DPIA documentation (Article 35)

### SOX
- ✅ Financial audit trail (Section 302)
- ✅ Internal controls (Section 404)
- ✅ 7-year retention (Section 802)

### ISO 27001
- ✅ Access control (A.9)
- ✅ Event logging (A.12)
- ✅ Incident investigation (A.16)

---

## Support

For any questions about compliance, consult:
- [API Documentation](API.en.md)
- [GitHub Issues](https://github.com/IBMiservices/ibmi-audit-trail/issues)
