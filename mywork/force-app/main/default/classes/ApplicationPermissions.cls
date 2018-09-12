public interface ApplicationPermissions {
    PermissionServices.PermissionLevel hasPermission();
    
    Boolean hasFLSPermissions();
    
    Boolean hasObjectPermissions();
    
    Boolean hasRecordTypePermissions();
}