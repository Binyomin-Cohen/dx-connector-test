@RestResource(urlMapping='/ScratchOrg/*')
global with sharing class DXRestController {

  @HttpPost	
  global static String insertScratchOrgInfo(String accessToken, String instanceUrl, String sightlineScratchOrgId, String sfdxAuthUrl, 
    String userId, String userName, String devHubScratchOrgId, String expirationDate) {
    Scratch_Org_Info__c scratchOrgInfo = new Scratch_Org_Info__c(
        name = sightlineScratchOrgId,
        Access_Token__c = accessToken,
        Instance_URL__c = instanceUrl,
        Scratch_Org_Id__c = sightlineScratchOrgId,
        SFDX_Auth_URL__c = sfdxAuthUrl,
        User_Id__c = userId,
        User_Name__c = userName
    );
    insert scratchOrgInfo;

    List<Scratch_Org__c> scratchOrgs = [select Id from Scratch_Org__c where Id = :sightlineScratchOrgId];
    if (scratchOrgs.size() > 0) {
      Scratch_Org__c scratchOrg = scratchOrgs[0];
      scratchOrg.Scratch_Org_Id__c = devHubScratchOrgId;
      if (String.isNotBlank(expirationDate)) {
        scratchOrg.Expiration_Date__c = Date.valueOf(expirationDate);
      }
      update scratchOrg;
    }

    return sightlineScratchOrgId;
  }

}
