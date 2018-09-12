/**
* @author Vivek
* @date 8th Sep, 2017
*
* @group <Salesforce Garage>
*
* @description Batch Job to keep polling jenkins and check for status of the job
*/

public class JenkinsBuildBatchJob implements Database.Batchable<SObject>, Database.AllowsCallouts,Schedulable {
    
    public static final String PATH_DELIMITER = '/';
    public static final String BATCH_JOB_TITLE = 'Jenkins Build Status Job';
    @TestVisible private String query;
    public static Integer SCOPE_SIZE = 5;
    public static final String MAX_CALLOUTS_MSG = 'Unable to make callout in JenkinsBuildBatchJob. ' +
        'The max number of callouts has been reached: ' + Limits.getLimitCallouts();
    public static final Integer INTERVAL_IN_MINUTES=2;
    public static final String EXCEPTION_MSG='Exception';
    public static final String JENKINS_SUCCESS='SUCCESS';
    public static final String JENKINS_FAILURE='FAILURE';
    public static final String SPLIT_DELIMITER = ';';
    public static final String JENKINS_INPROGRESS='IN PROGRESS';
    public static final String JENKINS_PENDING='PENDING';
    public static final String JENKINS_ULR_PARAMTER='\']]&wrapper=parametername';
    public static final String XML_RESPONSE_TAG_NUMBER='number';
    public static final String XML_RESPONSE_TAG_RESULT='result';
    
    public JenkinsBuildBatchJob(){
        this.query='Select ID,Name,Status__c,Jenkins_Job__r.Path__c from Jenkins_Build__c where Status__c=:JENKINS_PENDING OR Status__c=:JENKINS_INPROGRESS' ;
    }
    
    /**
    * @description Initializes the batch querying process
    * @param Database.BatchableContext bc
    * @return Database.QueryLocator
    */
    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);  
    }
    
    /**
    * @description Executes the Jenkins Build record to check for status of build
    * @param Database.BatchableContext bc
    * @param Jenkins_Build__c[] scope
    */
    public void execute(Database.BatchableContext BC, List<Jenkins_Build__c > scope){
        Set<Id> jobIds = new Set<Id>();
        List<Jenkins_Build__c>jenkisBuildList= new List<Jenkins_Build__c>();
        Jenkins_Config__c jenkinsConfig = Jenkins_Config__c.getInstance();
        Map<String, String> headerMap = new Map<String, String>();
        headerMap.put('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(jenkinsConfig.User_ID__c + ':' + jenkinsConfig.User_API_Token__c)));
        String endpoint = 
            jenkinsConfig.Endpoint__c.endsWith(PATH_DELIMITER) ?
            jenkinsConfig.Endpoint__c :
        jenkinsConfig.Endpoint__c + PATH_DELIMITER;          
        for(Jenkins_Build__c  j: scope){
            List<String>jenkinsResponse= new List<String>();
            String response;
            String path =
                j.Jenkins_Job__r.Path__c.endsWith(PATH_DELIMITER) ?
                j.Jenkins_Job__r.Path__c :
            j.Jenkins_Job__r.Path__c + PATH_DELIMITER;
         
            String finalEndpoint=endpoint+path+System.label.Jenkins_Build_Status_URL+j.Name+JENKINS_ULR_PARAMTER;
            if (LimitServices.getRemainingCalloutsAvailable() == 0) {
                throw new ALMException(MAX_CALLOUTS_MSG);
            }else{
                response=ALMRestServices.makeGetRequest(finalEndpoint, headerMap);
            } 
            Dom.Document doc = new Dom.Document();
            doc.load(response);
            String jobStatus=parseXMLResponse(doc);
            if(jobStatus!=EXCEPTION_MSG){
                for(String s: jobStatus.split(SPLIT_DELIMITER)){
                    jenkinsResponse.add(s);
                }
            }
            if(jenkinsResponse.size()==1){
                j.Status__C=JENKINS_INPROGRESS;
                j.Jenkins_Job_Id__c=jenkinsResponse[0];
                jenkisBuildList.add(j);
            }else if(jenkinsResponse.size()==2){
                if(jenkinsResponse[1]==JENKINS_SUCCESS){
                    j.Status__C=JENKINS_SUCCESS;
                    j.Jenkins_Job_Id__c=jenkinsResponse[0];
                    jenkisBuildList.add(j);
                    jobIds.add( j.Jenkins_Job__c);
                }else if(jenkinsResponse[1]==JENKINS_FAILURE){
                    j.Status__C=JENKINS_FAILURE;
                    j.Jenkins_Job_Id__c=jenkinsResponse[0];
                    jenkisBuildList.add(j);
                }
            }          
        }      
        try{
            if(!jenkisBuildList.isEmpty()){
                update jenkisBuildList;                             
            }
        }catch (DMLException e) {
            ALMLogServices.error(e, ALMLogServices.Application.JENKINS);
        }
    }
    
    /**
    * @description Method to parse XML response from Jenkins for Build status
    * @param Dom.Document doc
    * @return String
    */
    private String parseXMLResponse (Dom.Document doc){
        String xmlResponse=EXCEPTION_MSG;
        for(DOM.XMLNode xmlnodeobj:doc.getRootElement().getChildElements()){
            for(Dom.XMLNode child : xmlnodeobj.getChildElements()){
                if(child.getName()==XML_RESPONSE_TAG_NUMBER){
                    xmlResponse=child.getText();
                }
                if(child.getName() ==XML_RESPONSE_TAG_RESULT){
                    xmlResponse=xmlResponse+';'+child.getText();
                    break;
                }
            }    
        }
        System.debug('xmlResponse'+xmlResponse);
        return xmlResponse;
    }
    
    /**
    * @description Aborts the scheduled job and executes the batch job.
    * @param SchedulableContext sc  
    */
    public void execute(SchedulableContext SC){
        Database.executeBatch(new JenkinsBuildBatchJob(),SCOPE_SIZE);
        System.abortJob(sc.getTriggerId());
    }
    
    /**
    * @description finsh method to do post processing of records in finsh method
    * @param Database.BatchableContext bc
    * @return void
    */
    public void finish(Database.BatchableContext BC){
        List<Jenkins_Build__c> jobsRemaining = Database.query(this.query + ' LIMIT 1');
        if (!jobsRemaining.isEmpty() && !ExecuteJenkinsBuildbatchServices.isMonitorBatchScheduledOrRunning()) {
            System.scheduleBatch(new JenkinsBuildBatchJob(),BATCH_JOB_TITLE,INTERVAL_IN_MINUTES,SCOPE_SIZE);
        }
        
    }

}