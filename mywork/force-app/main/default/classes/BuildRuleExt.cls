public with sharing class BuildRuleExt {

    public static final String CRITERIA_DELIMITER = ';';

    public BuildRuleExt(ApexPages.StandardController sc) { }

    @auraEnabled
    public static void removeFromBuildRule(String jenkinsJobId, String deletedCriteria) {
        Jenkins_Job__c existingJob = JenkinsServices.getExistingJob(jenkinsJobId);
        if (existingJob.Build_Rule__c != null 
            && String.isNotEmpty(existingJob.Build_Rule__r.Boolean_Criteria__c) 
            && String.isNotEmpty(deletedCriteria)) {

            Set<String> criteria = JenkinsServices.getExistingBuildRuleCriteria(existingJob);
            criteria.remove(deletedCriteria);
            existingJob.Build_Rule__r.Boolean_Criteria__c = String.join(new List<String>(criteria), CRITERIA_DELIMITER);
            try {
                update existingJob.Build_Rule__r;
            } catch(System.DmlException de) {
                throw new AuraHandledException(System.Label.Generic_Error + ': ' + de.getMessage());
            }
        }
    }

    @auraEnabled
    public static void saveBuildRule(String jenkinsJobId, String newCriteria) {
        Jenkins_Job__c existingJob = JenkinsServices.getExistingJob(jenkinsJobId);
        if (!validateCriteria(jenkinsJobId, newCriteria)) {
            throw new AuraHandledException('Invalid criteria selection ' + newCriteria);
        }

        Build_Rule__c buildRule = (String.isEmpty(existingJob.Build_Rule__c)) ? 
            new Build_Rule__c() : existingJob.Build_Rule__r;

        if (String.isEmpty(buildRule.Boolean_Criteria__c)) {
            buildRule.Boolean_Criteria__c = newCriteria;
        } else {
            buildRule.Boolean_Criteria__c += CRITERIA_DELIMITER + newCriteria;
        }

        try {
            upsert buildRule;

            if (existingJob.Build_Rule__c == null) {
                existingJob.Build_Rule__c = buildRule.Id;
                update existingJob;
            }
        } catch(System.DmlException de) {
            throw new AuraHandledException(System.Label.Generic_Error + ': ' + de.getMessage());
        }
    }

    @auraEnabled
    public static List<Option> getAvailableOptions(String jenkinsJobId) {
        Set<String> existingCriteria;
        try {
            Jenkins_Job__c existingJob = JenkinsServices.getExistingJob(jenkinsJobId);
            existingCriteria = JenkinsServices.getExistingBuildRuleCriteria(existingJob);
        } catch(AuraHandledException ex) {
            existingCriteria  = new Set<String>();
        }
        
        List<Option> options = new List<Option>();

        for (Schema.SObjectField field : CI_Instance__c.SObjectType.getDescribe().fields.getMap().values()) {
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            if (fieldDescribe.getType() == Schema.DisplayType.Boolean 
                    && fieldDescribe.getName().endsWith('__c')
                    && fieldDescribe.isAccessible()) {
                options.add(new Option(fieldDescribe, existingCriteria.contains(fieldDescribe.getName())));
            }
        }

        return options;
    }
    
    private static Boolean validateCriteria(String jenkinsJobId, String fieldName) {
        for(Option option : getAvailableOptions(jenkinsJobId)) {
            if (option.value.equals(fieldName)) { 
                return true;
            }
        }

        return false;
    }

    public class Option {

        @auraEnabled
        public Boolean isSelected;

        @auraEnabled
        public String label;

        @auraEnabled
        public String value;

        public Option(Schema.DescribeFieldResult fieldDescribe, Boolean isSelected) {
            this.isSelected = isSelected;
            this.label = fieldDescribe.getLabel();
            this.value = fieldDescribe.getName();
        }
    }
}