**FREE

//==============================================================================
// ibmi-audit-trail - Programme de trigger système
// Fichier: trigger_program.rpgle
// Description: Exemple de programme appelé par un trigger système
//==============================================================================

ctl-opt dftactgrp(*NO) actgrp(*NEW);
ctl-opt main(Main);
ctl-opt option(*srcstmt: *nodebugio);

//==============================================================================
// Structure du buffer de trigger (format standard IBM i)
//==============================================================================
dcl-ds TriggerBuffer qualified based(pTriggerBuffer);
  fileName char(10);              // Nom du fichier
  library char(10);               // Bibliothèque
  memberName char(10);            // Nom du membre
  triggerEvent char(1);           // 1=INSERT, 2=DELETE, 3=UPDATE
  triggerTime char(1);            // 1=AFTER, 2=BEFORE
  commitLockLevel char(1);        // Niveau de verrouillage
  reserved1 char(3);
  ccsid int(10);                  // CCSID des données
  reserved2 char(8);
  offsetOldRecord int(10);        // Offset ancien enregistrement
  lengthOldRecord int(10);        // Longueur ancien enregistrement
  lengthOldRecNull int(10);       // Longueur indicateurs null anciens
  offsetOldRecNull int(10);       // Offset indicateurs null anciens
  offsetNewRecord int(10);        // Offset nouvel enregistrement
  lengthNewRecord int(10);        // Longueur nouvel enregistrement
  lengthNewRecNull int(10);       // Longueur indicateurs null nouveaux
  offsetNewRecNull int(10);       // Offset indicateurs null nouveaux
  reserved3 char(4);
  oldRecordData char(32766);      // Ancien enregistrement (taille variable)
  // newRecordData suit après oldRecordData
end-ds;

//==============================================================================
// Structure exemple pour la table CUSTOMER
//==============================================================================
dcl-ds Customer_t qualified template;
  id int(10);
  name varchar(100);
  email varchar(100);
  phone varchar(20);
  createdAt timestamp;
end-ds;

//==============================================================================
// Programme principal
//==============================================================================
dcl-proc Main;
  dcl-pi *N;
    triggerBufferPtr pointer const;
    triggerBufferLength int(10) const;
  end-pi;

  dcl-ds oldCustomer likeds(Customer_t);
  dcl-ds newCustomer likeds(Customer_t);
  dcl-s operation char(1);
  dcl-s tableName varchar(128);
  dcl-s recordKey varchar(1024);
  dcl-s oldJson clob(10485760:4);
  dcl-s newJson clob(10485760:4);
  dcl-s userName varchar(128);
  dcl-s ipAddress varchar(45);
  dcl-s jobName varchar(28);
  
  // Pointeur vers le buffer de trigger
  pTriggerBuffer = triggerBufferPtr;

  // Déterminer le type d'opération
  select;
    when TriggerBuffer.triggerEvent = '1';
      operation = 'I';  // INSERT
    when TriggerBuffer.triggerEvent = '2';
      operation = 'D';  // DELETE
    when TriggerBuffer.triggerEvent = '3';
      operation = 'U';  // UPDATE
  endsl;

  // Construire le nom de la table
  tableName = %trim(TriggerBuffer.library) + '.' + %trim(TriggerBuffer.fileName);

  // Extraire l'ancien enregistrement (si disponible)
  if TriggerBuffer.lengthOldRecord > 0;
    oldCustomer = *ALLX'00';
    %subst(pTriggerBuffer: TriggerBuffer.offsetOldRecord + 1:
           TriggerBuffer.lengthOldRecord) = 
      %addr(oldCustomer);
  endif;

  // Extraire le nouvel enregistrement (si disponible)
  if TriggerBuffer.lengthNewRecord > 0;
    newCustomer = *ALLX'00';
    %subst(pTriggerBuffer: TriggerBuffer.offsetNewRecord + 1:
           TriggerBuffer.lengthNewRecord) = 
      %addr(newCustomer);
  endif;

  // Construire la clé d'enregistrement
  if operation = 'D';
    recordKey = %char(oldCustomer.id);
  else;
    recordKey = %char(newCustomer.id);
  endif;

  // Convertir en JSON (simplifié)
  if operation = 'D' or operation = 'U';
    oldJson = BuildCustomerJSON(oldCustomer);
  endif;

  if operation = 'I' or operation = 'U';
    newJson = BuildCustomerJSON(newCustomer);
  endif;

  // Obtenir les métadonnées
  exec sql SET :userName = CURRENT_USER;
  exec sql SET :ipAddress = QSYS2.CLIENT_IPADDR;
  exec sql SET :jobName = QSYS2.JOB_NAME;

  // Insérer dans la table d'audit
  exec sql INSERT INTO AUDITLOG (
    TABLE_NAME,
    RECORD_KEY,
    OPERATION,
    USER_NAME,
    OLD_VALUES,
    NEW_VALUES,
    IP_ADDRESS,
    JOB_NAME
  ) VALUES (
    :tableName,
    :recordKey,
    :operation,
    :userName,
    :oldJson,
    :newJson,
    :ipAddress,
    :jobName
  );

  return;
end-proc;

//==============================================================================
// Fonction utilitaire: Convertir CUSTOMER en JSON
//==============================================================================
dcl-proc BuildCustomerJSON;
  dcl-pi *N clob(10485760:4);
    customer likeds(Customer_t) const;
  end-pi;

  dcl-s json varchar(32000);

  json = '{' +
    '"id":' + %char(customer.id) + ',' +
    '"name":"' + %trim(customer.name) + '",' +
    '"email":"' + %trim(customer.email) + '",' +
    '"phone":"' + %trim(customer.phone) + '",' +
    '"createdAt":"' + %char(customer.createdAt) + '"' +
    '}';

  return json;
end-proc;
