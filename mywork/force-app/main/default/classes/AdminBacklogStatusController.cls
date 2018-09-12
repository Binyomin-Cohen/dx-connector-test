public with sharing class AdminBacklogStatusController {

    public List<String> activeStatuses {get; set;}
    public List<String> inactiveStatuses {get; set;}
    public Boolean hasPermissions {get; set;}

    public AdminBacklogStatusController() {
        hasPermissions = PermissionServices.checkPagePermissions(new AdminBacklogPermissions()) == PermissionServices.PermissionLevel.FULL;
        inactiveStatuses =  new List<String>(BacklogItemServices.getInactiveStatuses());

        Set<String> allStatuses = new Set<String>(AssemblerServices.getBacklogStatuses().keySet());

        for(String inactiveStatus : inactiveStatuses) {
            allStatuses.remove(inactiveStatus);
        }

        activeStatuses = new List<String>(allStatuses);
        activeStatuses.sort();
        inactiveStatuses.sort();
    }

    /**
    * @throws ALMException
    */
    @RemoteAction
    public static void saveInactiveStatuses(List<String> inactiveStatuses) {
        try {
            BacklogItemServices.saveInactiveStatuses(inactiveStatuses);
        } catch(System.DMLException de) {
            throw new ALMException('An error occured updating the inactive statuses: '+ de.getMessage() );
        }
    }
}