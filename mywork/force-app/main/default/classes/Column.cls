public with sharing class Column implements Comparable {
    public Boolean isDefault {get; set;}
    public Boolean isStatic {get; set;}
    public Double width {get; set;}
    public Schema.DisplayType type {get; set;}
    public String apiName {get; set;}
    public String label {get; set;}
    public String linkName {get; set;}
    public Boolean ignoreLink {get; set;}
    public String localName {get; set;}
    public String relationshipName {get; set;}

    public Boolean isField {get; set;}
    
    public List<SelectOption> picklistOptions {get; set;}
    
    final private Set<Schema.DisplayType> PICKLIST_FIELD_TYPES = new Set<Schema.DisplayType>{
      Schema.DisplayType.Picklist, Schema.DisplayType.MultiPicklist
    };
    
    final private Set<Schema.DisplayType> BOOLEAN_FIELD_TYPES = new Set<Schema.DisplayType>{
      Schema.DisplayType.Boolean 
    };
    
    final private Set<Schema.DisplayType> REFERENCE_FIELD_TYPES = new Set<Schema.DisplayType>{
      Schema.DisplayType.Reference 
    };
    
    final private Set<Schema.DisplayType> USER_INPUT_FIELD_TYPES = new Set<Schema.DisplayType>{
      Schema.DisplayType.String, Schema.DisplayType.TextArea, Schema.DisplayType.URL, Schema.DisplayType.Email,  
      Schema.DisplayType.Integer, Schema.DisplayType.Percent, Schema.DisplayType.Double, Schema.DisplayType.Phone,
      Schema.DisplayType.Currency  
    };
    
    public Boolean isPicklist { 
      get {
        return PICKLIST_FIELD_TYPES.contains(this.type) || 
               BOOLEAN_FIELD_TYPES.contains(this.type); 
      }
      set; 
    }
    
    public Boolean isUserInput { 
      get {
        return USER_INPUT_FIELD_TYPES.contains(this.type); 
      }
      set; 
    }
    
    public Boolean isReferenceLookup { 
      get {
        return REFERENCE_FIELD_TYPES.contains(this.type); 
      }
      set; 
    }
    
    public Boolean isFilterable { 
      get {
        return isPicklist || isUserInput || isReferenceLookup;
      }
      set; 
    }

    public Column(Schema.DescribeFieldResult f) {
        this.label = f.getLabel();
        this.localName = f.getLocalName();
        this.apiName = f.getName();
        this.isDefault = false;
        this.isStatic = false;
        this.picklistOptions = new List<SelectOption>();
        this.isField = true;
        this.type = f.getType();
        if (this.apiName == 'Name') {
            this.relationshipName = 'Name';
            this.linkName = 'Id';
        } else if (this.type == Schema.DisplayType.Reference && this.apiName != 'RecordTypeId') {
            this.relationshipName = this.apiName.substringBeforeLast('Id').substringBeforeLast('__c');
            String nameField = SObjectServices.getNameField(f.getReferenceTo()[0]);
            this.relationshipName += f.isCustom() ? '__r.'+nameField : '.'+nameField;
            this.linkName = this.apiName;
        } else if (this.apiName == 'RecordTypeId') {
            this.relationshipName = 'RecordType.Name';
            this.linkName = this.apiName;
            this.ignoreLink = true;
        }
        
        if (isPicklist) {
            if (BOOLEAN_FIELD_TYPES.contains(this.type)){
                this.picklistOptions.add(new SelectOption( 'true', 'True' ));
                this.picklistOptions.add(new SelectOption( 'false', 'False' ));
            }
            else if (PICKLIST_FIELD_TYPES.contains(this.type)) {
                // Does Schema.DisplayType.Combobox work ? 
                for (Schema.PicklistEntry ple : f.getPicklistValues() ){
                   this.picklistOptions.add(new SelectOption(ple.getValue(), ple.getLabel()));
                }
            }
        }
    }

    public Column(String status) {
        this.label = this.apiName = this.localName = status;
        this.isDefault = false;
        this.isStatic = false;
        this.isField = false;
        this.picklistOptions = new List<SelectOption>();
    }

    public Column(String apiName, String label) {
        this.apiName = apiName;
        this.label = label;
        this.localName = label;
        this.isDefault = false;
        this.isStatic = false;
        this.isField = false;
        this.picklistOptions = new List<SelectOption>();
    }

    public Integer compareTo(Object compareTo) {
        Column compareToField = (Column) compareTo;
        if (this.label == compareToField.label) {
            return 0;
        } else if (this.label > compareToField.label) {
            return 1;
        } else {
            return -1;
        }
    }
}