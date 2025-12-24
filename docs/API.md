# API Reference - ibmi-audit-trail

## Table des matières

- [Initialisation](#initialisation)
- [Opérations d'audit](#opérations-daudit)
- [Consultation](#consultation)
- [Maintenance](#maintenance)
- [Configuration](#configuration)
- [Utilitaires](#utilitaires)

---

## Initialisation

### `AuditLog_Init(active)`

Initialise et active/désactive le système d'audit.

**Paramètres:**
- `active` (ind): `*ON` pour activer, `*OFF` pour désactiver

**Retour:**
- (ind): `*ON` si succès, `*OFF` si erreur

**Exemple:**
```rpgle
dcl-s success ind;
success = AuditLog_Init(*ON);
```

---

### `AuditLog_CreateTable()`

Crée la table AUDITLOG et ses indexes. Cette fonction est idempotente (peut être appelée plusieurs fois).

**Retour:**
- (ind): `*ON` si succès, `*OFF` si erreur

**Exemple:**
```rpgle
if AuditLog_CreateTable();
  dsply 'Table créée avec succès';
endif;
```

**Note:** Cette fonction doit être appelée une seule fois lors de l'installation initiale.

---

## Opérations d'audit

### `AuditLog_Insert(tableName : record)`

Enregistre une opération INSERT dans le journal d'audit.

**Paramètres:**
- `tableName` (varchar(128)): Nom de la table
- `record` (pointer): Pointeur vers la structure de données de l'enregistrement

**Retour:**
- (ind): `*ON` si succès, `*OFF` si erreur

**Exemple:**
```rpgle
dcl-ds customer likeds(CUSTOMER_T);
customer.id = 12345;
customer.name = 'Acme Corp';

AuditLog_Insert('CUSTOMER' : %addr(customer));
exec sql INSERT INTO CUSTOMER VALUES(:customer);
```

---

### `AuditLog_Update(tableName : newRecord : oldRecord)`

Enregistre une opération UPDATE avec les valeurs avant et après modification.

**Paramètres:**
- `tableName` (varchar(128)): Nom de la table
- `newRecord` (pointer): Pointeur vers les nouvelles valeurs
- `oldRecord` (pointer): Pointeur vers les anciennes valeurs

**Retour:**
- (ind): `*ON` si succès, `*OFF` si erreur

**Exemple:**
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

Enregistre une opération DELETE.

**Paramètres:**
- `tableName` (varchar(128)): Nom de la table
- `record` (pointer): Pointeur vers l'enregistrement supprimé

**Retour:**
- (ind): `*ON` si succès, `*OFF` si erreur

**Exemple:**
```rpgle
dcl-ds customer likeds(CUSTOMER_T);

exec sql SELECT * INTO :customer FROM CUSTOMER WHERE ID = :id;
AuditLog_Delete('CUSTOMER' : %addr(customer));
exec sql DELETE FROM CUSTOMER WHERE ID = :id;
```

---

## Consultation

### `AuditLog_GetHistory(tableName : recordKey : history)`

Récupère l'historique complet d'un enregistrement spécifique.

**Paramètres:**
- `tableName` (varchar(128)): Nom de la table
- `recordKey` (varchar(1024)): Clé de l'enregistrement (format JSON pour clés composites)
- `history` (likeds(AUDIT_HISTORY_T) dim(1000)): Tableau pour stocker les résultats

**Retour:**
- (int(10)): Nombre d'enregistrements trouvés

**Exemple:**
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

Récupère l'historique d'une table pour une période donnée.

**Paramètres:**
- `tableName` (varchar(128)): Nom de la table
- `dateFrom` (timestamp): Date de début
- `dateTo` (timestamp): Date de fin
- `history` (likeds(AUDIT_HISTORY_T) dim(1000)): Tableau pour stocker les résultats

**Retour:**
- (int(10)): Nombre d'enregistrements trouvés

**Exemple:**
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

Récupère toutes les opérations effectuées par un utilisateur.

**Paramètres:**
- `tableName` (varchar(128)): Nom de la table (ou '' pour toutes les tables)
- `userName` (varchar(128)): Nom de l'utilisateur
- `history` (likeds(AUDIT_HISTORY_T) dim(1000)): Tableau pour stocker les résultats

**Retour:**
- (int(10)): Nombre d'enregistrements trouvés

**Exemple:**
```rpgle
count = AuditLog_GetHistoryByUser('CUSTOMER' : 'JOHNDOE' : history);

// Toutes les tables
count = AuditLog_GetHistoryByUser('' : 'JOHNDOE' : history);
```

---

## Maintenance

### `AuditLog_Purge(retentionDays)`

Purge les enregistrements d'audit antérieurs à la période de rétention.

**Paramètres:**
- `retentionDays` (int(10)): Nombre de jours de rétention

**Retour:**
- (int(10)): Nombre d'enregistrements supprimés

**Exemple:**
```rpgle
dcl-s deletedCount int(10);

// Supprimer les audits de plus de 7 ans (2555 jours)
deletedCount = AuditLog_Purge(2555);

dsply ('Enregistrements supprimés: ' + %char(deletedCount));
```

**Note:** Cette fonction doit être exécutée régulièrement (mensuellement ou annuellement) pour maintenir la performance.

---

## Configuration

### `AuditLog_SetConfig(config)`

Configure les paramètres du système d'audit.

**Paramètres:**
- `config` (likeds(AUDIT_CONFIG_T)): Structure de configuration

**Retour:**
- (ind): `*ON` si succès, `*OFF` si erreur

**Exemple:**
```rpgle
dcl-ds config likeds(AUDIT_CONFIG_T);

config.active = *ON;
config.asyncMode = *OFF;
config.captureIP = *ON;
config.captureJob = *ON;
config.maxRetentionDays = 2555;  // 7 ans
config.compressionEnabled = *OFF;

AuditLog_SetConfig(config);
```

---

### `AuditLog_GetConfig(config)`

Récupère la configuration actuelle.

**Paramètres:**
- `config` (likeds(AUDIT_CONFIG_T)): Structure de configuration (retour)

**Retour:**
- (ind): `*ON` si succès, `*OFF` si erreur

**Exemple:**
```rpgle
dcl-ds config likeds(AUDIT_CONFIG_T);

AuditLog_GetConfig(config);

dsply ('Active: ' + config.active);
dsply ('Async: ' + config.asyncMode);
```

---

## Utilitaires

### `AuditLog_GetCurrentUser()`

Obtient le nom de l'utilisateur actuel.

**Retour:**
- (varchar(128)): Nom d'utilisateur

**Exemple:**
```rpgle
dcl-s user varchar(128);
user = AuditLog_GetCurrentUser();
```

---

### `AuditLog_GetCurrentIP()`

Obtient l'adresse IP du client actuel.

**Retour:**
- (varchar(45)): Adresse IP

**Exemple:**
```rpgle
dcl-s ip varchar(45);
ip = AuditLog_GetCurrentIP();
```

---

### `AuditLog_GetJobName()`

Obtient le nom du job actuel.

**Retour:**
- (varchar(28)): Nom du job

**Exemple:**
```rpgle
dcl-s job varchar(28);
job = AuditLog_GetJobName();
```

---

## Structures de données

### `AUDIT_RECORD_T`

Structure complète d'un enregistrement d'audit.

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

Structure simplifiée pour les résultats d'historique.

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

Structure de configuration.

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

## Constantes

```rpgle
dcl-c AUDIT_OP_INSERT 'I';
dcl-c AUDIT_OP_UPDATE 'U';
dcl-c AUDIT_OP_DELETE 'D';
```

---

## Codes SQL utilisés

### Recherche de modifications récentes
```sql
SELECT * FROM AUDITLOG
WHERE TABLE_NAME = 'CUSTOMER'
  AND TIMESTAMP >= CURRENT_TIMESTAMP - 7 DAYS
ORDER BY TIMESTAMP DESC;
```

### Statistiques d'audit par table
```sql
SELECT TABLE_NAME, OPERATION, COUNT(*) as NB_OPERATIONS
FROM AUDITLOG
GROUP BY TABLE_NAME, OPERATION
ORDER BY TABLE_NAME;
```

### Utilisateurs les plus actifs
```sql
SELECT USER_NAME, COUNT(*) as NB_OPERATIONS
FROM AUDITLOG
WHERE TIMESTAMP >= CURRENT_DATE
GROUP BY USER_NAME
ORDER BY NB_OPERATIONS DESC;
```
