-- ============================================================================
-- ibmi-audit-trail - Exemples de triggers d'audit
-- Fichier: triggers_example.sql
-- Description: Exemples d'utilisation des triggers pour un audit automatique
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Exemple 1: Trigger AFTER INSERT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER CUSTOMER_AFTER_INSERT
  AFTER INSERT ON CUSTOMER
  REFERENCING NEW AS N
  FOR EACH ROW
  MODE DB2SQL
BEGIN ATOMIC
  -- Préparer les données en JSON
  DECLARE v_new_values CLOB(10M);
  DECLARE v_record_key VARCHAR(1024);
  
  SET v_record_key = CAST(N.ID AS VARCHAR(1024));
  
  SET v_new_values = JSON_OBJECT(
    'id' VALUE N.ID,
    'name' VALUE N.NAME,
    'email' VALUE N.EMAIL,
    'phone' VALUE N.PHONE,
    'created_at' VALUE N.CREATED_AT
  );
  
  -- Insérer dans la table d'audit
  INSERT INTO AUDITLOG (
    TABLE_NAME, 
    RECORD_KEY, 
    OPERATION, 
    USER_NAME,
    NEW_VALUES,
    IP_ADDRESS,
    JOB_NAME
  ) VALUES (
    'CUSTOMER',
    v_record_key,
    'I',
    CURRENT_USER,
    v_new_values,
    QSYS2.CLIENT_IPADDR,
    QSYS2.JOB_NAME
  );
END;

-- ----------------------------------------------------------------------------
-- Exemple 2: Trigger AFTER UPDATE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER CUSTOMER_AFTER_UPDATE
  AFTER UPDATE ON CUSTOMER
  REFERENCING OLD AS O NEW AS N
  FOR EACH ROW
  MODE DB2SQL
BEGIN ATOMIC
  -- Préparer les données en JSON
  DECLARE v_old_values CLOB(10M);
  DECLARE v_new_values CLOB(10M);
  DECLARE v_record_key VARCHAR(1024);
  
  SET v_record_key = CAST(N.ID AS VARCHAR(1024));
  
  -- Anciennes valeurs
  SET v_old_values = JSON_OBJECT(
    'id' VALUE O.ID,
    'name' VALUE O.NAME,
    'email' VALUE O.EMAIL,
    'phone' VALUE O.PHONE,
    'created_at' VALUE O.CREATED_AT
  );
  
  -- Nouvelles valeurs
  SET v_new_values = JSON_OBJECT(
    'id' VALUE N.ID,
    'name' VALUE N.NAME,
    'email' VALUE N.EMAIL,
    'phone' VALUE N.PHONE,
    'created_at' VALUE N.CREATED_AT
  );
  
  -- Insérer dans la table d'audit
  INSERT INTO AUDITLOG (
    TABLE_NAME, 
    RECORD_KEY, 
    OPERATION, 
    USER_NAME,
    OLD_VALUES,
    NEW_VALUES,
    IP_ADDRESS,
    JOB_NAME
  ) VALUES (
    'CUSTOMER',
    v_record_key,
    'U',
    CURRENT_USER,
    v_old_values,
    v_new_values,
    QSYS2.CLIENT_IPADDR,
    QSYS2.JOB_NAME
  );
END;

-- ----------------------------------------------------------------------------
-- Exemple 3: Trigger AFTER DELETE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER CUSTOMER_AFTER_DELETE
  AFTER DELETE ON CUSTOMER
  REFERENCING OLD AS O
  FOR EACH ROW
  MODE DB2SQL
BEGIN ATOMIC
  -- Préparer les données en JSON
  DECLARE v_old_values CLOB(10M);
  DECLARE v_record_key VARCHAR(1024);
  
  SET v_record_key = CAST(O.ID AS VARCHAR(1024));
  
  SET v_old_values = JSON_OBJECT(
    'id' VALUE O.ID,
    'name' VALUE O.NAME,
    'email' VALUE O.EMAIL,
    'phone' VALUE O.PHONE,
    'created_at' VALUE O.CREATED_AT
  );
  
  -- Insérer dans la table d'audit
  INSERT INTO AUDITLOG (
    TABLE_NAME, 
    RECORD_KEY, 
    OPERATION, 
    USER_NAME,
    OLD_VALUES,
    IP_ADDRESS,
    JOB_NAME
  ) VALUES (
    'CUSTOMER',
    v_record_key,
    'D',
    CURRENT_USER,
    v_old_values,
    QSYS2.CLIENT_IPADDR,
    QSYS2.JOB_NAME
  );
END;

-- ----------------------------------------------------------------------------
-- Exemple 4: Trigger avec clé composite
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER ORDERLINE_AFTER_UPDATE
  AFTER UPDATE ON ORDER_LINES
  REFERENCING OLD AS O NEW AS N
  FOR EACH ROW
  MODE DB2SQL
BEGIN ATOMIC
  DECLARE v_old_values CLOB(10M);
  DECLARE v_new_values CLOB(10M);
  DECLARE v_record_key VARCHAR(1024);
  
  -- Clé composite en JSON
  SET v_record_key = JSON_OBJECT(
    'order_id' VALUE N.ORDER_ID,
    'line_number' VALUE N.LINE_NUMBER
  );
  
  SET v_old_values = JSON_OBJECT(
    'order_id' VALUE O.ORDER_ID,
    'line_number' VALUE O.LINE_NUMBER,
    'product_id' VALUE O.PRODUCT_ID,
    'quantity' VALUE O.QUANTITY,
    'price' VALUE O.PRICE
  );
  
  SET v_new_values = JSON_OBJECT(
    'order_id' VALUE N.ORDER_ID,
    'line_number' VALUE N.LINE_NUMBER,
    'product_id' VALUE N.PRODUCT_ID,
    'quantity' VALUE N.QUANTITY,
    'price' VALUE N.PRICE
  );
  
  INSERT INTO AUDITLOG (
    TABLE_NAME, 
    RECORD_KEY, 
    OPERATION, 
    USER_NAME,
    OLD_VALUES,
    NEW_VALUES,
    IP_ADDRESS,
    JOB_NAME
  ) VALUES (
    'ORDER_LINES',
    v_record_key,
    'U',
    CURRENT_USER,
    v_old_values,
    v_new_values,
    QSYS2.CLIENT_IPADDR,
    QSYS2.JOB_NAME
  );
END;

-- ----------------------------------------------------------------------------
-- Exemple 5: Trigger conditionnel (seulement certains champs)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER CUSTOMER_SENSITIVE_DATA_UPDATE
  AFTER UPDATE OF EMAIL, PHONE ON CUSTOMER
  REFERENCING OLD AS O NEW AS N
  FOR EACH ROW
  MODE DB2SQL
  WHEN (N.EMAIL <> O.EMAIL OR N.PHONE <> O.PHONE)
BEGIN ATOMIC
  DECLARE v_old_values CLOB(10M);
  DECLARE v_new_values CLOB(10M);
  DECLARE v_record_key VARCHAR(1024);
  
  SET v_record_key = CAST(N.ID AS VARCHAR(1024));
  
  -- Auditer uniquement les champs modifiés
  SET v_old_values = JSON_OBJECT(
    'email' VALUE O.EMAIL,
    'phone' VALUE O.PHONE
  );
  
  SET v_new_values = JSON_OBJECT(
    'email' VALUE N.EMAIL,
    'phone' VALUE N.PHONE
  );
  
  INSERT INTO AUDITLOG (
    TABLE_NAME, 
    RECORD_KEY, 
    OPERATION, 
    USER_NAME,
    OLD_VALUES,
    NEW_VALUES,
    IP_ADDRESS,
    JOB_NAME
  ) VALUES (
    'CUSTOMER',
    v_record_key,
    'U',
    CURRENT_USER,
    v_old_values,
    v_new_values,
    QSYS2.CLIENT_IPADDR,
    QSYS2.JOB_NAME
  );
END;

-- ----------------------------------------------------------------------------
-- Script de génération automatique de triggers
-- ----------------------------------------------------------------------------
-- Utiliser cette requête pour générer les triggers pour toutes les tables
-- d'un schéma

SELECT 
  'CREATE OR REPLACE TRIGGER ' || TABLE_SCHEMA || '.' || TABLE_NAME || '_AFTER_INSERT' || CHR(10) ||
  '  AFTER INSERT ON ' || TABLE_SCHEMA || '.' || TABLE_NAME || CHR(10) ||
  '  REFERENCING NEW AS N' || CHR(10) ||
  '  FOR EACH ROW MODE DB2SQL' || CHR(10) ||
  'BEGIN ATOMIC' || CHR(10) ||
  '  INSERT INTO AUDITLOG (TABLE_NAME, RECORD_KEY, OPERATION, USER_NAME, NEW_VALUES, IP_ADDRESS, JOB_NAME)' || CHR(10) ||
  '  VALUES (''' || TABLE_NAME || ''', ''KEY'', ''I'', CURRENT_USER, ''JSON'', QSYS2.CLIENT_IPADDR, QSYS2.JOB_NAME);' || CHR(10) ||
  'END;' AS CREATE_TRIGGER_STATEMENT
FROM QSYS2.SYSTABLES
WHERE TABLE_SCHEMA = 'VOTRE_SCHEMA'
  AND TABLE_TYPE = 'T';

-- ----------------------------------------------------------------------------
-- Désactivation/Réactivation des triggers
-- ----------------------------------------------------------------------------

-- Désactiver un trigger
-- ALTER TRIGGER CUSTOMER_AFTER_INSERT DISABLE;

-- Réactiver un trigger
-- ALTER TRIGGER CUSTOMER_AFTER_INSERT ENABLE;

-- Supprimer un trigger
-- DROP TRIGGER CUSTOMER_AFTER_INSERT;

-- Lister tous les triggers
SELECT 
  TRIGGER_SCHEMA,
  TRIGGER_NAME,
  EVENT_OBJECT_TABLE,
  ACTION_TIMING,
  EVENT_MANIPULATION,
  ENABLED
FROM QSYS2.SYSTRIGGERS
WHERE TRIGGER_SCHEMA = CURRENT_SCHEMA
ORDER BY EVENT_OBJECT_TABLE, TRIGGER_NAME;

-- ============================================================================
-- TRIGGERS SYSTÈME (External Program Triggers)
-- ============================================================================

-- Les triggers système appellent un programme externe (RPG, COBOL, etc.)
-- plutôt que du code SQL inline. Ils offrent plus de flexibilité et
-- de performance pour des traitements complexes.

-- ----------------------------------------------------------------------------
-- Étape 1: Créer le programme de trigger
-- ----------------------------------------------------------------------------
-- Voir le fichier trigger_program.rpgle pour l'implémentation complète
-- 
-- Compiler le programme:
-- CRTRPGMOD MODULE(MYLIB/TRGCUSTAUD) SRCSTMF('examples/trigger_program.rpgle')
-- CRTPGM PGM(MYLIB/TRGCUSTAUD) MODULE(MYLIB/TRGCUSTAUD)

-- ----------------------------------------------------------------------------
-- Étape 2: Créer le trigger système avec ADDPFTRG
-- ----------------------------------------------------------------------------

-- Trigger AFTER INSERT
-- ADDPFTRG FILE(MYLIB/CUSTOMER) 
--          TRGTIME(*AFTER) 
--          TRGEVENT(*INSERT) 
--          PGM(MYLIB/TRGCUSTAUD)
--          TRGUPDCND(*ALWAYS)

-- Trigger AFTER UPDATE
-- ADDPFTRG FILE(MYLIB/CUSTOMER) 
--          TRGTIME(*AFTER) 
--          TRGEVENT(*UPDATE) 
--          PGM(MYLIB/TRGCUSTAUD)
--          TRGUPDCND(*ALWAYS)

-- Trigger AFTER DELETE
-- ADDPFTRG FILE(MYLIB/CUSTOMER) 
--          TRGTIME(*AFTER) 
--          TRGEVENT(*DELETE) 
--          PGM(MYLIB/TRGCUSTAUD)

-- ----------------------------------------------------------------------------
-- Alternative: Créer via SQL (IBM i 7.2+)
-- ----------------------------------------------------------------------------

-- Trigger système INSERT
CREATE OR REPLACE TRIGGER CUSTOMER_SYS_INSERT
  AFTER INSERT ON CUSTOMER
  REFERENCING NEW AS N
  FOR EACH ROW
  MODE DB2ROW
  EXTERNAL NAME MYLIB.TRGCUSTAUD
  LANGUAGE RPGLE;

-- Trigger système UPDATE
CREATE OR REPLACE TRIGGER CUSTOMER_SYS_UPDATE
  AFTER UPDATE ON CUSTOMER
  REFERENCING OLD AS O NEW AS N
  FOR EACH ROW
  MODE DB2ROW
  EXTERNAL NAME MYLIB.TRGCUSTAUD
  LANGUAGE RPGLE;

-- Trigger système DELETE
CREATE OR REPLACE TRIGGER CUSTOMER_SYS_DELETE
  AFTER DELETE ON CUSTOMER
  REFERENCING OLD AS O
  FOR EACH ROW
  MODE DB2ROW
  EXTERNAL NAME MYLIB.TRGCUSTAUD
  LANGUAGE RPGLE;

-- ----------------------------------------------------------------------------
-- Gestion des triggers système
-- ----------------------------------------------------------------------------

-- Lister les triggers système (commande CL)
-- DSPPFTRG FILE(MYLIB/CUSTOMER)

-- Supprimer un trigger système (commande CL)
-- RMVPFTRG FILE(MYLIB/CUSTOMER) 
--          TRGTIME(*AFTER) 
--          TRGEVENT(*INSERT)

-- Désactiver temporairement
-- CHGPFTRG FILE(MYLIB/CUSTOMER)
--          TRGTIME(*AFTER)
--          TRGEVENT(*INSERT)
--          TRG(*DISABLE)

-- Réactiver
-- CHGPFTRG FILE(MYLIB/CUSTOMER)
--          TRGTIME(*AFTER)
--          TRGEVENT(*INSERT)
--          TRG(*ENABLE)

-- ----------------------------------------------------------------------------
-- Comparaison: Triggers SQL vs Triggers Système
-- ----------------------------------------------------------------------------

-- Triggers SQL (MODE DB2SQL):
--   ✅ Plus simple à écrire et maintenir
--   ✅ Code inline dans le trigger
--   ✅ Utilise JSON_OBJECT natif
--   ✅ Pas besoin de compiler séparément
--   ⚠️  Moins flexible pour logique complexe
--   ⚠️  Limité aux fonctions SQL

-- Triggers Système (MODE DB2ROW / ADDPFTRG):
--   ✅ Performance optimale pour traitements lourds
--   ✅ Accès complet aux APIs système
--   ✅ Réutilisable pour plusieurs tables
--   ✅ Logique métier complexe possible
--   ✅ Peut appeler d'autres programmes
--   ⚠️  Plus complexe à développer
--   ⚠️  Nécessite compilation séparée
--   ⚠️  Buffer de trigger à décoder manuellement

-- Recommandation:
--   - Triggers SQL: Pour l'audit simple et standard (recommandé)
--   - Triggers Système: Pour des besoins avancés (transformations, validations, etc.)
