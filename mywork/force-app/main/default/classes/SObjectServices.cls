public with sharing class SObjectServices
{
    public static final String FILE_DOWNLOAD_URL = URL.getSalesforceBaseUrl().toExternalForm() + '/servlet/servlet.FileDownload?file=';
    public static final String SPRINT_PREFIX = Sprint__c.SObjectType.getDescribe().getKeyPrefix();
    public static final String COMPONENT_PREFIX = Component__c.SObjectType.getDescribe().getKeyPrefix();
    public static final String DEPLOYMENT_ATTEMPT_PREFIX = Deployment_Attempt__c.SObjectType.getDescribe().getKeyPrefix();
    public static final String RELEASE_PREFIX = Release__c.SObjectType.getDescribe().getKeyPrefix();
    private static Pattern fieldOrObjectPattern = Pattern.compile('(?i)(\\w+__[cr])');
    private static Matcher patternMatcher;

    @TestVisible
    public static String CURRENT_NAMESPACE
    {
        get
        {
            if (CURRENT_NAMESPACE == null)
            {
                String className = SObjectServices.class.getName();
                Integer dotIndex = className.indexOf('.');

                if( dotIndex == -1 )
                {
                    CURRENT_NAMESPACE = '';
                }
                else
                {
                    CURRENT_NAMESPACE = className.substringBefore('.');
                }
            }
            return CURRENT_NAMESPACE;
        }
        private set;
    }

    public static Boolean isValidId(String idValue){
        try{
            Id validId = Id.valueOf(idValue);
        } catch (System.StringException e){
            return false;
        }
        return true;
    }

    public static String getNameSpace() {
        return String.isBlank(CURRENT_NAMESPACE) ? '' : CURRENT_NAMESPACE + '__';
    }
    
    public static String getFullyQualifiedName(String name) {
        if (String.isBlank(name)) {
            return null;
        }

        return (!name.startsWith(CURRENT_NAMESPACE)) ? CURRENT_NAMESPACE + '__' + name : name;
    }

    public static String getFullyQualifiedQuery(String query) {

	    String outputStringToReturn = query;

	    if (String.isNotBlank(query)) {
		    Set<String> alreadyReplaced = new Set<String>();
			patternMatcher = fieldOrObjectPattern.matcher(query);

			while (patternMatcher.find() == true){
			  String match = patternMatcher.group(0);
		      if(!alreadyReplaced.contains(match)){
			      alreadyReplaced.add(match);
			      outputStringToReturn = outputStringToReturn.replaceAll(match, getFullyQualifiedName(match));
			    }
			}
	    }

        return outputStringToReturn;
    }

    public static Boolean recordHasId(sObject sObj)
    {
         String id = (String) sObj.Id;
         return String.isNotBlank( id );
    }

    public static String getDownloadLinkForAttachment(Attachment att) {
        return FILE_DOWNLOAD_URL + att.Id;
    }

    /**
    * Append a string value to an existing string separated by the specified separator. Used for storing
    * values compressed in an sObject text field
    * @param  currentValue  The value to append to
    * @param  newValue      The value to append
    * @param  separator     The separator
    * @return    the concatenated value. If the value would be greater than a text field size (255),
    *             then the original value will be returned
    *   Custom Setting text field.
    */
    public static String appendValue(String currentValue, String newValue, String separator ) {

        if (String.isEmpty( currentValue )) {
            currentValue = newValue;
        } else if ( currentValue.length() + newValue.length() + separator.length() < 256){
            currentValue += separator + newValue;
        }

        return currentValue;
    }

    public static List<String> getPicklistValues(Schema.DescribeFieldResult fieldResult) {
        List<String> values = new List<String>();

        for(Schema.PicklistEntry picklistEntry : fieldResult.getPicklistValues()) {
            values.add( picklistEntry.getValue() );
        }

        return values;
    }

    public static Map<String, String> getPicklistValueMap(Schema.DescribeFieldResult fieldResult) {
        Map<String, String> valueToLabelMap = new Map<String, String>();

        for (Schema.PicklistEntry picklistEntry : fieldResult.getPicklistValues()) {
            valueToLabelMap.put(picklistEntry.getValue(), picklistEntry.getLabel());
        }

        return valueToLabelMap;
    }

    /**
    * Breaks down the given list of records into smaller sublists
    * @param  records   The list to break down
    * @param  chunkSize The size to break each sub list into
    */
    public static List<List<SObject>> chunkLists(List<SObject> records, Integer chunkSize) {
       List<List<SObject>> chunks = new List<List<SObject>>();

       Integer fromIndex = 0;
       Integer toIndex = 0;

       while (fromIndex < records.size()) {
           List<SObject> chunk = new List<SObject>();

           if (toIndex + chunkSize > records.size()) {
               toIndex = records.size();
           } else {
               toIndex += chunkSize;
           }
           for(Integer i = fromIndex; i < toIndex; i++) {
               chunk.add(records[i]);
           }
           chunks.add( chunk );
           fromIndex += chunkSize;
       }

       return chunks;
   }

   /**
    *  Returns the name field given the Schema.SObjectType, if isNameField retuns false for ALL fields on the SObject,
    *        it will return 'Id' by default.
    */
    public static String getNameField(Schema.SObjectType sobjType){
        String nameFieldResult = 'Id';
        for (Schema.SObjectField sobjField : sobjType.getDescribe().fields.getMap().values()){
            if (sobjField.getDescribe().isNameField()){
                nameFieldResult = sobjField.getDescribe().getName();
                break;
            }
        }
        return nameFieldResult;
    }

    /**
    * Filters out objects from the new list that do not have updates to the given field reference as compared to the old map.
    * @param newList - A list of new objects, potentially containing field updates.
    * @param oldMap - A map of old object IDs to old objects, to be compared against the new objects.
    * @param fieldReference - The field reference to the relevant field to compare when looking for updates.
    * @return A list of the new objects with unchanged objects filtered out.
    */
    public static List<SObject> filterObjectsWithFieldUpdate(List<SObject> newList, Map<Id, SObject> oldMap, Schema.SObjectField fieldReference) {
        if (oldMap == null) {
            return newList;
        }

        List<SObject> filteredNewList = new List<SObject>();
        for (SObject newItem : newList) {
            if (newItem.get(fieldReference) != oldMap.get(newItem.Id).get(fieldReference)) {
                filteredNewList.add(newItem);
            }
        }
        return filteredNewList;
    }

    public class SObjectFieldInfo {
        Schema.DescribeSObjectResult sObjectType;
        Set<String> ignoreRequiredFields;
        public List<String> fieldsAvailable;
        public List<String> required;
        public List<String> lookups;
        public Map<String, String> labelToApiNames;

        public SObjectFieldInfo(Schema.DescribeSObjectResult sObjectTypeIn){
            this(sObjectTypeIn, new Set<String>());
        }

        public SObjectFieldInfo(Schema.DescribeSObjectResult sObjectTypeIn, Set<String> doNotCountAsRequiredField){
            sObjectType = sObjectTypeIn;
            ignoreRequiredFields = doNotCountAsRequiredField;
            fieldsAvailable = new List<String>();
            required = new List<String>();
            lookups = new List<String>();
            labelToApiNames = new Map<String, String>();
        }

        public void populateFieldInfo(){
            for (Schema.SObjectField sobjField : sObjectType.fields.getMap().values()){
                Schema.DescribeFieldResult sobjFieldDescribe = sobjField.getDescribe();
                if (sobjFieldDescribe.isCreateable()){
                    Schema.DisplayType fieldType = sobjFieldDescribe.getType();
                    String fieldApiName = sobjFieldDescribe.getName();
                    labelToApiNames.put(sobjFieldDescribe.getLabel().toLowerCase(), fieldApiName);
                    fieldsAvailable.add(fieldApiName);

                    Boolean isRequired = !sobjFieldDescribe.isNillable() && fieldType != Schema.DisplayType.Boolean;
                    if (isRequired && !ignoreRequiredFields.contains(fieldApiName)) {
                        required.add(fieldApiName);
                    }
                    if (fieldType == Schema.DisplayType.Reference) {
                        lookups.add(fieldApiName);
                    }
                }
            }
        }
    }

    /**
    * Update SObjects allowing partial success
    * @param sObjects - List of SObjects to update
    * @throws ALMException when SObjects fail to update. Message includes Ids of failed update records
    */
    public static void updateSObjectsAllowingPartialSuccess(List<SObject> sObjects) {
        Boolean allOrNoneUpdate = false;
        List<Database.SaveResult> results = Database.update(sObjects, allOrNoneUpdate);

        String errorMessage = '';
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];

            if (!sr.isSuccess()) {
                SObject sObj = sObjects[i]; // The SObject will be at the same index as it's corresponding Save Result
                errorMessage += 'Update failed for SObject ' + sObj.Id
                                + ' with message: ';
                for (Database.Error err : sr.getErrors()) {
                    errorMessage += err.getMessage() + '\n';
                }
            }
        }

        if (String.isNotBlank(errorMessage)) {
            throw new ALMException(errorMessage);
        }
    }

}
