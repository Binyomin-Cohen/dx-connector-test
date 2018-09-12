public with sharing class AdminBacklogPrioritizationColsCont {

    public BacklogPrioritizationColumnConfig columnConfig { get; set; }
    public Boolean hasPermissions {get; set;}

    public AdminBacklogPrioritizationColsCont() {
        columnConfig = new BacklogPrioritizationColumnConfig();
        hasPermissions = PermissionServices.checkPagePermissions(new AdminBacklogPermissions()) == PermissionServices.PermissionLevel.FULL;
    }

    /**
    * @throws ALMException
    */
    @RemoteAction
    public static void saveColumns(List<String> fieldNames) {
        BacklogItemServices.savePrioritizationFields(fieldNames);
    }
}