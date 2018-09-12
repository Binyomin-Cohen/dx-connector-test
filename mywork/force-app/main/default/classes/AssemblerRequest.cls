public virtual with sharing class AssemblerRequest {
    public static final String SOAP_ENDPOINT = '/services/Soap/u/35.0';

    public static final String COMPONENT_HEADER_NAME = 'Component Name';
    public static final String COMPONENT_HEADER_TYPE = 'Type';
    public static final String COMPONENT_HEADER_PARENT = 'Parent Component';

    public List<List<String>> destructiveChangesPre;
    public List<List<String>> components;
    public String endpoint;
    public String orgId;
    public String buildId;
    public String sightlineRefreshToken;
    public String targetRefreshToken;
    public String clientId;
    public String clientSecret;
    public String targetEndpoint;
    public Boolean skipTargetBackup;

    public List<ProfilePermissions> profiles;

    public AssemblerRequest(Build__c build, Auth_User__c targetOAuth, Boolean skipTargetBackup) {

        this.orgId = UserInfo.getOrganizationId();

        this.buildId = build.Id;

        this.targetRefreshToken = targetOAuth.Refresh_Token__c;
        this.targetEndpoint = targetOAuth.Instance_URL__c + SOAP_ENDPOINT;


        Auth_User__c sightlineAuthUser = OAuthServices.getSightlineAuthUser();
        try {
            this.sightlineRefreshToken = sightlineAuthUser.Refresh_Token__c;
        } catch(Exception e) {
            throw new ALMException(System.Label.Sightline_Instance_Not_Authorized);
        }

        this.endpoint = sightlineAuthUser.Instance_URL__c;

        OAuthServices.AppSettings settings = OAuthServices.getAppSettings();
        this.clientId = settings.consumerKey;
        this.clientSecret = settings.consumerSecret;

        this.components = new List<List<String>>();
        this.destructiveChangesPre = new List<List<String>>();
        this.profiles = new List<ProfilePermissions>();
        this.skipTargetBackup = skipTargetBackup;
        loadManifest(build);
    }

    private void loadManifest(Build__c build) {
        components.add( new List<String>{ COMPONENT_HEADER_NAME, COMPONENT_HEADER_TYPE, COMPONENT_HEADER_PARENT,'Profile', 'Profile Permission' });
        destructiveChangesPre.add( new List<String>{ COMPONENT_HEADER_NAME, COMPONENT_HEADER_TYPE, COMPONENT_HEADER_PARENT });

        List<AssemblerManifestRecord> allComponents = retrieveComponentsToBuild(build);
        List<AssemblerManifestRecord> documentedComponents = new List<AssemblerManifestRecord>();
        Map<String, Set<String>> objectNameToFields = new Map<String, Set<String>>();

        Set<String> profilesToIncludeDocumentedComponents = new Set<String>();
        for (AssemblerManifestRecord component : allComponents ) {
            if(component instanceof ProfileManifestRecord
                && component.getBuildComponent().Type__c != AssemblerManifestRecord.REMOVED
                && !((ProfileManifestRecord)component).includeEntireProfile)
            {
                if (((ProfileManifestRecord)component).includeOnlyDocumentedComponents){
                    profilesToIncludeDocumentedComponents.add( ((ProfileManifestRecord)component).profileName );
                }
                profiles.add( ProfilePermissions.valueOf(
                    ((ProfileManifestRecord)component).selectedPermissions)
                );
            } else if (component.getBuildComponent().Type__c == AssemblerManifestRecord.DOCUMENTED
                    || component.getIsUndocumented()) {

                if (component.isDeletion) {
                    destructiveChangesPre.add(new List<String> { component.getName(), component.getType(), component.getParent() });
                } else {
                    components.add( new List<String> { component.getName(), component.getType(), component.getParent(), '', '0' });
                    if (!(component instanceof ProfileManifestRecord)){
                        documentedComponents.add(component);
                    }
                    if (component.getType() == ComponentServices.FIELD_ALM_NAME) {
                        mapFieldByObjectName(objectNameToFields, component);
                    }
                }
            }
        }

        Map<String, Set<String>> documentedComponentMap = ProfileServices.filterComponents(documentedComponents);
        for (ProfilePermissions profile : profiles) {
            if (profilesToIncludeDocumentedComponents.contains(profile.Name)){
                profile.selectPermissions(documentedComponentMap);
            }
            profile.expandFLS(objectNameToFields);
        }
    }

    /**
    *   Retrieves all saved components from the build
    * @param  build   the build to retrieve components from
    */
    protected virtual List<AssemblerManifestRecord> retrieveComponentsToBuild(Build__c build) {
        return AssemblerServices.getManifestByBuildId(build.Id);
    }

    private void mapFieldByObjectName(Map<String, Set<String>> objectNameToFields, AssemblerManifestRecord component) {
        if (!objectNameToFields.containsKey(component.getParent())) {
            objectNameToFields.put(component.getParent(), new Set<String>());
        }
        String apiName = ProfileTemplate.getApiName(component.getName(), component.getType(), component.getParent());
        objectNameToFields.get(component.getParent()).add(apiName);
    }
}