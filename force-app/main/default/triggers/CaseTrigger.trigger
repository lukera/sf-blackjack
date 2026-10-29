trigger CaseTrigger on Case (before insert, before update, after insert, after update) {
    
    List<Case> caseList = new List<Case>();
    //List<Contact> contactList = new List<Contact>();
    
    Set<String> newContactIdSet = new Set<String>();
    Set<String> existingEmailSet = new Set<String>();
    Set<String> existingNameSet = new Set<String>();
    Set<String> newEmailSet = new Set<String>();
    Set<String> newNameSet = new Set<String>();
    
    // Pegar a lista de todos os novos casos
    if(Trigger.isAfter && (Trigger.isInsert)){
        caseList = Trigger.New; 
    }
    
    System.debug('caseList'+caseList);
    
    Set<String> caseIds = new Set<String>();
    
    for (Case caseId : caseList) {
        caseIds.add(caseId.Id);
    }
    
    System.debug('caseIds'+caseIds);
    
    List<Case> newCaseList = [SELECT Id, Contact.Name, Contact.Email, ContactId FROM Case WHERE Id IN: caseIds];
    
    System.debug('newCaseList'+newCaseList);
    
    Map<Id, String> caseByContact = new Map<Id, String>();
    
    for (Case c : newCaseList) {
        if(c.ContactId != null){
            newEmailSet.add(c.Contact.Email);
            newNameSet.add(c.Contact.Name);
            caseByContact.put(c.ContactId, c.Id);
        }
    }
    
    System.debug('newEmailSet'+newEmailSet);
    System.debug('newNameSet'+newNameSet);
    
    //Um soql no objeto contact que ira obter os contatos novo de insert e update
    List<Contact> newContactList = [SELECT Id, Name, Email, createdDate FROM Contact WHERE Email IN: newEmailSet 
                                    AND Email != null AND Name IN: newNameSet ORDER BY CreatedDate ASC LIMIT 200];
    
    Map<String, List<Contact>> contactMap = new Map<String, List<Contact>>();
    
    for (Contact cont : newContactList) {
        if (contactMap.containsKey(cont.Name + cont.Email)) {
            contactMap.get(cont.Name + cont.Email).add(cont);
        } else {
            contactMap.put(cont.Name + cont.Email, new List<Contact> {cont});
        }
    }
    
    System.debug(contactMap);
    
    Set<Case> contactToUpdateSet = new Set<Case>();
    Set<Contact> contactToDeleteSet = new Set<Contact>();
    
    for (Contact cont : newContactList) { 
        for (Contact contactItem : contactMap.get(cont.Name + cont.Email)) {
            if (contactItem.CreatedDate < cont.CreatedDate) {
                Case case1 = new Case(Id = caseByContact.get(cont.Id),ContactId = contactItem.Id);
                contactToUpdateSet.add(case1);
            } else if (contactItem.CreatedDate > cont.CreatedDate) {
                contactToDeleteSet.add(contactItem);
            } 
        }
    }
    
    List<Case> contactToUpdateList = new List<Case>();
    contactToUpdateList.addAll(contactToUpdateSet);
    List<Contact> contactToDeleteList = new List<Contact>();
    contactToDeleteList.addAll(contactToDeleteSet);
    
    System.debug('contactToUpdateList'+contactToUpdateList);
    System.debug('contactToDeleteList'+contactToDeleteList); 
    
    Database.update(contactToUpdateList);
    Database.delete(contactToDeleteList);
    
}