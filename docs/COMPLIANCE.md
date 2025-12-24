# Guide de Conformité - ibmi-audit-trail

Ce document explique comment utiliser `ibmi-audit-trail` pour répondre aux exigences des différentes réglementations.

## 📋 Table des matières

- [RGPD (Règlement Général sur la Protection des Données)](#rgpd)
- [SOX (Sarbanes-Oxley Act)](#sox)
- [ISO 27001 (Sécurité de l'information)](#iso-27001)
- [Bonnes pratiques](#bonnes-pratiques)

---

## RGPD

### Article 30 : Registre des traitements

**Exigence:** Tenir un registre des activités de traitement.

**Solution avec ibmi-audit-trail:**
```rpgle
// Activer l'audit sur toutes les tables contenant des données personnelles
AuditLog_Init(*ON);

// Auditer les opérations
AuditLog_Insert('CONTACTS' : %addr(contact));
AuditLog_Update('CONTACTS' : %addr(new) : %addr(old));
AuditLog_Delete('CONTACTS' : %addr(contact));
```

**Rapport de conformité:**
```sql
-- Liste des opérations sur données personnelles
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

### Article 17 : Droit à l'effacement

**Exigence:** Possibilité de supprimer toutes les données d'une personne.

**Solution:**
```rpgle
// 1. Logger la suppression
AuditLog_Delete('CUSTOMERS' : %addr(customer));

// 2. Effectuer la suppression
exec sql DELETE FROM CUSTOMERS WHERE ID = :customerId;

// 3. Générer un rapport de suppression
dcl-ds history likeds(AUDIT_HISTORY_T) dim(100);
count = AuditLog_GetHistory('CUSTOMERS' : %char(customerId) : history);

// 4. Conserver la preuve de suppression (durée légale)
// L'audit reste dans AUDITLOG avec OLD_VALUES
```

---

### Article 33 : Notification de violation

**Exigence:** Détecter et notifier les violations de données sous 72h.

**Solution:**
```sql
-- Détection d'accès suspects
SELECT 
  USER_NAME,
  COUNT(*) as NB_ACCESS,
  MIN(TIMESTAMP) as FIRST_ACCESS,
  MAX(TIMESTAMP) as LAST_ACCESS
FROM AUDITLOG
WHERE TABLE_NAME = 'CUSTOMERS'
  AND TIMESTAMP >= CURRENT_TIMESTAMP - 24 HOURS
GROUP BY USER_NAME
HAVING COUNT(*) > 1000;  -- Seuil d'alerte

-- Accès hors heures ouvrables
SELECT * FROM AUDITLOG
WHERE HOUR(TIMESTAMP) NOT BETWEEN 8 AND 18
  AND DAYOFWEEK(TIMESTAMP) BETWEEN 2 AND 6;
```

---

### Article 35 : Analyse d'impact (DPIA)

**Exigence:** Documentation des traitements à risque.

**Rapport automatique:**
```sql
-- Analyse des opérations par type
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

### Section 302 : Certification des rapports financiers

**Exigence:** Trail d'audit complet des données financières.

**Solution:**
```rpgle
// Auditer toutes les tables financières
AuditLog_Init(*ON);

// Exemple: Factures
AuditLog_Insert('INVOICES' : %addr(invoice));
AuditLog_Update('INVOICES' : %addr(new) : %addr(old));

// Exemple: Paiements
AuditLog_Insert('PAYMENTS' : %addr(payment));
```

**Rapport de conformité SOX:**
```sql
-- Toutes les modifications de données financières
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

### Section 404 : Contrôles internes

**Exigence:** Documentation des contrôles et des changements.

**Séparation des tâches:**
```sql
-- Vérifier qu'un utilisateur ne peut pas créer ET approuver
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
HAVING COUNT(DISTINCT USER_NAME) = 1;  -- Alerte: même utilisateur
```

---

### Section 802 : Rétention des documents

**Exigence:** Conservation des audits pendant 7 ans.

**Configuration:**
```rpgle
dcl-ds config likeds(AUDIT_CONFIG_T);

config.active = *ON;
config.maxRetentionDays = 2555;  // 7 ans

AuditLog_SetConfig(config);
```

**Purge automatique:**
```rpgle
// Job mensuel de purge
dcl-s deleted int(10);

// Ne garder que 7 ans
deleted = AuditLog_Purge(2555);

dsply ('Audits purgés: ' + %char(deleted));
```

---

## ISO 27001

### A.9 : Contrôle d'accès

**Exigence:** Traçabilité des accès aux informations.

**Solution:**
```sql
-- Rapport d'accès par utilisateur
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

### A.12 : Sécurité des opérations

**Exigence:** Journalisation des événements.

**Configuration complète:**
```rpgle
dcl-ds config likeds(AUDIT_CONFIG_T);

config.active = *ON;
config.captureIP = *ON;      // Tracer l'IP
config.captureJob = *ON;     // Tracer le job
config.asyncMode = *OFF;     // Synchrone pour garantir l'écriture

AuditLog_SetConfig(config);
```

---

### A.16 : Gestion des incidents

**Exigence:** Capacité d'investigation.

**Enquête sur incident:**
```sql
-- Exemple: Qui a modifié ce client le 15 décembre?
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

## Bonnes pratiques

### 1. Activation sélective

```rpgle
// N'auditer que les tables sensibles
dcl-s auditTables varchar(50) dim(10);

auditTables(1) = 'CUSTOMERS';
auditTables(2) = 'INVOICES';
auditTables(3) = 'PAYMENTS';
auditTables(4) = 'EMPLOYEES';
auditTables(5) = 'CONTRACTS';

// Auditer uniquement ces tables
if %lookup(tableName : auditTables) > 0;
  AuditLog_Insert(tableName : %addr(record));
endif;
```

---

### 2. Rapports réguliers

**Job mensuel de rapport:**
```rpgle
// Générer un rapport mensuel pour la direction
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

// Envoyer par email ou sauvegarder dans l'IFS
```

---

### 3. Alertes automatiques

```sql
-- Créer une vue pour alertes
CREATE VIEW AUDIT_ALERTS AS
SELECT 
  'VOLUME_ANORMAL' as ALERT_TYPE,
  USER_NAME,
  COUNT(*) as NB_OPERATIONS,
  CURRENT_TIMESTAMP as ALERT_TIME
FROM AUDITLOG
WHERE TIMESTAMP >= CURRENT_TIMESTAMP - 1 HOUR
GROUP BY USER_NAME
HAVING COUNT(*) > 100;  -- Seuil configurable
```

---

### 4. Protection de la table d'audit

```sql
-- Créer un rôle dédié pour l'audit
CREATE ROLE AUDIT_ADMIN;

-- Accès lecture seule pour les autres
GRANT SELECT ON AUDITLOG TO PUBLIC;

-- Seul AUDIT_ADMIN peut modifier
GRANT ALL ON AUDITLOG TO AUDIT_ADMIN;
REVOKE DELETE, UPDATE ON AUDITLOG FROM PUBLIC;
```

---

### 5. Archivage à long terme

```rpgle
// Archiver les audits de plus d'1 an dans une table d'archive
exec sql 
  INSERT INTO AUDITLOG_ARCHIVE
  SELECT * FROM AUDITLOG
  WHERE TIMESTAMP < CURRENT_DATE - 365 DAYS;

// Puis purger la table principale
AuditLog_Purge(365);
```

---

## Checklist de conformité

### RGPD
- ✅ Traçabilité complète des opérations (Article 30)
- ✅ Preuve de suppression (Article 17)
- ✅ Détection de violations (Article 33)
- ✅ Documentation DPIA (Article 35)

### SOX
- ✅ Trail d'audit financier (Section 302)
- ✅ Contrôles internes (Section 404)
- ✅ Rétention 7 ans (Section 802)

### ISO 27001
- ✅ Contrôle d'accès (A.9)
- ✅ Journalisation (A.12)
- ✅ Investigation d'incidents (A.16)

---

## Support

Pour toute question sur la conformité, consultez :
- [Documentation API](API.md)
- [Issues GitHub](https://github.com/IBMiservices/ibmi-audit-trail/issues)
