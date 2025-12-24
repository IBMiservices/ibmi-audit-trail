# ibmi-audit-trail

Système d'audit automatique pour IBM i - Traçabilité complète des modifications de données.

**🇫🇷 Version française** | **[🇬🇧 English version](README.en.md)**

## 🎯 Objectif

Fournir une solution complète et réutilisable pour auditer automatiquement toutes les opérations de modification (INSERT, UPDATE, DELETE) sur les tables DB2 for i, avec conformité RGPD, SOX et ISO 27001.

## ✨ Fonctionnalités

- ✅ **Audit automatique** : Enregistrement transparent des INSERT/UPDATE/DELETE
- ✅ **Historique complet** : Stockage des valeurs avant/après en JSON
- ✅ **Métadonnées enrichies** : User, timestamp, IP, programme
- ✅ **API simple** : Quelques lignes de code pour auditer une table
- ✅ **Recherche performante** : Indexes optimisés pour requêtes historiques
- ✅ **Conformité** : RGPD, SOX, ISO 27001
- ✅ **Léger** : Pas de dépendances externes

## 📦 Installation

Ajoutez dans votre `dependencies.json` :

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

Puis installez :
```bash
python .vscode-deps/install_deps.py
```

## 🚀 Utilisation rapide

Deux approches possibles : **manuelle** (dans votre code) ou **automatique** (avec triggers).

### Approche 1: Triggers automatiques (recommandé) 🔥

Audit **100% transparent** avec des triggers DB2 AFTER :

```sql
-- Créer la table d'audit
-- (voir structure plus bas)

-- Trigger AFTER INSERT
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

-- Trigger AFTER UPDATE
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

-- Trigger AFTER DELETE
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

✅ **Avantages** : Aucune modification du code applicatif, audit garanti, centralisé  
📝 Voir [examples/triggers_example.sql](examples/triggers_example.sql) pour plus d'exemples

### Approche 2: API manuelle (dans votre code RPGLE)

#### 1. Initialisation (une seule fois)

```rpgle
/include 'auditlog.rpgleinc'

// Créer la table d'audit
AuditLog_CreateTable();

// Activer l'audit
AuditLog_Init(*ON);
```

#### 2. Auditer vos opérations

```rpgle
// Exemple : INSERT
dcl-ds customer likeds(CUSTOMER_T);
customer.id = 12345;
customer.name = 'Acme Corp';
customer.email = 'contact@acme.com';

AuditLog_Insert('CUSTOMER' : customer);
exec sql INSERT INTO CUSTOMER VALUES(:customer);
```

```rpgle
// Exemple : UPDATE
dcl-ds oldCustomer likeds(CUSTOMER_T);
dcl-ds newCustomer likeds(CUSTOMER_T);

exec sql SELECT * INTO :oldCustomer FROM CUSTOMER WHERE ID = :id;
newCustomer = oldCustomer;
newCustomer.email = 'newemail@acme.com';

AuditLog_Update('CUSTOMER' : newCustomer : oldCustomer);
exec sql UPDATE CUSTOMER SET EMAIL = :newCustomer.email WHERE ID = :id;
```

```rpgle
// Exemple : DELETE
AuditLog_Delete('CUSTOMER' : customer);
exec sql DELETE FROM CUSTOMER WHERE ID = :id;
```

#### 3. Consulter l'historique

```rpgle
// Obtenir l'historique d'un enregistrement
dcl-ds history likeds(AUDIT_HISTORY_T) dim(100);
nbRecords = AuditLog_GetHistory('CUSTOMER' : customerId : history);

// Recherche par période
nbRecords = AuditLog_GetHistoryByDate('CUSTOMER' : dateFrom : dateTo : history);

// Recherche par utilisateur
nbRecords = AuditLog_GetHistoryByUser('CUSTOMER' : userName : history);
```

### Quelle approche choisir ?

| Critère | Triggers (SQL) | API (RPGLE) |
|---------|----------------|-------------|
| **Transparence** | ✅ 100% automatique | ❌ Modification du code |
| **Performance** | ✅ Natif DB2 | ⚠️ Appel de fonction |
| **Flexibilité** | ⚠️ Fixe par trigger | ✅ Contrôle fin |
| **Maintenance** | ✅ Centralisée | ❌ Dispersée |
| **Recommandé pour** | Production, nouvelles tables | Migration progressive |

## 📊 Structure de la table d'audit

```sql
CREATE TABLE AUDITLOG (
  ID BIGINT GENERATED ALWAYS AS IDENTITY,
  TABLE_NAME VARCHAR(128) NOT NULL,
  RECORD_KEY VARCHAR(1024) NOT NULL,  -- JSON pour clés composites
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

-- Indexes pour performance
CREATE INDEX AUDITLOG_TABLE_IDX ON AUDITLOG(TABLE_NAME, RECORD_KEY);
CREATE INDEX AUDITLOG_DATE_IDX ON AUDITLOG(TIMESTAMP DESC);
CREATE INDEX AUDITLOG_USER_IDX ON AUDITLOG(USER_NAME);
```

## 📁 Structure du projet

```
ibmi-audit-trail/
├── core/                    # Code source RPGLE
│   ├── auditlog.rpgle      # Module principal
│   ├── auditlog_utils.rpgle # Utilitaires
│   └── auditlog.bnd        # Binding directory
├── ref/                     # Fichiers include
│   └── auditlog.rpgleinc   # Prototypes et structures
├── examples/                # Exemples d'utilisation
│   ├── demo_audit.rpgle    # Programme de démonstration
│   ├── triggers_example.sql # Exemples de triggers SQL
│   └── trigger_program.rpgle # Programme de trigger système
├── docs/                    # Documentation
│   ├── API.md              # Référence API
│   └── COMPLIANCE.md       # Guide conformité
└── tests/                   # Tests unitaires
    └── test_audit.rpgle    # Tests
```

## 🔐 Conformité

### RGPD
- ✅ Traçabilité complète (Article 30)
- ✅ Droit à l'oubli (purge contrôlée)
- ✅ Preuve de consentement

### SOX
- ✅ Audit trail financier
- ✅ Séparation des tâches
- ✅ Rapports d'audit

### ISO 27001
- ✅ Sécurité des accès
- ✅ Gestion des incidents
- ✅ Traçabilité des modifications

## 🛠️ API Référence

### Fonctions principales

| Fonction | Description |
|----------|-------------|
| `AuditLog_Init(active)` | Active/désactive l'audit |
| `AuditLog_CreateTable()` | Crée la table AUDITLOG |
| `AuditLog_Insert(table : record)` | Enregistre un INSERT |
| `AuditLog_Update(table : new : old)` | Enregistre un UPDATE |
| `AuditLog_Delete(table : record)` | Enregistre un DELETE |
| `AuditLog_GetHistory(table : key : history)` | Récupère l'historique |
| `AuditLog_Purge(retentionDays)` | Purge les anciennes données |

Voir [docs/API.md](docs/API.md) pour la documentation complète.

## 📈 Performance

- **Impact minimal** : ~5ms par opération auditée
- **Async possible** : Option pour audit en data queue
- **Partitionnement** : Support du partitionnement par date
- **Compression** : JSON compressé pour économiser l'espace

## 🤝 Contribution

Les contributions sont bienvenues ! Voir [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 Licence

GNU General Public License v3.0 - Voir [LICENSE](LICENSE) pour plus de détails.

## 🔗 Liens utiles

- [Documentation complète](docs/)
- [Exemples](examples/)
- [Issues](https://github.com/IBMiservices/ibmi-audit-trail/issues)
- [Système de dépendances](https://github.com/IBMiservices/ibmi-dependencies)

## 📞 Support

Pour toute question ou problème, ouvrez une [issue](https://github.com/IBMiservices/ibmi-audit-trail/issues).
