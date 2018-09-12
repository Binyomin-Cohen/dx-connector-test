public with sharing class GeneratePackageRequest {
    public static final Double DEFAULT_VERSION = 39.0;

    public static final String COMPONENT_HEADER_NAME = 'Component Name';
    public static final String COMPONENT_HEADER_TYPE = 'Type';
    public static final String COMPONENT_HEADER_PARENT = 'Parent Component';

    public List<List<String>> components;
    public String orgId;
    public Double version;

    public GeneratePackageRequest(List<AssemblerManifestRecord> releaseManifest) {
        orgId = UserInfo.getOrganizationId();
        version = DEFAULT_VERSION;

        components = new List<List<String>>();
        components.add(new List<String>{ COMPONENT_HEADER_NAME, COMPONENT_HEADER_TYPE, COMPONENT_HEADER_PARENT });
        for (AssemblerManifestRecord component : releaseManifest) {
            components.add(new List<String>{ component.getName(), component.getType(), component.getParent() });
        }
    }
}