public with sharing class GitController extends OAuthController {
    public String backlogItemId {get; set;}
    public String backlogItemName {get; set;}
    public String instanceId {get; set;}
    public static String SUCCESS_COMMIT_MESSAGE = 'Your commit request was submitted succesfully.';

    @TestVisible
    private static final String PAGE_STATE_TOKEN = 'PageState GitController';

    public GitController(ApexPages.StandardSetController controller) {
        setPageContext();
    }

    @AuraEnabled
    public static List<RepositoryResult> retrieveRepos() {
        List<RepositoryResult> results = new List<RepositoryResult>();
        for (VC_Repository__c vcRepository : [ SELECT Id, Repository_URL__c, Source_Format__c, Name FROM VC_Repository__c]) {
            results.add(new RepositoryResult(vcRepository));
        }
        return results;
    }

    @AuraEnabled
    public static List<String> retrieveBranches(String repositoryId) {
        try {
            VCServices.GitListResponse response = VCServices.gitListBranches(UserInfo.getUserId(), repositoryId, false);

            if (response.isSuccess) {
                return response.references;
            } else {
                throw new AuraHandledException(response.failureReason);
            }
        } catch (AuraHandledException e) {
            //In order to preserve the message, handle any aura exceptions separately
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private Boolean setPageContext() {
        String backlogId = ApexPages.currentPage().getParameters().get('id');
        //@TODO need to get the instanceId from the state
        //String instanceId = ApexPages.currentPage().getParameters().get('id');
        Backlog__c backLogFromPageParams = BacklogItemServices.getBacklogRecord( backlogId );
        if( backLogFromPageParams == null )
            return false;
        backlogItemId = backLogFromPageParams.Id;
        backlogItemName = backLogFromPageParams.Name;
        return PermissionServices.checkPagePermissions(new GitCommitPermissions()) == PermissionServices.PermissionLevel.FULL;
    }

    @AuraEnabled
    public static List<Instances__c> getInstances() {
        return InstanceServices.getAllInstances();
    }

    public class RepositoryResult {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String repoURL;

        public RepositoryResult(VC_Repository__c repo) {
            this.id = repo.Id;
            this.name = repo.Name;
            this.repoURL = repo.Repository_URL__c;
        }
    }

    @AuraEnabled
    public static PageMessage makeCommitRequest(String vcCommitId) {
        VC_Commit__c vcCommit = [SELECT Backlog_Item__c, Backlog_Components__c, Branch_Name__c, Commit_Message__c, VC_Repository__c,
                                       Response_Message__c, Source_Instance__c, Status__c, CreatedBy.Username
                                   FROM VC_Commit__c
                                   WHERE Id=:vcCommitId];
        try {
            // TODO: makeCommitRequest should just take an Id
            VCServices.makeCommitRequest(vcCommit);
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return new PageMessage(ApexPages.Severity.CONFIRM, SUCCESS_COMMIT_MESSAGE);
    }

    @AuraEnabled
    public static String saveCommitRequest(String commitRequestJSON) {
        CommitRequest request;
        try {
            request = (CommitRequest) JSON.deserialize(commitRequestJSON, CommitRequest.class);
            VC_Commit__c vcCommit = request.buildVCCommitObject();
            insert vcCommit;
            return vcCommit.Id;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class CommitRequest {
        @AuraEnabled
        public String backlogItemId;
        @AuraEnabled
        public List<String> backlogComponentIds;
        @AuraEnabled
        public String repositoryId;
        @AuraEnabled
        public String branchName;
        @AuraEnabled
        public String commitMessage;
        @AuraEnabled
        public String instanceId;

        public CommitRequest(String backlogItemId, List<String> backlogComponentIds, String repositoryId,
                             String branchName, String commitMessage, String instanceId) {
            this.backlogItemId = backlogItemId;
            this.backlogComponentIds = backlogComponentIds;
            this.repositoryId = repositoryId;
            this.branchName = branchName;
            this.commitMessage = commitMessage;
            this.instanceId = instanceId;
        }

        public VC_Commit__c buildVCCommitObject() {
            String backlogComponentIdsString = String.join(backlogComponentIds, ',');

            return new VC_Commit__c(Backlog_Components__c=backlogComponentIdsString, Backlog_Item__c=this.backlogItemId,
                                     Branch_Name__c=this.branchName, Commit_Message__c=this.commitMessage,
                                     VC_Repository__c=this.repositoryId, Source_Instance__c=instanceId);
        }
    }

    /**
    * Saves the current state of the user inputs on the page.
    * @param backlogItemId - The ID of the relevant backlog item.
    * @param pageStateMap - A map representing the current state of the user inputs on the page.
    */
    @AuraEnabled
    public static void savePageState(String backlogItemId, Map<String, Object> pageStateMap) {
        if (pageStateMap != null) {
            State.store(new PageState(constructPageStateToken(backlogItemId), pageStateMap));
        }
    }

    /**
    * Loads any existing saved state of the user inputs on the page.
    * @param backlogItemId - The ID of the relevant backlog item.
    * @return pageStateMap - A map representing any existing saved state of the user inputs on the page.
    */
    @AuraEnabled
    public static Map<String, Object> loadPageState(String backlogItemId) {
        PageState stateInstance = new PageState(constructPageStateToken(backlogItemId));

        try {
            State.retrieve(stateInstance);
        } catch (State.StateException se) {
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return stateInstance.stateMap;
    }

    /**
    * Expires any existing saved state of the user inputs on the page.
    * @param backlogItemId - The ID of the relevant backlog item.
    */
    @AuraEnabled
    public static void expirePageState(String backlogItemId) {
        new PageState(constructPageStateToken(backlogItemId)).expire();
    }

    /**
    * Constructs the state application token for the page state. This is used when saving/loading existing page state.
    * @param backlogItemId - The ID of the relevant backlog item.
    */
    public static String constructPageStateToken(String backlogItemId) {
        return PAGE_STATE_TOKEN + State.STATE_TOKEN_DELIM + backlogItemId;
    }
}
