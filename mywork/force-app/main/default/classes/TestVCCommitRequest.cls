@isTest
private class TestVCCommitRequest {

    static Instances__c instance;
    static Backlog__c backlog;
    static Auth_User__c sourceAuthUser;
    static Auth_User__c sightlineAuthUser;
    static ALM_Private__c almPrivate;
    static VC_Commit__c vcCommit;

    static String BRANCH_NAME = 'test-branch';
    static String COMMIT_MESSAGE = 'initial commit';
    static String REPO_URL = 'git@github.com:bluewolf/test.git';

    static OAuthServices.AppSettings settings;
    static String SSH_PUBLIC_KEY = 'ssh public key';
    static String SSH_PRIVATE_KEY = 'ssh private key';
    static String SSH_PASSPHRASE = 'ssh passphrase';

    private static final Id TEST_KEY_OWNER_ID = TestingUtils.ADMIN_USER.Id;

    static void setup() {
        instance = new Instances__c(Name='dev');
        insert instance;

        VC_Repository__c repo = new VC_Repository__c(Repository_URL__c=REPO_URL);
        insert repo;

        sourceAuthUser = TestingUtils.createAuthUser(TEST_KEY_OWNER_ID, instance.Id);

        backlog = new Backlog__c(Status__c='Complete');
        insert backlog;

        sightlineAuthUser = TestingUtils.setupSightlineAuth();
        sightlineAuthUser.Refresh_Token__c = 'test token';
        update sightlineAuthUser;

        almPrivate = TestingUtils.createOAuthSettings();
        settings = OAuthServices.getAppSettings();

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlog.Id, instance);
        vcCommit = new VC_Commit__c(Backlog_Item__c=backlog.Id, Branch_Name__c=BRANCH_NAME,  
                                      Commit_Message__c = COMMIT_MESSAGE, VC_Repository__c=repo.Id, 
                                      Backlog_Components__c = backlogComponent.Id);
        insert vcCommit;
        
        vcCommit = [SELECT Backlog_Item__c, Backlog_Components__c, Branch_Name__c, 
                                    Commit_Message__c, VC_Repository__c, CreatedBy.Username
                     FROM VC_Commit__c
                     WHERE Id=:vcCommit.Id];
    }

    static void setupSSH() {
        SSHServices.storePublicKey(TEST_KEY_OWNER_ID, SSH_PUBLIC_KEY);
        SSHServices.storePrivateKey(TEST_KEY_OWNER_ID, SSH_PRIVATE_KEY);
        SSHServices.storePassphrase(TEST_KEY_OWNER_ID, SSH_PASSPHRASE);
    }

    static testMethod void creatingVCCommitRequest_NoSSHKeysThrowsError() {
        setup();

        Test.startTest();

            try {
                VCCommitRequest request = new VCCommitRequest(vcCommit, sourceAuthUser);
                System.assert(false, 'we expect an exception to be thrown');
            } catch(Exception e) {
                System.assert(e.getMessage().contains(System.Label.VC_Keypair_Retrieval_Error),
                              'we expect the correct exception to be thrown');
            }

        Test.stopTest();
    }

    static testMethod void creatingVCCommitRequest_AttributesAreSetCorrectly() {
        System.runAs(TestingUtils.ADMIN_USER) {
            setup();
        }
        setupSSH();
        
        Test.startTest();
            VCCommitRequest request;

            System.runAs(TestingUtils.ADMIN_USER) {
                request = new VCCommitRequest(vcCommit, sourceAuthUser);
            }

        Test.stopTest();

        VersionControlSource gitSource = request.versionControlSource;
        
        System.assertEquals(BRANCH_NAME, gitSource.repoLocation, 'The branch name should be correct');
        System.assertEquals(COMMIT_MESSAGE, request.commitMessage, 'The commit message should be correct');
        System.assertEquals(TestingUtils.ADMIN_USER.Username, request.commitOwner, 'The commit owner should be correct');
        System.assertEquals(REPO_URL, gitSource.repoUrl, 'The repository url should be correct');

        System.assertEquals(SSH_PUBLIC_KEY, gitSource.publicKey, 'The public key should be correct');
        System.assertEquals(SSH_PRIVATE_KEY, gitSource.privateKey, 'The private key should be correct');
        System.assertEquals(SSH_PASSPHRASE, gitSource.passphrase, 'The pass phrase should be correct');

        System.assertEquals(settings.consumerKey, request.clientId, 'The clientId should be correct');
        System.assertEquals(settings.consumerSecret, request.clientSecret, 'The clientSecret should be correct');

        System.assertEquals(sourceAuthUser.Refresh_Token__c, request.sourceRefreshToken,
                            'The source refresh token should be correct');
        System.assertEquals(sourceAuthUser.Instance_URL__c + BaseRequest.SOAP_ENDPOINT, request.sourceEndpoint,
                            'The source endpoint should be correct');
        System.assertEquals(sightlineAuthUser.Instance_URL__c + BaseRequest.SOAP_ENDPOINT, request.sightlineEndPoint,
                            'The Sightline instance url should be correct');
        System.assertEquals(sightlineAuthUser.Refresh_Token__c, request.sightlineRefreshToken,
                            'The Sightline refresh token should be correct');
    }

    static testMethod void loadBacklogComponents() {
        final String DELETED_COMPONENT_NAME = 'deletedComponentName';
        System.runAs(TestingUtils.ADMIN_USER) {
            setup();
        }
        Instances__c instance2 = new Instances__c(Name='dev2');
        insert instance2;

        Component__c comp2 = TestingUtils.createComponent(DELETED_COMPONENT_NAME, 'justSomeTypeOfDeletedComponent', instance2.Id);

        Backlog_Component__c destructiveBacklogComponent = new Backlog_Component__c(
            Backlog__c = backlog.Id,
            Component__c = comp2.Id,
            Source_Instance__c = instance2.Id,
            Deleted__c = true);
        insert destructiveBacklogComponent;
        
        vcCommit.Backlog_Components__c += ',' + destructiveBacklogComponent.Id;
        update vcCommit;
    
        setupSSH();
        
        Test.startTest();
            VCCommitRequest request;

            System.runAs(TestingUtils.ADMIN_USER) {
                request = new VCCommitRequest(vcCommit, sourceAuthUser);
            }

        Test.stopTest();

        System.assert(request.components != null, 'Components should be initialized');
        System.assert(request.destructiveChanges != null, 'DestructiveChanges should be initialized');

        System.assertEquals(2, request.components.size(), 'One component should be in the components list');
        System.assertEquals(2, request.destructiveChanges.size(), 'One component should be in the list for destructive changes');
        
        System.assert(request.destructiveChanges[0].contains(AssemblerRequest.COMPONENT_HEADER_NAME),
            'The first component in the destructive changes list should be the header');
        System.assert(request.destructiveChanges[1].contains(DELETED_COMPONENT_NAME), 
            'The deleted component should be in the destructive changes list');   
        
        System.assert(request.components[0].contains(AssemblerRequest.COMPONENT_HEADER_NAME),
            'The first component in the components list should be the header');
        System.assert(request.components[1].contains(TestingUtils.TEST_OBJECT), 
            'The non-deleted component should be in the components list');   
        }

}
