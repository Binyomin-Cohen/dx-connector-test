public with sharing class DXCreateScratchOrgRequest extends BaseRequest {
    public String devHubServerUrl;
    public String devHubRefreshToken;
    public String pmScratchOrgId;
    public VersionControlSource versionControlSource;
    public Integer durationDays;
    public String newBranchName;
    public Map<String, Object> scratchOrgDefinition;

    //holds all String fields
    public static final Map<Schema.sObjectField, String> SCRATCH_DEF_FIELDS_TO_KEYS = new Map<Schema.sObjectField, String> {
        Schema.Scratch_Org_Definition__c.Admin_Email__c => 'adminEmail',
        Schema.Scratch_Org_Definition__c.Country__c => 'country',
        Schema.Scratch_Org_Definition__c.Description__c => 'description',
        Schema.Scratch_Org_Definition__c.Edition__c => 'edition',
        Schema.Scratch_Org_Definition__c.Language__c => 'language',
        Schema.Scratch_Org_Definition__c.Org_Name__c => 'orgName',
        Schema.Scratch_Org_Definition__c.Username__c => 'username'
    };

    public static final Map<Schema.sObjectField, String> SCRATCH_DEF_OTHER_FIELDS_MAPPING = new Map<Schema.sObjectField, String> {
        Schema.Scratch_Org_Definition__c.Disabled_Org_Preferences__c => 'disabled',
        Schema.Scratch_Org_Definition__c.Enabled_Org_Preferences__c => 'enabled',
        Schema.Scratch_Org_Definition__c.Has_Sample_Data__c => 'hasSampleData',
        Schema.Scratch_Org_Definition__c.Features__c => 'features'
    };
    public static final STRING ORG_PREFERENCES = 'orgPreferences';

    public DXCreateScratchOrgRequest() {
        super();
    }

    public DXCreateScratchOrgRequest(String devHubServerUrl, String devHubRefreshToken, Scratch_Org__c scratchOrg,
                                     Scratch_Org_Definition__c scratchOrgDef) {
        super();
        this.devHubServerUrl = devHubServerUrl;
        this.devHubRefreshToken = devHubRefreshToken;
        this.pmScratchOrgId = scratchOrg.Id;
        this.durationDays = (Integer)scratchOrg.Duration_Days__c;
        this.newBranchName = isCreatingNewBranch(scratchOrg) ? scratchOrg.Repository_Location__c : null;

        // taken from VCCommitRequest - pull into common method
        List<VC_Repository__c> repos = [
            SELECT Repository_URL__c, SFDC_Metadata_Path__c, Source_Format__c
                FROM VC_Repository__c
                WHERE Id = :scratchOrg.VC_Repository__c ];
        VC_Repository__c repo;
        if (repos.size() > 0) {
            repo = repos[0];
        } else {
            throw new ALMException(System.Label.VC_Repository_Retrieval_Error);
        }

        if (String.isBlank(repo.Repository_URL__c)) {
            throw new ALMException(VCServices.NO_REPOSITORY_URL_ERROR);
        }
        String locationToClone = isCreatingNewBranch(scratchOrg) ? scratchOrg.Parent_Branch_Name__c : scratchOrg.Repository_Location__c;
        this.versionControlSource = new VersionControlSource(repo, locationToClone);
        this.scratchOrgDefinition = createScratchOrgDefinitionMap(scratchOrgDef);
    }

    public static Boolean isCreatingNewBranch(Scratch_Org__c scratchOrg) {
        return scratchOrg.Parent_Branch_Name__c != null;
    }

    /**
    * Creates a map of all populated Scratch_Org_Definition__c values for use in JSON serialization
    */
    public static Map<String, Object> createScratchOrgDefinitionMap(Scratch_Org_Definition__c scratchOrgDef) {
        
        Map<String, Object> definedValues = new Map<String, Object>();

        if (scratchOrgDef == null) {
            return definedValues;
        }

        for (Schema.sObjectField field : SCRATCH_DEF_FIELDS_TO_KEYS.keySet()) {
            String value = (String)scratchOrgDef.get(field);
            if (String.isNotEmpty(value)) {
                definedValues.put(SCRATCH_DEF_FIELDS_TO_KEYS.get(field), value);
            }
        }
        
        //handle non string types
        
        if (scratchOrgDef.Has_Sample_Data__c) {
            definedValues.put(SCRATCH_DEF_OTHER_FIELDS_MAPPING.get(Schema.Scratch_Org_Definition__c.Has_Sample_Data__c),
                scratchOrgDef.Has_Sample_Data__c);
        }

        if (String.isNotEmpty(scratchOrgDef.Features__c)) {
            definedValues.put(SCRATCH_DEF_OTHER_FIELDS_MAPPING.get(Schema.Scratch_Org_Definition__c.Features__c),
                 getListFromMultiSelectValue(scratchOrgDef.Features__c));
        }

        if (String.isNotEmpty(scratchOrgDef.Enabled_Org_Preferences__c) || 
            String.isNotEmpty(scratchOrgDef.Disabled_Org_Preferences__c)) {
            
            Map<String, List<String>> orgPrefs = new Map<String, List<String>> {
                SCRATCH_DEF_OTHER_FIELDS_MAPPING.get(Schema.Scratch_Org_Definition__c.Enabled_Org_Preferences__c) 
                    => getListFromMultiSelectValue(scratchOrgDef.Enabled_Org_Preferences__c),
                SCRATCH_DEF_OTHER_FIELDS_MAPPING.get(Schema.Scratch_Org_Definition__c.Disabled_Org_Preferences__c)
                    => getListFromMultiSelectValue(scratchOrgDef.Disabled_Org_Preferences__c)
            };
            definedValues.put(ORG_PREFERENCES, orgPrefs);
        }

        return definedValues;
    }

    private static List<String> getListFromMultiSelectValue(String value) {
        return String.isEmpty(value) ? new List<String>() : value.split(';');
    }
}
