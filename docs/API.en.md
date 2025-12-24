# API Reference - ibmi-audit-trail

**[🇫🇷 Version française](API.md)** | **🇬🇧 English version**

## Table of Contents

- [Initialization](#initialization)
- [Audit Operations](#audit-operations)
- [Consultation](#consultation)
- [Maintenance](#maintenance)
- [Configuration](#configuration)
- [Utilities](#utilities)

---

## Initialization

### `AuditLog_Init(active)`

Initializes and activates/deactivates the audit system.

**Parameters:**
- `active` (ind): `*ON` to activate, `*OFF` to deactivate

**Return:**
- (ind): `*ON` if successful, `*OFF` if error

**Example:**
```rpgle
dcl-s success ind;
success = AuditLog_Init(*ON);
```

---

### `AuditLog_CreateTable()`

Creates the AUDITLOG table and its indexes. This function is idempotent (can be called multiple times).

**Return:**
- (ind): `*ON` if successful, `*OFF` if error

**Example:**
```rpgle
if AuditLog_CreateTable();
  dsply 'Table created successfully';
endif;
```

**Note:** This function should be called only once during initial installation.

---

## Audit Operations

### `AuditLog_Insert(tableName : record)`

Records an INSERT operation in the audit log.

**Parameters:**
- `tableName` (varchar(128)): Table name
- `record` (pointer): Pointer to the record data structure

**Return:**
- (ind): `*ON` if successful, `*OFF` if error

**Example:**
```rpgle
dcl-ds customer likeds(CUSTOMER_T);
customer.id = 12345;
customer.name = 'Acme Corp';

AuditLog_Insert('CUSTOMER' : %addr(customer));
exec sql INSERT INTO CUSTOMER VALUES(:customer);
```

---

### `AuditLog_Update(tableName : newRecord : oldRecord)`

Records an UPDATE operation with values before and after modification.

**Parameters:**
- `tableName` (varchar(128)): Table name
- `newRecord` (pointer): Pointer to the new values
- `oldRecord` (pointer): Pointer to the old values

**Return:**
- (ind): `*ON` if successful, `*OFF` if error

**Example:**
```rpgle
dcl-ds oldCustomer likeds(CUSTOMER_T);
dcl-ds newCustomer likeds(CUSTOMER_T);

exec sql SELECT * INTO :oldCustomer FROM CUSTOMER WHERE ID = :id;
newCustomer = oldCustomer;
newCustomer.email = 'newemail@acme.com';

AuditLog_Update('CUSTOMER' : %addr(newCustomer) : %addr(oldCustomer));
exec sql UPDATE CUSTOMER SET EMAIL = :newCustomer.email WHERE ID = :id;
```

---

### `AuditLog_Delete(tableName : record)`

Records a DELETE operation.

**Parameters:**
- `tableName` (varchar(128)): Table name
- `record` (pointer): Pointer to the deleted record

**Return:**
- (ind): `*ON` if successful, `*OFF` if error

**Example:**
```rpgle
dcl-ds customer likeds(CUSTOMER_T);

exec sql SELECT * INTO :customer FROM CUSTOMER WHERE ID = :id;
AuditLog_Delete('CUSTOMER' : %addr(customer));
exec sql DELETE FROM CUSTOMER WHERE ID = :id;
```

---

## Consultation

### `AuditLog_GetHistory(tableName : recordKey : history)`

Retrieves the complete history of a specific record.

**Parameters:**
- `tableName` (varchar(128)): Table name
- `recordKey` (varchar(1024)): Record key (JSON format for composite keys)
- `history` (likeds(AUDIT_HISTORY_T) dim(1000)): Array to store results

**Return:**
- (int(10)): Number of records found

**Example:**
```rpgle
dcl-ds history likeds(AUDIT_HISTORY_T) dim(100);
dcl-s count int(10);
dcl-s i int(10);

count = AuditLog_GetHistory('CUSTOMER' : '12345' : history);

for i = 1 to count;
  dsply ('Operation: ' + history(i).operation);
  dsply ('User: ' + history(i).userName);
  dsply ('Date: ' + %char(history(i).timestamp));
endfor;
```

---

### `AuditLog_GetHistoryByDate(tableName : dateFrom : dateTo : history)`

Retrieves the history of a table for a given period.

**Parameters:**
- `tableName` (varchar(128)): Table name
- `dateFrom` (timestamp): Start date
- `dateTo` (timestamp): End date
- `history` (likeds(AUDIT_HISTORY_T) dim(1000)): Array to store results

**Return:**
- (int(10)): Number of records found

**Example:**
```rpgle
dcl-s dateFrom timestamp;
dcl-s dateTo timestamp;
dcl-ds history likeds(AUDIT_HISTORY_T) dim(1000);

dateFrom = %timestamp('2025-01-01-00.00.00');
dateTo = %timestamp('2025-12-31-23.59.59');

count = AuditLog_GetHistoryByDate('CUSTOMER' : dateFrom : dateTo : history);
```

---

### `AuditLog_GetHistoryByUser(tableName : userName : history)`

Retrieves all operations performed by a user.

**Parameters:**
- `tableName` (varchar(128)): Table name (or '' for all tables)
- `userName` (varchar(128)): User name
- `history` (likeds(AUDIT_HISTORY_T) dim(1000)): Array to store results

**Return:**
- (int(10)): Number of records found

**Example:**
```rpgle
count = AuditLog_GetHistoryByUser('CUSTOMER' : 'JOHNDOE' : history);

// All tables
count = AuditLog_GetHistoryByUser('' : 'JOHNDOE' : history);
```

---

## Maintenance

### `AuditLog_Purge(retentionDays)`

Purges audit records older than the retention period.

**Parameters:**
- `retentionDays` (int(10)): Number of days to retain

**Return:**
- (int(10)): Number of records deleted

**Example:**
```rpgle
dcl-s deletedCount int(10);

// Delete audits older than 7 years (2555 days)
deletedCount = AuditLog_Purge(2555);

dsply ('Records deleted: ' + %char(deletedCount));
```

**Note:** This function should be executed regularly (monthly or annually) to maintain performance.

---

## Configuration

### `AuditLog_SetConfig(config)`

Configures the audit system parameters.

**Parameters:**
- `config` (likeds(AUDIT_CONFIG_T)): Configuration structure

**Return:**
- (ind): `*ON` if successful, `*OFF` if error

**Example:**
```rpgle
dcl-ds config likeds(AUDIT_CONFIG_T);

config.active = *ON;
config.asyncMode = *OFF;
config.captureIP = *ON;
config.captureJob = *ON;
config.maxRetentionDays = 2555;  // 7 years
config.compressionEnabled = *OFF;

AuditLog_SetConfig(config);
```

---

### `AuditLog_GetConfig(config)`

Retrieves the current configuration.

**Parameters:**
- `config` (likeds(AUDIT_CONFIG_T)): Configuration structure (return)

**Return:**
- (ind): `*ON` if successful, `*OFF` if error

**Example:**
```rpgle
dcl-ds config likeds(AUDIT_CONFIG_T);

AuditLog_GetConfig(config);

dsply ('Active: ' + config.active);
dsply ('Async: ' + config.asyncMode);
```

---

## Utilities

### `AuditLog_GetCurrentUser()`

Gets the current user name.

**Return:**
- (varchar(128)): User name

**Example:**
```rpgle
dcl-s user varchar(128);
user = AuditLog_GetCurrentUser();
```

---

### `AuditLog_GetCurrentIP()`

Gets the current client IP address.

**Return:**
- (varchar(45)): IP address

**Example:**
```rpgle
dcl-s ip varchar(45);
ip = AuditLog_GetCurrentIP();
```

---

### `AuditLog_GetJobName()`

Gets the current job name.

**Return:**
- (varchar(28)): Job name

**Example:**
```rpgle
dcl-s job varchar(28);
job = AuditLog_GetJobName();
```

---

## Data Structures

### `AUDIT_RECORD_T`

Complete audit record structure.

```rpgle
dcl-ds AUDIT_RECORD_T qualified template;
  id bigint(20);
  tableName varchar(128);
  recordKey varchar(1024);
  operation char(1);
  userName varchar(128);
  timestamp timestamp;
  oldValues varchar(10485760:4);
  newValues varchar(10485760:4);
  ipAddress varchar(45);
  programName varchar(10);
  jobName varchar(28);
end-ds;
```

---

### `AUDIT_HISTORY_T`

Simplified structure for history results.

```rpgle
dcl-ds AUDIT_HISTORY_T qualified template;
  id bigint(20);
  operation char(1);
  userName varchar(128);
  timestamp timestamp;
  oldValues varchar(10485760:4);
  newValues varchar(10485760:4);
  programName varchar(10);
end-ds;
```

---

### `AUDIT_CONFIG_T`

Configuration structure.

```rpgle
dcl-ds AUDIT_CONFIG_T qualified template;
  active ind;
  asyncMode ind;
  captureIP ind;
  captureJob ind;
  maxRetentionDays int(10);
  compressionEnabled ind;
end-ds;
```

---

## Constants

```rpgle
dcl-c AUDIT_OP_INSERT 'I';
dcl-c AUDIT_OP_UPDATE 'U';
dcl-c AUDIT_OP_DELETE 'D';
```

---

## SQL Examples

### Search for recent changes
```sql
SELECT * FROM AUDITLOG
WHERE TABLE_NAME = 'CUSTOMER'
  AND TIMESTAMP >= CURRENT_TIMESTAMP - 7 DAYS
ORDER BY TIMESTAMP DESC;
```

### Audit statistics by table
```sql
SELECT TABLE_NAME, OPERATION, COUNT(*) as NB_OPERATIONS
FROM AUDITLOG
GROUP BY TABLE_NAME, OPERATION
ORDER BY TABLE_NAME;
```

### Most active users
```sql
SELECT USER_NAME, COUNT(*) as NB_OPERATIONS
FROM AUDITLOG
WHERE TIMESTAMP >= CURRENT_DATE
GROUP BY USER_NAME
ORDER BY NB_OPERATIONS DESC;
```
