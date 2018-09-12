trigger AssetDuplicatePreventer on Backlog_Component__c (before insert, before update) {
    
    String soql = '';
    
    for (Backlog_Component__c member : System.Trigger.new) {
        if ( System.Trigger.isInsert || (member.Component__c != System.Trigger.oldMap.get(member.Id).Component__c && member.Source_Sandbox__c != System.Trigger.oldMap.get(member.Id).Source_Sandbox__c) ) {
            String conditionClause = '(Source_Sandbox__c = \'' + member.Source_Sandbox__c + '\' AND Component__c = \''+ member.Component__c + '\' AND Backlog__c = \'' + member.Backlog__c + '\' AND Profile_Permission__c = ' + member.Profile_Permission__c;
            
            if (member.Profile__c != null) {
            	conditionClause += ' AND Profile__c = \''+ member.Profile__c + '\')';
            } else {
            	conditionClause += ')';
            }
            
            if (soql == '') {
                soql = 'Select Backlog__c, Source_Sandbox__c, Profile_Permission__c, Profile__c, Profile__r.Name, Component__c, Component__r.Name, Component__r.Type__c, Component__r.Parent_Component__r.Name FROM Backlog_Component__c Where ' + conditionClause;

            } else {
                soql += ' OR ' + conditionClause;
            }
        }
    }
    
    if (soql != '') {
        List<Backlog_Component__c> qr = Database.query(soql);
        
        if (qr.size() >= 1) {
            for (Backlog_Component__c triggerBacklogComp : System.Trigger.new) {
                for (Backlog_Component__c qrComp : qr) {
                    if (qrComp.Component__c == triggerBacklogComp.Component__c && 
                        qrComp.Source_Sandbox__c == triggerBacklogComp.Source_Sandbox__c && 
                        qrComp.Profile_Permission__c == triggerBacklogComp.Profile_Permission__c && 
                        qrComp.Profile__c == triggerBacklogComp.Profile__c) {
                        	triggerBacklogComp.addError('Duplicate component found on this Backlog. Component: ' + qrComp.Component__r.Name + ' | Type: ' + qrComp.Component__r.Type__c + ' | Parent Component: ' + qrComp.Component__r.Parent_Component__r.Name);
                            break;
                    }
                }
            }
        } 
    }
    
}