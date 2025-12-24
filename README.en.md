# ibmi-audit-trail

Automatic audit system for IBM i - Complete traceability of data changes.

**[🇫🇷 Version française](README.md)** | **🇬🇧 English version**

## 🎯 Objective

Provide a complete and reusable solution to automatically audit all modification operations (INSERT, UPDATE, DELETE) on DB2 for i tables, with GDPR, SOX, and ISO 27001 compliance.

## ✨ Features

- ✅ **Automatic auditing**: Transparent recording of INSERT/UPDATE/DELETE
- ✅ **Complete history**: Before/after values stored in JSON
- ✅ **Enriched metadata**: User, timestamp, IP, program
- ✅ **Simple API**: Just a few lines of code to audit a table
- ✅ **High-performance search**: Optimized indexes for historical queries
- ✅ **Compliance**: GDPR, SOX, ISO 27001
- ✅ **Lightweight**: No external dependencies

## 📦 Installation

Add to your `dependencies.json`:

```json
{
  "dependencies": {
    "ibmi-audit-trail": {
      "url": "https://github.com/IBMiservices/ibmi-audit-trail.git",
      "ref": "main"
    }
  }
}
```

Then install:
```bash
python .vscode-deps/install_deps.py
```

## 🚀 Quick Start

Two possible approaches: **manual** (in your code) or **automatic** (with triggers).

### Approach 1: Automatic Triggers (recommended) 🔥

**100% transparent** audit with DB2 AFTER triggers:

```sql
-- Create the audit table
-- (see structure below)

-- AFTER INSERT Trigger
CREATE OR REPLACE TRIGGER CUSTOMER_AFTER_INSERT
  AFTER INSERT ON CUSTOMER
  REFERENCING NEW AS N
  FOR EACH ROW MODE DB2SQL
BEGIN ATOMIC
  INSERT INTO AUDITLOG (
    TABLE_NAME, RECORD_KEY, OPERATION, USER_NAME,
    NEW_VALUES, IP_ADDRESS, JOB_NAME
  ) VALUES (
    'CUSTOMER',
    CAST(N.ID AS VARCHAR(1024)),
    'I',
    CURRENT_USER,
    JSON_OBJECT('id' VALUE N.ID, 'name' VALUE N.NAME, 'email' VALUE N.EMAIL),
    QSYS2.CLIENT_IPADDR,
    QSYS2.JOB_NAME
  );
END;

-- AFTER UPDATE Trigger
CREATE OR REPLACE TRIGGER CUSTOMER_AFTER_UPDATE
  AFTER UPDATE ON CUSTOMER
  REFERENCING OLD AS O NEW AS N
  FOR EACH ROW MODE DB2SQL
BEGIN ATOMIC
  INSERT INTO AUDITLOG (
    TABLE_NAME, RECORD_KEY, OPERATION, USER_NAME,
    OLD_VALUES, NEW_VALUES, IP_ADDRESS, JOB_NAME
  ) VALUES (
    'CUSTOMER',
    CAST(N.ID AS VARCHAR(1024)),
    'U',
    CURRENT_USER,
    JSON_OBJECT('id' VALUE O.ID, 'name' VALUE O.NAME, 'email' VALUE O.EMAIL),
    JSON_OBJECT('id' VALUE N.ID, 'name' VALUE N.NAME, 'email' VALUE N.EMAIL),
    QSYS2.CLIENT_IPADDR,
    QSYS2.JOB_NAME
  );
END;

-- AFTER DELETE Trigger
CREATE OR REPLACE TRIGGER CUSTOMER_AFTER_DELETE
  AFTER DELETE ON CUSTOMER
  REFERENCING OLD AS O
  FOR EACH ROW MODE DB2SQL
BEGIN ATOMIC
  INSERT INTO AUDITLOG (
    TABLE_NAME, RECORD_KEY, OPERATION, USER_NAME,
    OLD_VALUES, IP_ADDRESS, JOB_NAME
  ) VALUES (
    'CUSTOMER',
    CAST(O.ID AS VARCHAR(1024)),
    'D',
    CURRENT_USER,
    JSON_OBJECT('id' VALUE O.ID, 'name' VALUE O.NAME, 'email' VALUE O.EMAIL),
    QSYS2.CLIENT_IPADDR,
    QSYS2.JOB_NAME
  );
END;
```

✅ **Benefits**: No application code changes, guaranteed audit, centralized  
📝 See [examples/triggers_example.sql](examples/triggers_example.sql) for more examples

### Approach 2: Manual API (in your RPGLE code)

#### 1. Initialization (once)

```rpgle
/include 'auditlog.rpgleinc'

// Create audit table
AuditLog_CreateTable();

// Enable auditing
AuditLog_Init(*ON);
```

#### 2. Audit your operations

```rpgle
// Example: INSERT
dcl-ds customer likeds(CUSTOMER_T);
customer.id = 12345;
customer.name = 'Acme Corp';
customer.email = 'contact@acme.com';

AuditLog_Insert('CUSTOMER' : customer);
exec sql INSERT INTO CUSTOMER VALUES(:customer);
```

```rpgle
// Example: UPDATE
dcl-ds oldCustomer likeds(CUSTOMER_T);
dcl-ds newCustomer likeds(CUSTOMER_T);

exec sql SELECT * INTO :oldCustomer FROM CUSTOMER WHERE ID = :id;
newCustomer = oldCustomer;
newCustomer.email = 'newemail@acme.com';

AuditLog_Update('CUSTOMER' : newCustomer : oldCustomer);
exec sql UPDATE CUSTOMER SET EMAIL = :newCustomer.email WHERE ID = :id;
```

```rpgle
// Example: DELETE
AuditLog_Delete('CUSTOMER' : customer);
exec sql DELETE FROM CUSTOMER WHERE ID = :id;
```

#### 3. Query history

```rpgle
// Get record history
dcl-ds history likeds(AUDIT_HISTORY_T) dim(100);
nbRecords = AuditLog_GetHistory('CUSTOMER' : customerId : history);

// Search by date range
nbRecords = AuditLog_GetHistoryByDate('CUSTOMER' : dateFrom : dateTo : history);

// Search by user
nbRecords = AuditLog_GetHistoryByUser('CUSTOMER' : userName : history);
```

### Which approach to choose?

| Criteria | Triggers (SQL) | API (RPGLE) |
|---------|----------------|-------------|
| **Transparency** | ✅ 100% automatic | ❌ Code modification |
| **Performance** | ✅ Native DB2 | ⚠️ Function call |
| **Flexibility** | ⚠️ Fixed per trigger | ✅ Fine control |
| **Maintenance** | ✅ Centralized | ❌ Scattered |
| **Recommended for** | Production, new tables | Progressive migration |

## 📊 Audit Table Structure

```sql
CREATE TABLE AUDITLOG (
  ID BIGINT GENERATED ALWAYS AS IDENTITY,
  TABLE_NAME VARCHAR(128) NOT NULL,
  RECORD_KEY VARCHAR(1024) NOT NULL,  -- JSON for composite keys
  OPERATION CHAR(1) NOT NULL,         -- I=Insert, U=Update, D=Delete
  USER_NAME VARCHAR(128) NOT NULL,
  TIMESTAMP TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  OLD_VALUES CLOB(10M),               -- JSON
  NEW_VALUES CLOB(10M),               -- JSON
  IP_ADDRESS VARCHAR(45),
  PROGRAM_NAME VARCHAR(10),
  JOB_NAME VARCHAR(28),
  PRIMARY KEY (ID)
);

-- Performance indexes
CREATE INDEX AUDITLOG_TABLE_IDX ON AUDITLOG(TABLE_NAME, RECORD_KEY);
CREATE INDEX AUDITLOG_DATE_IDX ON AUDITLOG(TIMESTAMP DESC);
CREATE INDEX AUDITLOG_USER_IDX ON AUDITLOG(USER_NAME);
```

## 📁 Project Structure

```
ibmi-audit-trail/
├── core/                    # RPGLE source code
│   ├── auditlog.rpgle      # Main module
│   ├── auditlog_utils.rpgle # Utilities
│   └── auditlog.bnd        # Binding directory
├── ref/                     # Include files
│   └── auditlog.rpgleinc   # Prototypes and structures
├── examples/                # Usage examples
│   ├── demo_audit.rpgle    # Demo program
│   ├── triggers_example.sql # SQL trigger examples
│   └── trigger_program.rpgle # System trigger program
├── docs/                    # Documentation
│   ├── API.md              # API Reference
│   └── COMPLIANCE.md       # Compliance Guide
└── tests/                   # Unit tests
    └── test_audit.rpgle    # Tests
```

## 🔐 Compliance

### GDPR
- ✅ Complete traceability (Article 30)
- ✅ Right to be forgotten (controlled purge)
- ✅ Proof of consent

### SOX
- ✅ Financial audit trail
- ✅ Separation of duties
- ✅ Audit reports

### ISO 27001
- ✅ Access security
- ✅ Incident management
- ✅ Change traceability

## 🛠️ API Reference

### Main Functions

| Function | Description |
|----------|-------------|
| `AuditLog_Init(active)` | Enable/disable auditing |
| `AuditLog_CreateTable()` | Create AUDITLOG table |
| `AuditLog_Insert(table : record)` | Record an INSERT |
| `AuditLog_Update(table : new : old)` | Record an UPDATE |
| `AuditLog_Delete(table : record)` | Record a DELETE |
| `AuditLog_GetHistory(table : key : history)` | Retrieve history |
| `AuditLog_Purge(retentionDays)` | Purge old data |

See [docs/API.md](docs/API.md) for complete documentation.

## 📈 Performance

- **Minimal impact**: ~5ms per audited operation
- **Async capable**: Option for audit in data queue
- **Partitioning**: Date-based partitioning support
- **Compression**: Compressed JSON to save space

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 License

GNU General Public License v3.0 - See [LICENSE](LICENSE) for details.

## 🔗 Useful Links

- [Complete documentation](docs/)
- [Examples](examples/)
- [Issues](https://github.com/IBMiservices/ibmi-audit-trail/issues)
- [Dependencies system](https://github.com/IBMiservices/ibmi-dependencies)

## 📞 Support

For any questions or issues, open an [issue](https://github.com/IBMiservices/ibmi-audit-trail/issues).
