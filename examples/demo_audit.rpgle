**FREE

//==============================================================================
// ibmi-audit-trail - Audit Log System
// Fichier: demo_audit.rpgle
// Description: Programme de démonstration du système d'audit
//==============================================================================

ctl-opt dftactgrp(*NO) actgrp(*NEW);
ctl-opt main(Main);
ctl-opt option(*srcstmt: *nodebugio);
ctl-opt bnddir('AUDITLOG');

/include 'auditlog.rpgleinc'

//==============================================================================
// Structure exemple: Client
//==============================================================================
dcl-ds CUSTOMER_T qualified template;
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
  dcl-s success ind;
  dcl-ds customer likeds(CUSTOMER_T);
  dcl-ds oldCustomer likeds(CUSTOMER_T);
  dcl-ds history likeds(AUDIT_HISTORY_T) dim(100);
  dcl-s historyCount int(10);
  dcl-s i int(10);

  // 1. Initialiser le système d'audit
  dsply 'Initialisation du système d''audit...';
  success = AuditLog_Init(*ON);
  
  if not success;
    dsply 'Erreur lors de l''initialisation';
    return;
  endif;

  // 2. Créer la table d'audit (première fois uniquement)
  dsply 'Création de la table AUDITLOG...';
  success = AuditLog_CreateTable();
  
  if success;
    dsply 'Table AUDITLOG créée avec succès';
  else;
    dsply 'Table AUDITLOG existe déjà';
  endif;

  // 3. Simuler un INSERT
  dsply 'Test INSERT...';
  customer.id = 12345;
  customer.name = 'Acme Corporation';
  customer.email = 'contact@acme.com';
  customer.phone = '+33123456789';
  customer.createdAt = %timestamp();

  success = AuditLog_Insert('CUSTOMER' : %addr(customer));
  
  if success;
    dsply 'INSERT audité avec succès';
  else;
    dsply 'Erreur lors de l''audit INSERT';
  endif;

  // 4. Simuler un UPDATE
  dsply 'Test UPDATE...';
  oldCustomer = customer;
  customer.email = 'newemail@acme.com';
  customer.phone = '+33987654321';

  success = AuditLog_Update('CUSTOMER' : %addr(customer) : %addr(oldCustomer));
  
  if success;
    dsply 'UPDATE audité avec succès';
  else;
    dsply 'Erreur lors de l''audit UPDATE';
  endif;

  // 5. Consulter l'historique
  dsply 'Consultation de l''historique...';
  historyCount = AuditLog_GetHistory('CUSTOMER' : '12345' : history);
  
  dsply ('Nombre d''opérations: ' + %char(historyCount));

  for i = 1 to historyCount;
    dsply ('Op: ' + history(i).operation + 
           ' User: ' + history(i).userName + 
           ' Date: ' + %char(history(i).timestamp));
  endfor;

  // 6. Simuler un DELETE
  dsply 'Test DELETE...';
  success = AuditLog_Delete('CUSTOMER' : %addr(customer));
  
  if success;
    dsply 'DELETE audité avec succès';
  else;
    dsply 'Erreur lors de l''audit DELETE';
  endif;

  // 7. Tester la purge (ne pas vraiment purger dans la démo)
  dsply 'Test de purge (simulation)...';
  dsply 'Purge désactivée pour la démo';
  
  dsply 'Démonstration terminée avec succès!';

end-proc;
