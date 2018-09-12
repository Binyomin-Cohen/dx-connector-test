public class BuildModel {

    public Build__c record;
    public String buildStatus;
    public String webAssemblerFailureMessage;
    public String buildStage;
    public Integer componentsRetrieved;
    public Integer componentsTotal;

    public BuildModel(Build__c build){
        this.record = build;
        if (build != null){
            this.buildStatus = build.Status__c;
            if (!build.Deployment_Attempts__r.isEmpty()){
                this.webAssemblerFailureMessage = build.Deployment_Attempts__r[0].Assemble_Request_Error__c;
            }
        }
    }

    public BuildModel (Build__c build, AssemblerServices.BuildStatus buildStatus) {
        this(build);
        if (build != null && buildStatus != null) {
            this.buildStatus = buildStatus.status;
            if (String.isNotBlank(buildStatus.failureReason)) {
                webAssemblerFailureMessage = buildStatus.failureReason;
            }
            this.buildStage = buildStatus.buildStage;
            this.componentsRetrieved = buildStatus.componentsRetrieved;
            this.componentsTotal = buildStatus.componentsTotal;
        }
    }

    /**
    * Saves the Build__c and related Deployent_Attempt__c if there are unsaved changes
    * @throws DMLExeption
    */
    public void save() {

        System.savepoint sp = Database.setSavepoint();

        if (record.Status__c != buildStatus) {
            record.Status__c = buildStatus;
            update record;
        }

        if (!record.Deployment_Attempts__r.isEmpty()) {
            Deployment_Attempt__c attempt = record.Deployment_Attempts__r[0];

            if (attempt.Assemble_Request_Error__c != webAssemblerFailureMessage) {
                attempt.Assemble_Request_Error__c = webAssemblerFailureMessage;

                try {
                    update attempt;
                } catch (DMLException de) {
                    Database.rollback(sp);
                    throw de;
                }
            }
        }
    }
}