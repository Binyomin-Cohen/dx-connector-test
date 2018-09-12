public with sharing class ComponentSearchController
{
	/**--------------------------------------- DEPRECATED CLASS ---------------------------------------
	
    public Boolean isDebug = true;

    public ApexPages.Action saveAction {get; set;} // The save method to invoke in the page controller

    public ApexPages.Action deleteAction {get; set;} // The delete method to invoke in the page controller

    public ComponentSearchWrapper[] existingSavedMembers {get; set;}

    private String soql; // The soql to get master component list

    public List<Component__c> searchResultsList {get; set;} // The result set of the initial soql, including filtered soqls

    public List<ComponentSearchWrapper> searchResultsWrapper {get;set;} // Wrapper for the soql results

    public List<SelectOption> instances {get; set;}

    public String[] selectedInstances {get; set;}

    public AssetControllerExtension pageController { get;
        set {
            if (value != null) {
                pageController = value;
            }
        }
    }

    public String sortDirection {
        get {
           if (sortDirection == null) {
               sortDirection = 'asc';
           }
           return sortDirection;
        }

        set;
    }

    public String sortField {
        get {
           if (sortField == null) {
               sortField = 'Name';
           }
           return sortField;
        }

        set;
    }

    public Integer recordCount {get; set;}

    // ----------------------
    // Constructor
    // ----------------------
    public ComponentSearchController() {
        log('CONSTRUCTOR.... ComponentSearchController2');

        searchResultsList = new List<Component__c>();

        soql = 'Select Id, Name, Type__c, Deleted__c, Parent_Component__r.Name, Field_Modified_Data__c, Overall_Last_Modified_Date__c From Component__c Where Name != null AND Deleted__c = false AND (Overall_Last_Modified_Date__c <= TODAY OR Overall_Last_Modified_Date__c = null)';

        doQuery();

        Schema.DescribeSObjectResult r = Component__c.sObjectType.getDescribe();

        Schema.DescribeFieldResult f = Schema.sObjectType.Component__c.fields.Source_Instances__c;

        List<Schema.PicklistEntry> values = f.getPicklistValues();

        instances = new List<SelectOption>();
        for(picklistentry ple:schema.Component__c.fields.Source_Instances__c.getdescribe().getpicklistvalues()) {
            instances.add( new SelectOption(ple.getvalue(), ple.getlabel()) );
        }
     }

    public void toggleSort() {

        sortDirection = sortDirection.equals('asc') ? 'desc' : 'asc';

        doQuery();
    }

    public void doQuery() {
        try {
            log('doQuery() : ' + soql + ' order by ' + sortField + ' ' + sortDirection + ' LIMIT 100');

            searchResultsList = Database.query(soql + ' order by ' + sortField + ' ' + sortDirection + ' LIMIT 100');

            createSearchResultsWrappers();
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Could not query for components.  The error was: ' + e.getMessage()));
        }
    }

    private void createSearchResultsWrappers() {
        log('selectedInstances : ' + selectedInstances);

        searchResultsWrapper = new List<ComponentSearchWrapper>();

        for (Component__c component : searchResultsList) {
            log('Adding : ' + component);

            log('fieldModifiedData : ' + component.Field_Modified_Data__c);

            String instanceName = '';
            Datetime lastModifiedDate = null;
            String lastModifiedBy = '';

            if (component.Field_Modified_Data__c != null) {
                List<FieldModifiedData> fieldModifiedData = (List<FieldModifiedData>) JSON.deserialize(component.Field_Modified_Data__c, List<FieldModifiedData>.class);

                for (FieldModifiedData o : fieldModifiedData) {
                    instanceName = o.environmentName;
                    lastModifiedDate = o.lastModifiedDate;
                    lastModifiedBy = o.lastModifiedByName;

                    // If selected instances is null, create a wrapper for each environment listed in the JSON data
                    if (selectedInstances == null) {
                        // Create a wrapper for each JSON object
                        ComponentSearchWrapper.addWrapper(searchResultsWrapper, component, instanceName, '',  lastModifiedDate, lastModifiedBy);
                    } else {
                        // The user wants to filter search results by the instnace name
                        // Only create a wrapper if the selected instnace matches the JSON enviornment
                        for (String instance : selectedInstances) {
                            if (instanceName.equalsIgnoreCase(instance)) {
                                ComponentSearchWrapper.addWrapper(searchResultsWrapper, component, instanceName, '', lastModifiedDate, lastModifiedBy);
                            }
                        }
                    }
                }
            } else {
                // If component doesn't have JSON data, we still need to create a wrapper for the component
                ComponentSearchWrapper.addWrapper(searchResultsWrapper, component, instanceName, '', lastModifiedDate, lastModifiedBy);
            }
        }

        searchResultsWrapper.sort();

        recordCount = searchResultsWrapper.size();
    }

    public PageReference doSearch() {
        String name = Apexpages.currentPage().getParameters().get('name');
        String cType = Apexpages.currentPage().getParameters().get('type');
        String parentName = Apexpages.currentPage().getParameters().get('parentName');
        String includeDeleted = Apexpages.currentPage().getParameters().get('includeDeleted');

        log('Name: ' + name);
        log('Type:' + cType);
        log('Parent Name:' + parentName);
        log('Include Deleted:' + includeDeleted);

        soql = 'Select Id, Name, Type__c, Deleted__c, Parent_Component__r.Name, Field_Modified_Data__c From Component__c Where Name != null';

        // If user has NOT checked the Include Deleted checkbox we want to exclude component records who's deleted field is true.
        if (includeDeleted.equalsIgnoreCase('false')) {
            soql += ' and Deleted__c = false';
        }

        if (!name.equals('')) {
            soql += ' and Name LIKE \'%'+String.escapeSingleQuotes(name)+'%\'';
        }

        if (!cType.equals('')) {
            soql += ' and Type__c LIKE \'%'+String.escapeSingleQuotes(cType)+'%\'';
        }

        if (!parentName.equals('')) {
            soql += ' and Parent_Component__r.Name LIKE \'%'+String.escapeSingleQuotes(parentName)+'%\'';
        }

        doQuery();

        return null;
    }

    public PageReference updateSearchResultsCheckboxes() {
        String isChecked = Apexpages.currentPage().getParameters().get('selectAll');

        log('isChecked : ' + isChecked);

        if (isChecked == 'true') {
            for (ComponentSearchWrapper wrapper : searchResultsWrapper) {
                wrapper.checked = true;

                log('ComponentSearchWrapper : ' + wrapper);
            }
        } else {
            for (ComponentSearchWrapper wrapper : searchResultsWrapper) {
                wrapper.checked = false;
            }
        }

        log('searchResultsWrapper : ' + searchResultsWrapper);

        return null;
    }

    public PageReference updateSavedComponentsCheckboxes() {
        String isChecked = Apexpages.currentPage().getParameters().get('selectAll');

        log('existingSavedMembers : ' + existingSavedMembers);

        if (isChecked == 'true') {
            for (ComponentSearchWrapper wrapper : existingSavedMembers) {
                wrapper.checked = true;
            }
        } else {
            for (ComponentSearchWrapper wrapper : existingSavedMembers) {
                wrapper.checked = false;
            }
        }

        return null;
    }

    private void log(String message) {
        if (isDebug) {
            System.debug('xxxxxxxxxxxxxxxxxxx ' + message);
        }
    }
    */
}