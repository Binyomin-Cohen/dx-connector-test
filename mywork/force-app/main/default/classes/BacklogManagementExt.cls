public with sharing class BacklogManagementExt {
    public static final Integer CONFLICT_RESPONSE_CODE = 409;
    public static final Integer ERROR_RESPONSE_CODE = 500;

    public static final Integer COLUMN_PERCENTAGE_WIDTH = 91;
    public static final Integer DEFAULT_COLUMN_COUNT = 3;
    public static final Double DEFAULT_COLUMN_WIDTH_MODIFIER = 1.0;
    public static final Double PUSH_TOPIC_API_VERSION = 39.0;

    // This length should match the minLength option set by setRemoteSource in combobox.js
    public static final Integer REFERENCE_RESULTS_MIN_CHAR_LENGTH = 3;

    public static Integer DEFAULT_PAGE_SIZE = 50;
    //the maximum number of backlog items to load at a time
    public static Integer MAX_RECORD_COUNT = 200;

    public static Map<String, Double> COLUMN_WIDTH_MODIFIER_MAP = new Map<String, Double>{
        'BOOLEAN' => 0.50,
        'INTEGER' => 0.75,
        'PERCENT' => 0.75,
        'DOUBLE' => 0.75,
        'DATETIME' => 0.75,
        'TEXTAREA' => 2.50,
        'STRING' => 2.50
    };

    //NOTE This is not `final` in order to get around testing limitation with duplicate push topic names
    public static String DEFAULT_PUSH_TOPIC_NAME = 'BacklogMgmtUpdates';
    public static String CUSTOM_PUSH_TOPIC_NAME = 'CustomBacklogMgmtUpdates';
    public static final String CUSTOM_BACKLOG_ID_PARAM = 'backlogid';
    public final String DEFAULT_BACKLOG_NAME {
        get{
            if(DEFAULT_BACKLOG_NAME == null) {
                try{
                    DEFAULT_BACKLOG_NAME = CustomBacklogServices.MASTER_BACKLOG_RECORD.Name;
                } catch (ALMException aex) {
                    addPageMessage(new PageMessage(
                        ApexPages.Severity.ERROR,
                        System.Label.Generic_Error + ': ' + aex.getMessage()
                    ));
                }
            }
            return DEFAULT_BACKLOG_NAME;
        }
        set;
    }

    public Double sprintColumnWidth {get; set;}

    public transient List<BacklogItemRow> backlogItems { get; set; }
    public transient List<BacklogItemRow> additionalBacklogItems { get; set; }
    public transient List<BacklogItemRow> unprioritizedBacklogItems { get; set; }

    public List<Column> columns { get; set; }
    public List<SelectOption> statusFilters { get; set; }
    public List<String> selectedStatusFilters { get; set; }
    public Integer columnCount {get; set;}

    public Boolean hasMoreRecords {get; set;}
    public Integer permissionLevel {get; private set;}
    public Integer totalPrioritizedItems {get; set;}
    public String totalPrioritizedItemsDisplay {
        get{
            return totalPrioritizedItems >= Limits.getLimitQueryRows()
                   ? Limits.getLimitQueryRows().format() + '+'
                   : totalPrioritizedItems.format();
        }
        private set;
    }

    public String autoPrioritizationBehavior {get; set;}

    @testVisible
    private Integer recordsLoaded {
        get {
            if (recordsLoaded == null){
                recordsLoaded = 0;
            }
            return recordsLoaded;
        }
        set;
    }

    /**comma delimited list of Backlog__c ids*/
    public String recordsToLoad { get; set; }
    /**comma delimited string of ids to remove form loaded backlog item ids*/
    public String recordsToUnload {get; set;}

    @TestVisible
    private String customBacklogId { get; private set; }
    public String customBacklogTitle { get; private set; }

    public Boolean viewingCustomBacklog {
        get {
            return isCustomBacklogEnabled && String.isNotBlank(customBacklogId) && !isCustomBacklogIdMaster;
        }
        private set;
    }

    public Boolean isCustomBacklogEnabled {
        get {
            return ALMSettings__c.getInstance().Enable_Custom_Backlogs__c;
        }
        private set;
    }

    public Boolean isCustomBacklogIdMaster {
        get {
            return BacklogManagementHomeController.MASTER_BACKLOG_IDENTIFIER.equalsIgnoreCase(customBacklogId);
        }

        private set;
    }

    public transient ALMPageMessages pageMsgs { get; set; }

    public String BACKLOG_ITEM_HOME_URL {
      get {
        return '/' + Schema.SObjectType.Backlog__c.getKeyPrefix() + '/o?nooverride=1';
      }

      private set;
    }

    public String userTimeZone {
        get {
            return UserInfo.getTimeZone().getId();
        }
    }

    public String userLocale {
        get {
            return UserInfo.getLocale();
        }
    }

    private Set<Id> loadedBacklogItemIds;

    public BacklogManagementExt(ApexPages.StandardSetController setCon) {
        hasMoreRecords = false;
        permissionLevel = PermissionServices.checkPagePermissions(new BacklogManagementPermissions()).ordinal();
        selectedStatusFilters = new List<String>();
        loadedBacklogItemIds = new Set<Id>();
        try {
            String backlogIdParameter = ApexPages.currentPage().getParameters().get(CUSTOM_BACKLOG_ID_PARAM);

            if (String.isBlank(backlogIdParameter)) {
                User_Preferences__c preference = User_Preferences__c.getValues(UserInfo.getUserId());
                if (preference != null && String.isNotBlank(preference.Default_Custom_Backlog_Id__c)) {
                    customBacklogId = preference.Default_Custom_Backlog_Id__c;
                }
            } else {
                customBacklogId = backlogIdParameter;
            }

            customBacklogTitle = DEFAULT_BACKLOG_NAME;
            if (!isCustomBacklogIdMaster && String.isNotBlank(customBacklogId)){
                List<Custom_Backlog__c> customBacklogs = [Select Name From Custom_Backlog__c Where Id =: customBacklogId LIMIT 1];
                if (!customBacklogs.isEmpty()){
                    customBacklogTitle = customBacklogs[0].Name;
                }
            }
        } catch (Exception e){
            addPageMessage(new PageMessage(
                ApexPages.Severity.ERROR,
                System.Label.Generic_Error + ': ' + e.getMessage()
            ));
        }
        populateFilters();
        populateColumns();
        columnCount = DEFAULT_COLUMN_COUNT + columns.size();
        calculateColumnWidths();

        getBacklogAutoPrioritizationBehavior();
    }

    public PageReference backlogPageRedirect() {
        if ( isCustomBacklogEnabled && String.isBlank(customBacklogId)) {
            PageReference retURL = new PageReference('/apex/BacklogManagementHome');
            retURL.setRedirect(true);
            return retURL;
         }

         return null;
    }

    /**
    * Loads the initial set of prioritized and unprioritized backlog items.
    */
    public void loadBacklogItems() {
        unprioritizedBacklogItems = getBacklogItems(true, MAX_RECORD_COUNT);
        backlogItems = getBacklogItems(false, DEFAULT_PAGE_SIZE);
        recordsLoaded = DEFAULT_PAGE_SIZE;

        if (backlogItems.isEmpty() && !unprioritizedBacklogItems.isEmpty()) {
            backlogItems = unprioritizedBacklogItems;
            unprioritizedBacklogItems = new List<BacklogItemRow>();
        }

        renumberBacklogItems(backlogItems, 0);
    }

    /**
    * Loads remaining records after the initial partial page load of the first page of records.
    */
    public void loadAdditionalItems() {
        PermissionServices.checkPagePermissions(new BacklogManagementPermissions());
        additionalBacklogItems = getBacklogItems(false, MAX_RECORD_COUNT - DEFAULT_PAGE_SIZE);
        renumberBacklogItems(additionalBacklogItems, DEFAULT_PAGE_SIZE);
        Set<Id> aleadyQueriedRecordIdSet = new Set<Id>();
        for (BacklogItemRow additionalItem : additionalBacklogItems) {
            aleadyQueriedRecordIdSet.add(additionalItem.record.Id);
        }
        if (additionalBacklogItems.size() == MAX_RECORD_COUNT - DEFAULT_PAGE_SIZE) {
            if (viewingCustomBacklog){
                totalPrioritizedItems = BacklogItemServices.getCustomPrioritizedItemCount(customBacklogId, aleadyQueriedRecordIdSet);
            } else {
                totalPrioritizedItems = BacklogItemServices.getPrioritizedItemCount(aleadyQueriedRecordIdSet);
            }
            hasMoreRecords = totalPrioritizedItems > MAX_RECORD_COUNT;
        } else {
            hasMoreRecords = false;
        }
        recordsLoaded += additionalBacklogItems.size();
    }

    /**
    * Load an additional page(<code>MAX_RECORD_COUNT</code> records) requested by the user.
    */
    public void loadAllRemainingItems() {
        loadMoreItems(null);
    }

    /**
    * Loads specific backlog items
    */
    public void loadSpecificItems() {
        List<String> recordIdsToLoad = new List<String>();
        if (!String.isBlank(recordsToLoad)) {
            recordIdsToLoad = (List<String>)String.escapeSingleQuotes(recordsToLoad).split(',');
            recordsToLoad = '';
        }
        loadMoreItems(recordIdsToLoad);
    }

    public void unloadBacklogItems() {
        if (!String.isBlank(recordsToUnload)) {
             loadedBacklogItemIds.removeAll( (List<Id>)recordsToUnload.split(',') );
        }
        recordsToUnload = '';
    }

    public void addPageMessage(PageMessage pm){
        if (pageMsgs == null){
            pageMsgs = new ALMPageMessages();
        }
        pageMsgs.addMessage(pm);
    }

    private void loadMoreItems(List<String> recordIdsToLoad) {
        if (totalPrioritizedItems == null) {
            return;
        }

        additionalBacklogItems = getBacklogItems(recordIdsToLoad, false, MAX_RECORD_COUNT);

        recordsLoaded += additionalBacklogItems.size();
        hasMoreRecords = recordsLoaded < totalPrioritizedItems;
    }

    /**
    * Sequentially renumbers backlog items
    * @param  backlogItems      The items to renumber
    * @param  startingPriority  The number, not inclusive, to start prioritization at.
    */
    private void renumberBacklogItems(List<BacklogItemRow> itemsToRenumber, Integer startingPriority) {
        List<Backlog__c> itemsToUpdate = new List<Backlog__c>();

        Integer priority = startingPriority;
        for (BacklogItemRow backlogItem : itemsToRenumber) {
            priority++;
            if (backlogItem.priority != priority) {
                backlogItem.savePriority(priority);
                itemsToUpdate.add(backlogItem.record);
            }
        }

        if (!itemsToUpdate.isEmpty()) {
            try {
                update itemsToUpdate;
            } catch(DmlException de) {
                addPageMessage(new PageMessage(
                    ApexPages.Severity.ERROR,
                    System.Label.Generic_Error + ': ' + de.getMessage()
                ));
            }
        }
    }

    private void populateFilters() {
        statusFilters = AssemblerServices.getBacklogStatusesAsSelectOptions();
    }

    private void populateColumns() {
        columns = new List<Column>();
        Set<String> unusedDefaultColumns = BacklogItemServices.DEFAULT_COLUMNS.clone();
        Map<String, Schema.SObjectField> fieldInfo = Backlog__c.SObjectType.getDescribe().fields.getMap();
        for (Column column : BacklogItemServices.getPrioritizationFields()) {
            if (unusedDefaultColumns.contains(column.apiName)) {
                unusedDefaultColumns.remove(column.apiName);
            }
            if ( (!viewingCustomBacklog && isCustomBacklogEnabled) || (column.apiName != SObjectServices.getFullyQualifiedName('Custom_Priority__c')) ){
                columns.add(column);
            }
        }
        for (String apiName : unusedDefaultColumns) {
            columns.add( new Column(fieldInfo.get(apiName).getDescribe()) );
        }
    }

    private void calculateColumnWidths() {
        Double totalColumnWidthModifier = 0.0;
        for (Column currentColumn : columns) {
            Double width = COLUMN_WIDTH_MODIFIER_MAP.get(currentColumn.type.name());
            totalColumnWidthModifier += width != null ? width : DEFAULT_COLUMN_WIDTH_MODIFIER;
        }
        Double normalizedWidth = COLUMN_PERCENTAGE_WIDTH / totalColumnWidthModifier;
        for (Column currentColumn : columns) {
            Double width = (
                currentColumn.apiName != 'Name' ?
                COLUMN_WIDTH_MODIFIER_MAP.get(currentColumn.type.name()) :
                DEFAULT_COLUMN_WIDTH_MODIFIER
            );
            currentColumn.width = width != null ? width : DEFAULT_COLUMN_WIDTH_MODIFIER;
            currentColumn.width *= normalizedWidth;
        }
    }

    private List<BacklogItemRow> getBacklogItems(Boolean getUnprioritizedItems, Integer queryLimit) {
        return getBacklogItems(null, getUnprioritizedItems, queryLimit);
    }

    private List<BacklogItemRow> getBacklogItems(List<String> recordIdsToLoad, Boolean getUnprioritizedItems, Integer queryLimit) {

        Set<String> queryFieldSet = new Set<String>();
        for( Column column : columns) {
            if (column.relationshipName != null && column.linkName != null) {
                queryFieldSet.add(column.relationshipName);
                queryFieldSet.add(column.linkName);
            } else if (column.apiName != null) {
                queryFieldSet.add(column.apiName);
            }
        }
        queryFieldSet.addAll(new List<String>{
            SObjectServices.getFullyQualifiedName('Custom_Priority__c'),
            SObjectServices.getFullyQualifiedName('Priority__c')
        });
        List<String> queryFields = new List<String>(queryFieldSet);

        Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();
        String priorityField = viewingCustomBacklog ? 'Custom_Priority__c' : 'Priority__c';


        String query  = 'SELECT ' + String.join(queryFields, ',');
        query        += ' FROM ' + SObjectServices.getFullyQualifiedName('Backlog__c');
        query        += ' WHERE ' + SObjectServices.getFullyQualifiedName('Status__c') + ' NOT IN :inactiveStatuses';

        if (getUnprioritizedItems) {
            query    += ' AND ' + SObjectServices.getFullyQualifiedName(priorityField) + ' = NULL';
        } else {
            query    += ' AND ' + SObjectServices.getFullyQualifiedName(priorityField) + ' != NULL';
        }

        if (recordIdsToLoad != null && !recordIdsToLoad.isEmpty()) {
            query    += ' AND Id IN :recordIdsToLoad';
        }

        query        += ' AND Id NOT IN :loadedBacklogItemIds';

        if (viewingCustomBacklog){
            query    += ' AND '+SObjectServices.getFullyQualifiedName('Custom_Backlog__c')+' =:customBacklogId';
        }

        query        += ' ORDER BY ' + SObjectServices.getFullyQualifiedName(priorityField) + ' ASC NULLS LAST, CreatedDate DESC';
        query        += ' LIMIT ' + queryLimit;

        List<BacklogItemRow> backlogRows = new List<BacklogItemRow>();
        for (Backlog__c backlogItem : Database.query( query )) {
            backlogRows.add( new BacklogItemRow(backlogItem, viewingCustomBacklog) );
            loadedBacklogItemIds.add(backlogItem.Id);
        }

        return backlogRows;
    }

    private static UpdateResponse createConflictResponse(List<BacklogItem> backlogItems, String conflictUser) {
        if (String.isBlank(conflictUser)) {
            conflictUser = 'Another User';
        }
        UpdateResponse conflictResponse = new UpdateResponse();
        conflictResponse.isSuccess = false;
        conflictResponse.errorCode = CONFLICT_RESPONSE_CODE;
        conflictResponse.errorMsg = String.format(System.Label.Grooming_Conflict, new List<String>{conflictUser});
        conflictResponse.recordIds = new List<String>();
        for(BacklogItem item : backlogItems) {
            conflictResponse.recordIds.add( item.id );
        }
        return conflictResponse;
    }
    private static UpdateResponse createErrorResponse(System.DMLException de) {
        UpdateResponse errorResponse = new UpdateResponse();
        errorResponse.isSuccess = false;

        if (de.getDmlType(0) == System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION) {
            errorResponse.errorMsg = System.Label.Validation_Message + de.getDmlMessage(0);
        }
        else {
            errorResponse.errorMsg = de.getMessage();
        }
        errorResponse.errorCode = ERROR_RESPONSE_CODE;

        return errorResponse;
    }

    /**
    * @return Set<String> the set of api names for all columns displayed on the page
    */
    private static Set<String> getAllColumnApiNames() {
        Map<String, Schema.SObjectField> fieldInfo = Backlog__c.SObjectType.getDescribe().fields.getMap();

        Set<String> names = new Set<String>();
        for (ALM_Settings_List__c nameSetting : ALMSettingsServices.getPrioritizationColumnSettings()) {
            String fieldName = nameSetting.Value__c;
            if (fieldInfo.containsKey(fieldName)
                && fieldInfo.get(fieldName).getDescribe().getLength() <= 255) {
                names.add(nameSetting.Value__c);
            }
        }

        names.add('Id');
        names.add(SObjectServices.getFullyQualifiedName('Priority__c'));
        names.add(SObjectServices.getFullyQualifiedName('Custom_Priority__c'));
        names.addAll(BacklogItemServices.DEFAULT_COLUMNS);
        return names;
    }

    public class FieldTypeResult {
        public Map<String, String> typeMap;
        public Map<String, Map<String, String>> picklistMap;
        public FieldTypeResult(){
            typeMap = new Map<String, String>();
            picklistMap = new Map<String, Map<String, String>>();
        }
    }

    @RemoteAction
    public static FieldTypeResult getFieldTypes() {
        FieldTypeResult result = new FieldTypeResult();
	    Map<String, Schema.SObjectField> fieldInfo = Backlog__c.SObjectType.getDescribe().fields.getMap();
        for (String apiName : getAllColumnApiNames()) {
            Schema.DisplayType displayType = fieldInfo.get(apiName).getDescribe().getType();
            result.typeMap.put(apiName, displayType.name());
            if (displayType.name() == 'picklist'){
                Map<String, String> valueMap = SObjectServices.getPicklistValueMap(fieldInfo.get(apiName).getDescribe());
                result.picklistMap.put(apiName, valueMap);
            }
        }
        return result;
	}

    @testVisible
    private static Set<String> getPushTopicColumns(Boolean isCustomBacklog){
        Set<String> fieldNames = getAllColumnApiNames();

        if (isCustomBacklog){
            fieldNames.remove(SObjectServices.getFullyQualifiedName('Priority__c'));
        }

        return fieldNames;
    }
    /**
    * Gets the PushTopic name for listening for backlog updates
    * If the topic doesn't exist or it is deactivated, create it or activate it
    */
    @RemoteAction
    public static String getPushTopic(Boolean isCustomBacklog) {

        final String PUSH_TOPIC_NAME = isCustomBacklog ? CUSTOM_PUSH_TOPIC_NAME : DEFAULT_PUSH_TOPIC_NAME;
        //TODO: need to handle orgs without streamingApi
        List<PushTopic> pushTopics = [SELECT Id, Name, Query, IsActive FROM PushTopic WHERE Name = :PUSH_TOPIC_NAME];

        String fieldNamesString = String.join(new List<String>(getPushTopicColumns(isCustomBacklog)), ',');

        String soql = 'SELECT ' + fieldNamesString + ' FROM ' + SObjectServices.getFullyQualifiedName('Backlog__c');

        PushTopic pushTopic;

        if (pushTopics.isEmpty()) {
            pushTopic = new PushTopic();
            pushTopic.Name = PUSH_TOPIC_NAME;
            pushTopic.Query =  soql;
            pushTopic.ApiVersion = PUSH_TOPIC_API_VERSION;
            pushTopic.NotifyForOperationCreate = true;
            pushTopic.NotifyForOperationUpdate = true;
            pushTopic.NotifyForOperationUndelete = true;
            pushTopic.NotifyForOperationDelete = true;
            pushTopic.NotifyForFields = 'Referenced';
            insert pushTopic;
        } else {
            pushTopic = pushTopics[0];
            if (pushTopic.Query != soql || !pushTopic.isActive) {
                pushTopic.Query = soql;
                pushTopic.isActive = true;
                update pushTopic;
            }
        }

        return pushTopic.Name;
    }

    @RemoteAction
    public static UpdateResponse updateStatuses(List<BacklogItem> itemsToUpdate, String status) {
        UpdateResponse response = new UpdateResponse();

        if (PermissionServices.checkPagePermissions(new BacklogManagementPermissions()).ordinal() < PermissionServices.PermissionLevel.FULL.ordinal()) {
            response.isSuccess = false;
            response.errorMsg = System.Label.Permissions_Error;

            return response;
        }

        //ignore requests for blank updates
        if (String.isBlank(status)) {
            return response;
        }

        if (BacklogItemServices.getInactiveStatuses().contains(status)) {
            response.inactive = true;
        }

        Map<String, BacklogItem> itemsToUpdateMap = new Map<String, BacklogItem>();
        List<Backlog__c> backlogItems;
        for(BacklogItem item : itemsToUpdate) {
            itemsToUpdateMap.put(item.id, item);
        }
        try {
            backlogItems = [
                SELECT Id, Status__c, LastModifiedBy.Name
                FROM Backlog__c
                WHERE Id IN :itemsToUpdateMap.keySet()
                FOR UPDATE
            ];
        } catch (System.QueryException qe) {
            System.debug(qe);
            return createConflictResponse( itemsToUpdate, null );
        }

        for(Backlog__c item : backlogItems) {
            BacklogItem incomingRecord = itemsToUpdateMap.get(item.Id);
            if (incomingRecord.status != item.Status__c
             && status != item.Status__c) {
                return createConflictResponse( itemsToUpdate, item.LastModifiedBy.Name );
            }
            item.Status__c = status;
        }
        try {
            update backlogItems;
        } catch(DmlException de) {
            System.debug(de);
            return createErrorResponse( de );
        }
        return response;
    }

    @RemoteAction
    public static UpdateResponse updatePriorities(List<BacklogItem> itemsToUpdate, Boolean isCustomBacklog) {
        if (PermissionServices.checkPagePermissions(new BacklogManagementPermissions()).ordinal() < PermissionServices.PermissionLevel.FULL.ordinal()) {
            UpdateResponse response = new UpdateResponse();
            response.isSuccess = false;
            response.errorMsg = System.Label.Permissions_Error;

            return response;
        }

        Schema.SObjectField prioritySObjectField = isCustomBacklog ? Backlog__c.Custom_Priority__c : Backlog__c.Priority__c;

        Map<String, BacklogItem> itemsToUpdateMap = new Map<String, BacklogItem>();
        List<Backlog__c> backlogItems;

        for(BacklogItem item : itemsToUpdate) {
            itemsToUpdateMap.put(item.id, item);
        }
        try {
            backlogItems = [
                SELECT Id, Priority__c, Custom_Priority__c, LastModifiedBy.Name
                FROM Backlog__c
                WHERE Id IN :itemsToUpdateMap.keySet()
                FOR UPDATE
            ];
        } catch (System.QueryException qe) {
            System.debug(qe);
            return createConflictResponse( itemsToUpdate, null );
        }

        for(Backlog__c item : backlogItems) {
            BacklogItem incomingRecord = itemsToUpdateMap.get(item.Id);
            if (incomingRecord.priority != item.get(prioritySObjectField)
                 && String.isNotBlank(incomingRecord.oldPriority)
                 && Decimal.valueOf(incomingRecord.oldPriority) != item.get(prioritySObjectField)) {
                return createConflictResponse( itemsToUpdate, item.LastModifiedBy.Name );
            }
            item.put(prioritySObjectField, incomingRecord.priority);
        }
        try {
            update backlogItems;
        } catch(DmlException de) {
            System.debug(de);
            return createErrorResponse( de );
        }
        return new UpdateResponse();
    }

    @RemoteAction
    public static Set<String> getReferenceResults(String fieldApiName, String query){
        if (query == null || query.length() < REFERENCE_RESULTS_MIN_CHAR_LENGTH ){
            throw new ALMException('Minumum length required: ' + REFERENCE_RESULTS_MIN_CHAR_LENGTH);
        }
        Set<String> results = new Set<String>();
        Schema.SObjectField sobjField = Schema.sObjectType.Backlog__c.fields.getMap().get(SObjectServices.getFullyQualifiedName(fieldApiName));
        if (sobjField  != null){
            List<Schema.sObjectType> refObjects = sobjField.getDescribe().getReferenceTo();
            if (!refObjects.isEmpty()){
                String nameField = SObjectServices.getNameField(refObjects[0]);
                String refQuery = 'Select ' + nameField + ' From ' + String.valueOf(refObjects[0]) + ' WHERE ' + nameField +
                  ' like \'%'+String.escapeSingleQuotes(query)+'%\' ';
                results = Pluck.strings(nameField, Database.query(refQuery));
            }
        }
        return results;
    }

    @RemoteAction
    public static Set<String> getInactiveStatuses() {
        return BacklogItemServices.getInactiveStatuses();
    }

    public void getBacklogAutoPrioritizationBehavior() {
        try {
            Id backlogId = getCurrentBacklogId();
            autoPrioritizationBehavior = BacklogItemServices.getBacklogAutoPrioritizationBehavior(backlogId).name().toUpperCase();
        } catch (ALMException e) {
            addPageMessage(new PageMessage(ApexPages.Severity.ERROR, e.getMessage()));
        }
    }

    public void setBacklogAutoPrioritizationBehavior() {
        if (permissionLevel < PermissionServices.PermissionLevel.FULL.ordinal()) {
            return;
        }

        try {
            Id backlogId = getCurrentBacklogId();
            BacklogItemServices.setBacklogAutoPrioritizationBehavior(
                backlogId,
                BacklogAutoPrioritizationModel.convertPrioritizationBehaviorStringToEnum(autoPrioritizationBehavior)
            );
        } catch (ALMException e) {
            addPageMessage(new PageMessage(ApexPages.Severity.ERROR, e.getMessage()));
        }
    }

    private Id getCurrentBacklogId() {
        Id backlogId = null;

        if (!isCustomBacklogEnabled || isCustomBacklogIdMaster) {
            backlogId = BacklogItemServices.UNIVERSAL_BACKLOG_ID;
        } else if (viewingCustomBacklog) {
            backlogId = customBacklogId;
        } else {
            throw new ALMException(System.Label.Backlog_ID_Determination_Error);
        }

        return backlogId;
    }

    public class UpdateResponse {
        public Boolean isSuccess;
        public Boolean inactive;
        public Integer errorCode;
        public String errorMsg;
        public List<String> recordIds;

        public UpdateResponse() {
            isSuccess = true;
            inactive = false;
        }
    }

    /**
    * Data type used for BacklogItems serialized through remote actions
    */
    public class BacklogItem {
        public String id;
        public Decimal priority;
        public String oldPriority;
        public String status;
    }
}
