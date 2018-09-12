/**
* @author Vivek
* @date 18th Sep, 2017
*
* @group <Salesforce Garage>
*
* @description Test class for ExecuteJenkinsBuildbatchServices
*/
@isTest
private class TestExecuteJenkinsBuildbatchServices {

    /*
        Test method to check status of jenkins batch job.
    */
    static testMethod void testJenkinsJobRunningStatus(){
        Test.startTest();
            Boolean isMonitorBatchRunning = ExecuteJenkinsBuildbatchServices.isMonitorBatchScheduledOrRunning();
        Test.Stoptest();
        System.assertEquals(isMonitorBatchRunning, false, 'By default, the Jenkins monitor batch job should not be running');
    }
}