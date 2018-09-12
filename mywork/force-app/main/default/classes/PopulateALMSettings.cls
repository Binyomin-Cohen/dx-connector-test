public with sharing class PopulateALMSettings {
    public static void populateCustomSettingEnableMultipleBacklogs() {
        String errorString;
        ALMSettings__c existingSetting = ALMSettings__c.getOrgDefaults();
        if(!existingSetting.Enable_Custom_Backlogs__c) {
            existingSetting.Enable_Custom_Backlogs__c = true;
            try {
                upsert existingSetting;
            } catch (DMLException dex) {
                errorString = dex.getMessage();
            }

            if (String.isNotBlank(errorString)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                String[] mailTo = new String[] {'productdev@bluewolfgroup.com'};
                mail.setToAddresses(mailTo);
                mail.setSubject('Errors occurred during the universal backlog creation post install process');
                mail.setPlainTextBody(errorString);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
            }
        }
    }
}
