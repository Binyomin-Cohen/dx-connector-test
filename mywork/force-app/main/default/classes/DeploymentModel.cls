public with sharing class DeploymentModel {

    public static final String DEFAULT_TEST_LEVEL = 'Default';
    public static final String FAILED_BUILD_STATUS = 'Failed';
    public static final Integer QUICK_DEPLOY_MAX_AGE = 240;

    public Attempt deploymentAttempt;
    public Deployment__c record;

    public Boolean isValidation;
    public Boolean isDeploy;
    public Boolean isSuccess;
    public Boolean isInProgress;
    public Boolean isManualUpload;
    public Boolean isQuickDeployEligible;
    public String sourceInstanceName;
    public String targetInstanceName;
    public String lastModifiedDate;
    public Integer totalBuildErrors;
    public String buildStatus;
    public Integer codeCoverage;
    public String buildPackageUrl;
    public String backupPackageUrl;
    @TestVisible
    private Integer codeCoverageErrorCount;

    public DeploymentModel(Deployment__c deployment, Deployment_Attempt__c deploymentAttempt) {
        this(deployment, deploymentAttempt, 0);
    }

    public DeploymentModel(Deployment__c deployment, Deployment_Attempt__c deploymentAttempt, Integer codeCoverageErrorCount) {
        this.record = deployment;
        Datetime deploymentEndDate;
        this.codeCoverageErrorCount = codeCoverageErrorCount;
        if (deploymentAttempt == null) {
            this.isValidation = false;
            this.isDeploy = false;
            this.isSuccess = false;
            this.isInProgress = false;
        } else {
            this.deploymentAttempt = new Attempt(deploymentAttempt, codeCoverageErrorCount);
            this.isValidation = deploymentAttempt.Is_Validation__c;
            this.isDeploy = !deploymentAttempt.Is_Validation__c;
            this.isSuccess = deploymentAttempt.Status__c == DeploymentServices.STATUS_SUCCESS ? true : false;
            this.isInProgress = (this.deploymentAttempt.inProgress || this.deploymentAttempt.isPending || this.deploymentAttempt.isNotStarted);
            this.codeCoverage = (deploymentAttempt.Total_Code_Coverage__c == null) ? null : deploymentAttempt.Total_Code_Coverage__c.intValue();
            deploymentEndDate = deploymentAttempt.End_Date__c;
        }

        buildPackageUrl = deployment.Build__r.Package_URL__c;
        backupPackageUrl = deployment.Build__r.Backup_URL__c;
        lastModifiedDate = deployment.LastModifiedDate.format();
        this.isManualUpload = (deployment.Build__c == null) ? false : deployment.Build__r.Manual_Upload__c;

        setSourceInstanceName();
        this.targetInstanceName = (deployment.Target__c == null ? '' : deployment.Target__r.Name);
        this.buildStatus = deployment.Build__r.Status__c;
        setIsQuickDeployEligible(deploymentEndDate);
    }

    public DeploymentModel(Deployment__c deployment, Deployment_Attempt__c deploymentAttempt, Integer codeCoverageErrorCount, Integer numErrors) {
        this(deployment, deploymentAttempt, codeCoverageErrorCount);
        this.totalBuildErrors = (numErrors == null ? 0 : numErrors);
        this.isSuccess = getIsSuccess();
    }

    private void setSourceInstanceName() {
        if (record.Source__c != null) {
            this.sourceInstanceName = record.Source__r.Name;
        } else if (record.Build__r.Source_Repository__c != null) {
            this.sourceInstanceName = record.Build__r.Source_Repository__r.Name;
        } else {
            this.sourceInstanceName = '';
        }
    }

    private void setIsQuickDeployEligible(Datetime endDate) {
        if (isSuccess && isValidation
             && codeCoverage != null && codeCoverage >= 75
             && !deploymentAttempt.hasComponentErrors
             && !deploymentAttempt.hasTestErrors
             && deploymentAttempt.hasRanTests
             && endDate >= Datetime.now().addHours(-QUICK_DEPLOY_MAX_AGE)
             && codeCoverageErrorCount == 0 
             ) {
            isQuickDeployEligible = true;
        } else {
            isQuickDeployEligible = false;
        }
    }

    private Boolean getIsSuccess() {
        if (this.totalBuildErrors > 0 || FAILED_BUILD_STATUS.equalsIgnoreCase(this.buildStatus)) {
            return false;
        } else if(this.deploymentAttempt != null &&
                (this.deploymentAttempt.hasComponentErrors ||
                this.deploymentAttempt.hasTestErrors ||
                this.deploymentAttempt.hasCodeCoverageErrors))
        {
            return false;
        }

        return true;
    }

    public class Attempt {
        public final String NOT_APPLICABLE = 'N/A';
        public final String NOT_RAN = 'NOT RAN';
        public final String RESULT_PASS = 'pass';
        public final String RESULT_FAIL = 'fail';
        public final String RESULT_CANCELED = 'canceled';

        public Deployment_Attempt__c record {get; set;}
        public String deploymentType {get; set;}
        public String endTime {get; set;}
        public String sfDeploymentId {get; set;}
        public String startTime {get; set;}
        public String status {get; set;}
        public String targetInstance {get; set;}
        public String lastModifiedDate {get; set;}
        public Boolean isPending {get; set;}
        public Boolean inProgress {get; set;}
        public Boolean isNotStarted {get; private set;}
        public Boolean isQuickDeploy {get; private set;}
        public Boolean hasComponentErrors {get; set;}
        public Boolean hasTestErrors {get; set;}
        public Boolean hasRanTests {get; set;}
        public Boolean hasCodeCoverageErrors {get; set;}

        public String deploymentStatus {
            get {
                if(record.Status__c == 'Succeeded') {
                    return 'Successful';
                } else if(record.Status__c == 'Pending') {
                    return 'Pending';
                } else if(record.Status__c == 'Failed') {
                    return 'Failed';
                } else if(record.Status__c == 'InProgress') {
                    return 'In Progress';
                } else if(record.Status__c == 'Canceled') {
                    return 'Canceled';
                } else {
                    return 'Unknown';
                }
            }
        }
        public String codeCoverage {get; set;}
        public String apexTestsTotal { get; set; }
        public Decimal numberComponentsErrors { get; set; }
        public Decimal numberTestsErrors { get; set; }
        public Decimal totalLines { get; set; }
        public Decimal numberComponentsTotal { get; set; }
        public String componentResult {get; set;}
        public String apexResult {get; set;}
        public String assembleRequestError { get; set; }

        public Attempt(Deployment_Attempt__c deployment) {
            this(deployment, 0);
        }

        public Attempt(Deployment_Attempt__c deployment, Integer codeCoverageErrorCount) {
            this.record = deployment;
            if (record.Start_Date__c != null) {
                this.startTime = record.Start_Date__c.format();
            }
            if (record.End_Date__c != null) {
                this.endTime = record.End_Date__c.format();
            }
            if (record.Status__c != null) {
                status = record.Status__c.replaceAll(' ','').toLowerCase();
            }

            if (record.Status__c == DeploymentServices.STATUS_FAILED ||
                  record.Status__c == DeploymentServices.STATUS_SUCCESS ||
                    record.Status__c == DeploymentServices.STATUS_CANCELED) {
                hasCodeCoverageErrors = (codeCoverageErrorCount > 0);
            } else {
                hasCodeCoverageErrors = false;
            }
            setQuickDeployResults();

            lastModifiedDate = record.LastModifiedDate.format();
            sfDeploymentId = record.SF_Deployment_Id__c;
            targetInstance = record.Target_Instance__r.Name;
            deploymentType = (deployment.Is_Validation__c) ? 'validation' : 'deployment';
            isPending = (String.isBlank(record.Status__c) || record.Status__c == DeploymentServices.STATUS_PENDING);
            inProgress = (isPending || record.Status__c == DeploymentServices.STATUS_IN_PROGRESS || record.Status__c == 'In Progress');
            isNotStarted = (record.Status__c == DeploymentServices.STATUS_NOT_STARTED);
            numberComponentsTotal = record.Number_Components_Total__c != null ? record.Number_Components_Total__c : 0;
            numberTestsErrors = record.Number_Test_Errors__c != null ? record.Number_Test_Errors__c : 0;
            hasTestErrors = (numberTestsErrors > 0);
            numberComponentsErrors = record.Number_Components_Errors__c != null ? record.Number_Components_Errors__c : 0;
            hasComponentErrors = (numberComponentsErrors > 0) || (record.Status__c == DeploymentServices.STATUS_FAILED && !hasTestErrors && !hasCodeCoverageErrors);
            totalLines = record.Total_Lines__c != null ? record.Total_Lines__c : 0;

            hasRanTests = totalLines > 0;

            if (hasRanTests) {
                codeCoverage = record.Total_Code_Coverage__c + '';
            } else {
                codeCoverage = NOT_APPLICABLE;
            }
            apexTestsTotal = record.Number_Tests_Total__c == null ? '0' : record.Number_Tests_Total__c + '';

            if (status == RESULT_CANCELED) {
                if (Integer.valueOf(apexTestsTotal) == 0) {
                    componentResult = RESULT_CANCELED;

                    // Set apex result to in-progress to display the gray vertial bar image
                    apexResult = 'in-progress';
                } else {
                    componentResult = (hasComponentErrors) ? RESULT_FAIL : RESULT_PASS;
                    apexResult = RESULT_CANCELED;
                }
            } else {
                componentResult = (hasComponentErrors) ? RESULT_FAIL : RESULT_PASS;
                apexResult = (hasTestErrors) ? RESULT_FAIL : RESULT_PASS;
            }

            assembleRequestError = deployment.Assemble_Request_Error__c;
            if (!String.isBlank(assembleRequestError)) {
                componentResult = NOT_APPLICABLE;
                apexTestsTotal = NOT_APPLICABLE;
                codeCoverage = NOT_APPLICABLE;
            }
        }

        private void setQuickDeployResults() {
            isQuickDeploy = record.Is_Quick_Deploy__c;
            if (isQuickDeploy) {
                 Deployment_Attempt__c quickDeployAttempt =
                     DeploymentServices.getQuickDeployValidationAttempt(record.Deployment__c);

                 if (quickDeployAttempt != null) {
                     record.Number_Tests_Total__c = quickDeployAttempt.Number_Tests_Total__c;
                     record.Total_Lines__c = quickDeployAttempt.Total_Lines__c;
                     record.Total_Code_Coverage__c = quickDeployAttempt.Total_Code_Coverage__c;
                     record.Test_Level__c = quickDeployAttempt.Test_Level__c;
                 }
            }
        }
    }

}