public with sharing class CustomMetadataServices {
    /**
    * Deploys a custom metadata type to the org.
    * @param customMetadataTypeName - The full API name of the custom metadata type (without the "__mdt" suffix).
    * @param customMetadataRecordLabel - The label of the custom metadata type record.
    * @param customMetadataFieldToValueMap - A map of fields to values of custom metadata values to add to the custom metadata record.
    * @param callback - The callback handler for the asynchronous custom metadata type deployment.
    */
    public static void deployCustomMetadata(String customMetadataTypeName, String customMetadataRecordLabel, Map<String, Object> customMetadataFieldToValueMap, Metadata.DeployCallback callback) {
        List<Metadata.CustomMetadataValue> customMetadataValues = buildCustomMetadataValues(customMetadataFieldToValueMap);

        deployCustomMetadata(customMetadataTypeName, customMetadataRecordLabel, customMetadataValues, callback);
    }

    /**
    * Deploys a custom metadata type to the org.
    * @param customMetadataTypeName - The full API name of the custom metadata type (without the "__mdt" suffix).
    * @param customMetadataRecordLabel - The label of the custom metadata type record.
    * @param customMetadataValues - A collection of custom metadata values to add to the custom metadata record.
    * @param callback - The callback handler for the asynchronous custom metadata type deployment.
    */
    public static void deployCustomMetadata(String customMetadataTypeName, String customMetadataRecordLabel, List<Metadata.CustomMetadataValue> customMetadataValues, Metadata.DeployCallback callback) {
        Metadata.CustomMetadata customMetadata = buildCustomMetadata(customMetadataTypeName, customMetadataRecordLabel, customMetadataValues);

        deployCustomMetadata(customMetadata, callback);
    }

    /**
    * Deploys a custom metadata type to the org.
    * @param customMetadata - The custom metadata type to deploy to the org.
    * @param callback - The callback handler for the asynchronous custom metadata type deployment.
    */
    public static void deployCustomMetadata(Metadata.CustomMetadata customMetadata, Metadata.DeployCallback callback) {
        Metadata.DeployContainer customMetadataContainer = new Metadata.DeployContainer();
        customMetadataContainer.addMetadata(customMetadata);

        Metadata.Operations.enqueueDeployment(customMetadataContainer, callback);
    }

    /**
    * Builds a custom metadata object with custom metadata values.
    * @param customMetadataTypeName - The full API name of the custom metadata type (without the "__mdt" suffix).
    * @param customMetadataRecordLabel - The label of the custom metadata type record.
    * @param customMetadataFieldToValueMap - A map of fields to values of custom metadata values to add to the custom metadata record.
    * @return The new custom metadata object.
    */
    public static Metadata.CustomMetadata buildCustomMetadata(String customMetadataTypeName, String customMetadataRecordLabel, Map<String, Object> customMetadataFieldToValueMap) {
        List<Metadata.CustomMetadataValue> customMetadataValues = buildCustomMetadataValues(customMetadataFieldToValueMap);
        Metadata.CustomMetadata customMetadata = buildCustomMetadata(customMetadataTypeName, customMetadataRecordLabel, customMetadataValues);

        return customMetadata;
    }

    /**
    * Builds a custom metadata object with custom metadata values.
    * @param customMetadataTypeName - The full API name of the custom metadata type (without the "__mdt" suffix).
    * @param customMetadataRecordLabel - The label of the custom metadata type record.
    * @param customMetadataValues - A collection of custom metadata values to add to the custom metadata record.
    * @return The new custom metadata object.
    */
    public static Metadata.CustomMetadata buildCustomMetadata(String customMetadataTypeName, String customMetadataRecordLabel, List<Metadata.CustomMetadataValue> customMetadataValues) {
        Metadata.CustomMetadata customMetadata = buildCustomMetadata(customMetadataTypeName, customMetadataRecordLabel);
        customMetadata.values.addAll(customMetadataValues);

        return customMetadata;
    }

    /**
    * Builds a custom metadata object.
    * @param customMetadataTypeName - The full API name of the custom metadata type (without the "__mdt" suffix).
    * @param customMetadataRecordLabel - The label of the custom metadata type record.
    * @return The new custom metadata object.
    */
    public static Metadata.CustomMetadata buildCustomMetadata(String customMetadataTypeName, String customMetadataRecordLabel) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        customMetadata.fullName = SObjectServices.getFullyQualifiedName(customMetadataTypeName + '.' + customMetadataRecordLabel);
        customMetadata.label = customMetadataRecordLabel;

        return customMetadata;
    }

    /**
    * Builds custom metadata values.
    * @param customMetadataFieldToValueMap - A map of fields to values of the custom metadata value.
    * @return The new custom metadata value.
    */
    public static List<Metadata.CustomMetadataValue> buildCustomMetadataValues(Map<String, Object> customMetadataFieldToValueMap) {
        List<Metadata.CustomMetadataValue> customMetadataValues = new List<Metadata.CustomMetadataValue>();
        for (String field : customMetadataFieldToValueMap.keySet()) {
            customMetadataValues.add(buildCustomMetadataValue(field, customMetadataFieldToValueMap.get(field)));
        }

        return customMetadataValues;
    }

    /**
    * Builds a custom metadata value.
    * @param field - The field name of the custom metadata value.
    * @param value - The value of the custom metadata value.
    * @return The new custom metadata value.
    */
    public static Metadata.CustomMetadataValue buildCustomMetadataValue(String field, Object value) {
        Metadata.CustomMetadataValue customMetadataValue = new Metadata.CustomMetadataValue();
        customMetadataValue.field = SObjectServices.getFullyQualifiedName(field);
        customMetadataValue.value = value;

        return customMetadataValue;
    }
}