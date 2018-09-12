@RestResource(urlMapping='/FeedbackAPI/*')
global with sharing class FeedbackRestService
{
    public static String EQUALS_OPERATOR = 'equals';
    public static String NO_SETTINGS_ERROR_MSG = 'Feedback API settings have not been configured.';
    public static String INVALID_SETTINGS_ERROR_MSG = 'Feedback API settings have not been configured Properly. Invalid target object.';
    public static String INVALID_MAPPING_ERROR_MSG = 'Feedback API mapping has not been configured Properly. Please check your mappings.';
    public static String INVALID_JSON_ERROR = 'Invalid JSON data.';
    public static String UNAUTHORIZED_MSG = 'Unauthorized request.';

    /**
    *  Creates an SObject from the feedbackData
    *  @param feedbackData     JSON string representing field data for the feedback record  i.e. '{"Story_Description__c" : "value xxx"}'
    *  @param authToken    The org Id to check for authorization
    */
    @HttpPost
    global static Response create(String feedbackData, String authToken)
    {
        Feedback_API_Settings__c settings = Feedback_API_Settings__c.getInstance();
        List<Feedback_API_Mapping__c> fieldMappings = Feedback_API_Mapping__c.getAll().values();

        if( settings == null || fieldMappings.isEmpty() )
        {
            return new Response(false, NO_SETTINGS_ERROR_MSG);
        }
        else if( !isAuthorized( settings, authToken) )
        {
            return new Response(false, UNAUTHORIZED_MSG);
        }

        SObject target;

        try
        {
            target = buildTargetObject( settings.Target_Object_Name__c, fieldMappings, feedbackData);
        }
        catch( FeedbackAPIException fe )
        {
            return new Response(false, fe.getMessage());
        }
        catch( Exception e )
        {
            return new Response(false, 'An unknown error occured: ' + e.getMessage());
        }

        try
        {
            insert target;
        }
        catch( DMLException de)
        {
            return new Response(false, de.getMessage());
        }

        String name = getName(settings, target);

        return new Response(true, '', String.valueOf( target.Id ), name);
    }

    private static Boolean isAuthorized(Feedback_API_Settings__c settings, String orgId)
    {
        return (settings.Org_Id__c == orgId);
    }

    private static String getName(Feedback_API_Settings__c settings, SObject record)
    {
        String query = 'SELECT Name FROM ' + settings.Target_Object_Name__c;
        query += ' WHERE Id = \'' + record.Id + '\'';
        List<SObject> records = Database.query( query );
        if (records.isEmpty())
        {
            return '';
        }
        else
        {
        	return String.valueOf( records[0].get('Name') );
        }
    }

    /**
    * Creates an sObject of type typeName from fieldMappings using the data from fieldJSON
    *  @param typeName      The type to create
    *  @param fieldMappings  Used to map fields from the fieldJSON to the target object
    *  @param fieldJSON      JSON Field mapping for source / target object
    *  @throws FeedbackAPIException
    */
    private static sObject buildTargetObject(String typeName, List<Feedback_API_Mapping__c> fieldMappings, String fieldJSON)
    {
        Map<String, Object> sourceData;
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(typeName);
        if (targetType == null) {
            throw new FeedbackAPIException(INVALID_SETTINGS_ERROR_MSG);
        }

        try
        {
            sourceData = (Map<String, Object>) JSON.deserializeUntyped( fieldJSON );
        }
        catch(System.JSONException je)
        {
            throw new FeedbackAPIException(INVALID_JSON_ERROR);
        }

        SObject target = targetType.newSObject();

        for( Feedback_API_Mapping__c mapping : fieldMappings )
        {
            if ( sourceData.containsKey( mapping.Source_Field__c ) )
            {
                Object value = sourceData.get( mapping.Source_Field__c );

                if (mapping.Is_Complex__c)
                {
                    if (String.isBlank(mapping.Operator__c)
                        || (mapping.Operator__c.equalsIgnoreCase( EQUALS_OPERATOR )
                             && mapping.Comparison_Value__c != null
                             && mapping.Comparison_Value__c.equalsIgnoreCase( String.valueOf( value ))))
                    {
                        Formula f = new Formula( mapping.Target_Value__c );
                        value = f.evaluateSimpleMergeFields(sourceData);
                    }
                    else
                    {
                        continue;
                    }
                }

                if (value instanceof String && Formula.isDateTime( (String)value )) {
                    value = Formula.parseJSONDateTime( (String)value );
                }
                else if (value instanceof String && Formula.isDate( (String)value )) {
                    value = Date.valueOf( (String)value );
                }

                try
                {
                    target.put( mapping.Target_Field__c, value );
                }
                catch(System.SObjectException se)
                {
                    throw new FeedbackAPIException(INVALID_MAPPING_ERROR_MSG + ':' +mapping.Target_Field__c);
                }
            }
        }

        return target;
    }

    global class Response
    {
        public Boolean success;
        /*holds any error message if an error occured*/
        public String message;
        public String createdId;
        public String createdName;

        public Response( Boolean success, String message)
        {
            this.success = success;
            this.message = message;
        }
        public Response( Boolean success, String message, String createdId, String createdName)
        {
            this( success, message);
            this.createdId = createdId;
            this.createdName = createdName;
        }
    }

    global class FeedbackAPIException extends Exception {}
}