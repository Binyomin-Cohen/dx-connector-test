public with sharing class AuthUserServices {
    public static List<Auth_User__c> filterChangedRefreshToken(List<Auth_User__c> records, Map<Id, Auth_User__c> oldIdToAuthUser) {
        List<Auth_User__c> changedRecords = new List<Auth_User__c>();

        for (Auth_User__c record : records) {
            if (record.Is_For_Tools__c
                && record.Is_Refresh_Token_Valid__c != oldIdToAuthUser.get(record.Id).Is_Refresh_Token_Valid__c) {
                changedRecords.add(record);
            }
        }

        return changedRecords;
    }

    public static void setLoginError(List<Auth_User__c> authUsers) {
        Map<Id, Auth_User__c> instanceIdToAuthUser = new Map<Id, Auth_User__c>();

        for (Auth_User__c authUser : authUsers) {
            instanceIdToAuthUser.put(authUser.Instance__c, authUser);
        }

        List<ALM_Job__c> almJobs = [
            SELECT Source_Instance__c, Target_Instance__c, Login_Error__c
            FROM ALM_Job__c
            WHERE Source_Instance__c IN :instanceIdToAuthUser.keySet()
                OR Target_Instance__c IN :instanceIdToAuthUser.keySet()
        ];

        for (ALM_Job__c almJob : almJobs) {
            Auth_User__c authUserSource = instanceIdToAuthUser.get(almJob.Source_Instance__c);
            Auth_User__c authUserTarget = instanceIdToAuthUser.get(almJob.Target_Instance__c);

            if (authUserSource != null && authUserTarget != null) {
                almJob.Login_Error__c = !(authUserSource.Is_Refresh_Token_Valid__c && authUserTarget.Is_Refresh_Token_Valid__c);
            } else if (authUserSource != null) {
                almJob.Login_Error__c = !authUserSource.Is_Refresh_Token_Valid__c;
            } else if (authUserTarget != null) {
                almJob.Login_Error__c = !authUserTarget.Is_Refresh_Token_Valid__c;
            }
        }

        try {
            update almJobs;
        } catch (DMLException de) {
            for (Integer i = 0; i < de.getNumDml(); ++i) {
                Integer failedIndex = de.getDmlIndex(i);
                String failedMessage = de.getDmlMessage(i);

                Auth_User__c authUserSource = instanceIdToAuthUser.get(almJobs[failedIndex].Source_Instance__c);
                Auth_User__c authUserTarget = instanceIdToAuthUser.get(almJobs[failedIndex].Target_Instance__c);

                Auth_User__c authUser = authUserSource != null ? authUserSource : authUserTarget;

                authUser.addError(failedMessage);
            }
        }
    }
}