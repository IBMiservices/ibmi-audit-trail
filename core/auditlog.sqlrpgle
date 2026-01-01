**FREE

//==============================================================================
// ibmi-audit-trail - Audit Log System
// Fichier: auditlog.rpgle
// Description: Module principal du système d'audit
//==============================================================================

ctl-opt nomain thread(*concurrent);
ctl-opt option(*srcstmt:*SHOWCPY:*EXT:*XREF:*SECLVL:*DEBUGIO:*EXPDDS);

/include 'auditlog.rpgleinc'

//============e==================================================================
// Variables globales
//==============================================================================
dcl-s gAuditActive ind inz(*OFF);
dcl-ds gConfig likeds(AUDIT_CONFIG_T);

//==============================================================================
// IMPLÉMENTATION - Fonctions principales
//==============================================================================

//------------------------------------------------------------------------------
// AuditLog_Init - Initialise le système d'audit
//------------------------------------------------------------------------------
dcl-proc AuditLog_Init export;
  dcl-pi *N ind;
    active ind const;
  end-pi;

  gAuditActive = active;
  
  // Configuration par défaut
  if active;
    gConfig.active = *ON;
    gConfig.asyncMode = *OFF;
    gConfig.captureIP = *ON;
    gConfig.captureJob = *ON;
    gConfig.maxRetentionDays = 2555;  // 7 ans par défaut
    gConfig.compressionEnabled = *OFF;
  endif;

  return *ON;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_CreateTable - Crée la table AUDITLOG
//------------------------------------------------------------------------------
dcl-proc AuditLog_CreateTable export;
  dcl-pi *N ind;
  end-pi;

  dcl-s sqlStmt varchar(4096);

  // Créer la table
  sqlStmt = 
    'CREATE TABLE AUDITLOG (' +
    '  ID BIGINT GENERATED ALWAYS AS IDENTITY,' +
    '  TABLE_NAME VARCHAR(128) NOT NULL,' +
    '  RECORD_KEY VARCHAR(1024) NOT NULL,' +
    '  OPERATION CHAR(1) NOT NULL,' +
    '  USER_NAME VARCHAR(128) NOT NULL,' +
    '  TIMESTAMP TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,' +
    '  OLD_VALUES CLOB(10M),' +
    '  NEW_VALUES CLOB(10M),' +
    '  IP_ADDRESS VARCHAR(45),' +
    '  PROGRAM_NAME VARCHAR(10),' +
    '  JOB_NAME VARCHAR(28),' +
    '  PRIMARY KEY (ID)' +
    ')';

  exec sql EXECUTE IMMEDIATE :sqlStmt;
  
  if sqlcode <> 0 and sqlcode <> -601;  // -601 = table existe déjà
    return *OFF;
  endif;

  // Créer les indexes
  exec sql CREATE INDEX AUDITLOG_TABLE_IDX 
           ON AUDITLOG(TABLE_NAME, RECORD_KEY);
  
  exec sql CREATE INDEX AUDITLOG_DATE_IDX 
           ON AUDITLOG(TIMESTAMP DESC);
  
  exec sql CREATE INDEX AUDITLOG_USER_IDX 
           ON AUDITLOG(USER_NAME);

  return *ON;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_Insert - Enregistre une opération INSERT
//------------------------------------------------------------------------------
dcl-proc AuditLog_Insert export;
  dcl-pi *N ind;
    tableName varchar(128) const;
    record pointer const options(*string);
  end-pi;

  if not gAuditActive;
    return *ON;
  endif;

  return WriteAuditRecord(
    tableName :
    '' :  // recordKey à extraire du record
    AUDIT_OP_INSERT :
    *NULL :  // oldValues
    record
  );
end-proc;

//------------------------------------------------------------------------------
// AuditLog_Update - Enregistre une opération UPDATE
//------------------------------------------------------------------------------
dcl-proc AuditLog_Update export;
  dcl-pi *N ind;
    tableName varchar(128) const;
    newRecord pointer const options(*string);
    oldRecord pointer const options(*string);
  end-pi;

  if not gAuditActive;
    return *ON;
  endif;

  return WriteAuditRecord(
    tableName :
    '' :  // recordKey à extraire du record
    AUDIT_OP_UPDATE :
    oldRecord :
    newRecord
  );
end-proc;

//------------------------------------------------------------------------------
// AuditLog_Delete - Enregistre une opération DELETE
//------------------------------------------------------------------------------
dcl-proc AuditLog_Delete export;
  dcl-pi *N ind;
    tableName varchar(128) const;
    record pointer const options(*string);
  end-pi;

  if not gAuditActive;
    return *ON;
  endif;

  return WriteAuditRecord(
    tableName :
    '' :  // recordKey à extraire du record
    AUDIT_OP_DELETE :
    record :
    *NULL
  );
end-proc;

//------------------------------------------------------------------------------
// AuditLog_GetHistory - Récupère l'historique d'un enregistrement
//------------------------------------------------------------------------------
dcl-proc AuditLog_GetHistory export;
  dcl-pi *N int(10);
    tableName varchar(128) const;
    recordKey varchar(1024) const;
    history likeds(AUDIT_HISTORY_T) dim(1000);
  end-pi;

  dcl-s count int(10) inz(0);
  dcl-s i int(10) inz(0);
  dcl-s id int(20);
  dcl-s operation char(1);
  dcl-s userName varchar(128);
  dcl-s timestamp_ timestamp;
  dcl-s oldValues sqltype(CLOB_LOCATOR);
  dcl-s newValues sqltype(CLOB_LOCATOR);
  dcl-s programName varchar(10);

  exec sql DECLARE C1 CURSOR FOR
      SELECT ID, OPERATION, USER_NAME, TIMESTAMP,
            OLD_VALUES, NEW_VALUES, PROGRAM_NAME
      FROM AUDITLOG
      WHERE TABLE_NAME = :tableName
        AND RECORD_KEY = :recordKey
      ORDER BY TIMESTAMP
      FOR READ ONLY;

  exec sql OPEN C1;

  exec sql FETCH C1 INTO :id,
                         :operation,
                         :userName,
                         :timestamp_,
                         :oldValues,
                         :newValues,
                         :programName;

  dow sqlstate < '02000';
    i += 1;
    if i > 1000;
      leave;
    endif;
    history(i).id = id;
    history(i).operation = operation;
    history(i).userName = userName;
    history(i).timestamp = timestamp_;
    history(i).oldValues = oldValues;
    history(i).newValues = newValues;
    history(i).programName = programName;
    
    exec sql FETCH C1 INTO :id, :operation, :userName, :timestamp_,
                          :oldValues, :newValues, :programName;
  enddo;

  count = i;

  exec sql CLOSE C1;

  return count;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_GetHistoryByDate - Récupère l'historique par période
//------------------------------------------------------------------------------
dcl-proc AuditLog_GetHistoryByDate export;
  dcl-pi *N int(10);
    tableName varchar(128) const;
    dateFrom timestamp const;
    dateTo timestamp const;
    history likeds(AUDIT_HISTORY_T) dim(1000);
  end-pi;

  dcl-s count int(10) inz(0);
  dcl-s i int(10) inz(0);
  dcl-s id int(20);
  dcl-s operation char(1);
  dcl-s userName varchar(128);
  dcl-s timestamp_ timestamp;
  dcl-s oldValues sqltype(CLOB_LOCATOR);
  dcl-s newValues sqltype(CLOB_LOCATOR);
  dcl-s programName varchar(10);

  exec sql DECLARE C2 CURSOR FOR
    SELECT ID, OPERATION, USER_NAME, TIMESTAMP,
           OLD_VALUES, NEW_VALUES, PROGRAM_NAME
    FROM AUDITLOG
    WHERE TABLE_NAME = :tableName
      AND TIMESTAMP BETWEEN :dateFrom AND :dateTo
    ORDER BY TIMESTAMP DESC
    FOR READ ONLY;

  exec sql OPEN C2;

  exec sql FETCH C2 INTO :id,
                         :operation,
                         :userName,
                         :timestamp_,
                         :oldValues,
                         :newValues,
                         :programName;

  dow sqlstate < '02000';
    i += 1;
    if i > 1000;
      leave;
    endif;
    history(i).id = id;
    history(i).operation = operation;
    history(i).userName = userName;
    history(i).timestamp = timestamp_;
    history(i).oldValues = oldValues;
    history(i).newValues = newValues;
    history(i).programName = programName;
    
    exec sql FETCH C2 INTO :id, :operation, :userName, :timestamp_,
                          :oldValues, :newValues, :programName;
  enddo;

  count = i;

  exec sql CLOSE C2;

  return count;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_GetHistoryByUser - Récupère l'historique par utilisateur
//------------------------------------------------------------------------------
dcl-proc AuditLog_GetHistoryByUser export;
  dcl-pi *N int(10);
    tableName varchar(128) const;
    pUserName varchar(128) const;
    history likeds(AUDIT_HISTORY_T) dim(1000);
  end-pi;

  dcl-s count int(10) inz(0);
  dcl-s i int(10) inz(0);
  dcl-s id int(20);
  dcl-s operation char(1);
  dcl-s userName varchar(128);
  dcl-s timestamp_ timestamp;
  dcl-s oldValues sqltype(CLOB_LOCATOR);
  dcl-s newValues sqltype(CLOB_LOCATOR);
  dcl-s programName varchar(10);
  dcl-s whereClause varchar(256);

  if tableName <> '';
    whereClause = 'TABLE_NAME = :tableName AND USER_NAME = :userName';
  else;
    whereClause = 'USER_NAME = :userName';
  endif;

  exec sql DECLARE C3 CURSOR FOR
    SELECT ID, OPERATION, USER_NAME, TIMESTAMP,
           OLD_VALUES, NEW_VALUES, PROGRAM_NAME
    FROM AUDITLOG
    WHERE USER_NAME = :pUserName
    ORDER BY TIMESTAMP DESC
    FOR READ ONLY;

  exec sql OPEN C3;

  exec sql FETCH C3 INTO :id,
                         :operation,
                         :userName,
                         :timestamp_,
                         :oldValues,
                         :newValues,
                         :programName;

  dow sqlstate < '02000';
    i += 1;
    if i > 1000;
      leave;
    endif;
    history(i).id = id;
    history(i).operation = operation;
    history(i).userName = userName;
    history(i).timestamp = timestamp_;
    history(i).oldValues = oldValues;
    history(i).newValues = newValues;
    history(i).programName = programName;
    
    exec sql FETCH C3 INTO :id, :operation, :userName, :timestamp_,
                          :oldValues, :newValues, :programName;
  enddo;

  count = i;

  exec sql CLOSE C3;

  return count;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_Purge - Purge les anciennes données d'audit
//------------------------------------------------------------------------------
dcl-proc AuditLog_Purge export;
  dcl-pi *N int(10);
    retentionDays int(10) const;
  end-pi;

  dcl-s deletedCount int(10);
  dcl-s cutoffDate timestamp;

  // Calculer la date de coupure
  exec sql SET :cutoffDate = CURRENT_TIMESTAMP - :retentionDays DAYS;

  // Supprimer les enregistrements
  exec sql DELETE FROM AUDITLOG WHERE TIMESTAMP < :cutoffDate;

  exec sql GET DIAGNOSTICS :deletedCount = ROW_COUNT;

  return deletedCount;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_SetConfig - Configure le système d'audit
//------------------------------------------------------------------------------
dcl-proc AuditLog_SetConfig export;
  dcl-pi *N ind;
    config likeds(AUDIT_CONFIG_T) const;
  end-pi;

  gConfig = config;
  gAuditActive = config.active;

  return *ON;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_GetConfig - Récupère la configuration actuelle
//------------------------------------------------------------------------------
dcl-proc AuditLog_GetConfig export;
  dcl-pi *N ind;
    config likeds(AUDIT_CONFIG_T);
  end-pi;

  config = gConfig;
  return *ON;
end-proc;

//==============================================================================
// FONCTIONS UTILITAIRES
//==============================================================================

//------------------------------------------------------------------------------
// AuditLog_GetCurrentUser - Obtient l'utilisateur actuel
//------------------------------------------------------------------------------
dcl-proc AuditLog_GetCurrentUser export;
  dcl-pi *N varchar(128);
  end-pi;

  dcl-s userName varchar(128);

  exec sql SET :userName = CURRENT_USER;

  return userName;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_GetCurrentIP - Obtient l'adresse IP du client
//------------------------------------------------------------------------------
dcl-proc AuditLog_GetCurrentIP export;
  dcl-pi *N varchar(45);
  end-pi;

  dcl-s ipAddress varchar(45);

  exec sql 
      SELECT SYSIBM.CLIENT_IPADDR 
        into :ipAddress 
        FROM SYSIBM.SYSDUMMY1;
        
  if sqlcode <> 0;
    ipAddress = '';
  endif;

  return ipAddress;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_GetJobName - Obtient le nom du job actuel
//------------------------------------------------------------------------------
dcl-proc AuditLog_GetJobName export;
  dcl-pi *N varchar(28);
  end-pi;

  dcl-s jobName varchar(28);

  exec sql SET :jobName = QSYS2.JOB_NAME;

  return jobName;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_GetProgramName - Obtient le nom du programme appelant
//------------------------------------------------------------------------------
dcl-proc AuditLog_GetProgramName export;
  dcl-pi *N varchar(10);
  end-pi;

  dcl-s programName varchar(10);

  // TODO: Utiliser une API système pour obtenir le call stack
  // Pour l'instant, retourner vide
  programName = '';

  return programName;
end-proc;

//------------------------------------------------------------------------------
// AuditLog_RecordToJSON - Convertit une structure en JSON
//------------------------------------------------------------------------------
dcl-proc AuditLog_RecordToJSON export;
  dcl-pi *N ind;
    record pointer const options(*string);
    json sqltype(CLOB_LOCATOR);
  end-pi;

  // TODO: Implémentation avec ibmi-json ou YAJL
  // Pour l'instant, créer un CLOB temporaire et assigner au locator
  EXEC SQL SET :json = '{}';

  return *ON;
end-proc;

//==============================================================================
// FONCTIONS INTERNES
//==============================================================================

//------------------------------------------------------------------------------
// WriteAuditRecord - Écrit un enregistrement d'audit
//------------------------------------------------------------------------------
dcl-proc WriteAuditRecord;
  dcl-pi *N ind;
    tableName varchar(128) const;
    recordKey varchar(1024) const;
    operation char(1) const;
    oldRecord pointer const options(*string);
    newRecord pointer const options(*string);
  end-pi;

  dcl-s userName varchar(128);
  dcl-s ipAddress varchar(45);
  dcl-s jobName varchar(28);
  dcl-s programName varchar(10);
  dcl-s oldJson sqltype(CLOB_LOCATOR);
  dcl-s newJson sqltype(CLOB_LOCATOR);

  // Collecter les métadonnées
  userName = AuditLog_GetCurrentUser();
  
  if gConfig.captureIP;
    ipAddress = AuditLog_GetCurrentIP();
  endif;
  
  if gConfig.captureJob;
    jobName = AuditLog_GetJobName();
  endif;

  programName = AuditLog_GetProgramName();

  // Convertir en JSON
  if oldRecord <> *NULL;
    AuditLog_RecordToJSON(oldRecord : oldJson);
  endif;

  if newRecord <> *NULL;
    AuditLog_RecordToJSON(newRecord : newJson);
  endif;

  // Insérer dans la table d'audit
  exec sql INSERT INTO AUDITLOG (
    TABLE_NAME, RECORD_KEY, OPERATION, USER_NAME,
    OLD_VALUES, NEW_VALUES, IP_ADDRESS, PROGRAM_NAME, JOB_NAME
  ) VALUES (
    :tableName, :recordKey, :operation, :userName,
    :oldJson, :newJson, :ipAddress, :programName, :jobName
  );

  if sqlcode <> 0;
    return *OFF;
  endif;

  return *ON;
end-proc;
