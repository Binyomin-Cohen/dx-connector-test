public with sharing class AdminSprintLanesController {

    public SprintColumnConfig columnConfig { get; set; }
    public Boolean hasPermissions {get; set;}
    
    public AdminSprintLanesController() {
        columnConfig = new SprintColumnConfig();
        hasPermissions = PermissionServices.checkPagePermissions(new AdminSprintPermissions()) == PermissionServices.PermissionLevel.FULL;
    }
    
    /**
    * @throws ALMException
    */
    @RemoteAction
    public static void saveColumns(List<String> statuses) {
        SprintServices.saveSprintLanes(statuses);
    }
    
}