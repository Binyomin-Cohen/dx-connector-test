@isTest
private class TestSSHServices {
    private static final String TEST_PUBLIC_KEY = 'Test Public Key';
    private static final String TEST_PRIVATE_KEY = 'Test Private Key';
    private static final String TEST_PASSPHRASE = 'Test Passphrase';
    private static final Id TEST_KEY_OWNER_ID = TestingUtils.ADMIN_USER.Id;

    private static void assertProperStorage(Id expectedKeyOwnerId, Schema.SObjectField expectedUserKeyFieldReference, String expectedFieldContent) {
        Id keyOwnerId = expectedKeyOwnerId == null ? TestingUtils.ADMIN_USER.Id : expectedKeyOwnerId;

        List<SSH_Keypair__c> actualKeypairs = [SELECT Public_Key__c, Private_Key__c, Passphrase__c FROM SSH_Keypair__c WHERE OwnerId = :keyOwnerId];

        System.assert(!actualKeypairs.isEmpty(), 'A keypair should be returned.');     
        SSH_Keypair__c actualKeypair = actualKeypairs[0];   

        ALM_Private__c privateSettings = ALM_Private__c.getOrgDefaults();
        Blob managementKey = EncodingUtil.base64Decode(privateSettings.SSH_Management_Key__c);

        String actualFieldContent = null;
        try {
            String encryptedField = String.valueOf(actualKeypair.get(expectedUserKeyFieldReference));

            actualFieldContent = Crypto.decryptWithManagedIV(SSHServices.MANAGEMENT_ENCRYPTION_ALGORITHM, managementKey, EncodingUtil.base64Decode(encryptedField)).toString();
        } catch (Exception e) {
            System.assert(false, 'The field should decrypt properly.');
        }

        System.assertEquals(expectedFieldContent, actualFieldContent, 'The decrypted field should match.');
    }

    private static testMethod void storeField_nullFieldReference() {
        TestingUtils.createSSHPrivateSettings();

        Test.startTest();

            try {
                SSHServices.storeField(TEST_KEY_OWNER_ID, null, TEST_PUBLIC_KEY);

                System.assert(false, 'An exception should be thrown when attempting to store with a null field reference.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(System.Label.SSH_User_Key_Invalid_Field_Error), 'The proper exception should be thrown when attempting to store with a null field reference.');
            }

        Test.stopTest();
    }

    private static testMethod void storePublicKey() {
        TestingUtils.createSSHPrivateSettings();

        Test.startTest();

            SSHServices.storePublicKey(TEST_KEY_OWNER_ID, TEST_PUBLIC_KEY);

        Test.stopTest();

        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY);
    }

    private static testMethod void storePrivateKey() {
        String TEST_PRIVATE_KEY = 'Test Private Key';

        TestingUtils.createSSHPrivateSettings();

        Test.startTest();

            SSHServices.storePrivateKey(TEST_KEY_OWNER_ID, TEST_PRIVATE_KEY);

        Test.stopTest();

        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Private_Key__c, TEST_PRIVATE_KEY);
    }

    private static testMethod void storePassphrase() {
        TestingUtils.createSSHPrivateSettings();

        Test.startTest();

            SSHServices.storePassphrase(TEST_KEY_OWNER_ID, TEST_PASSPHRASE);

        Test.stopTest();

        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Passphrase__c, TEST_PASSPHRASE);
    }

    private static testMethod void storePublicKey_existingKeypair() {
        TestingUtils.createSSHPrivateSettings();
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Public_Key__c, 'Some Other Public Key');

        Test.startTest();

            SSHServices.storePublicKey(TEST_KEY_OWNER_ID, TEST_PUBLIC_KEY);

        Test.stopTest();

        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY);
    }

    private static testMethod void storePublicKey_existingManagementKey() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);

        Test.startTest();

            SSHServices.storePublicKey(TEST_KEY_OWNER_ID, TEST_PUBLIC_KEY);

        Test.stopTest();

        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY);
    }

    private static testMethod void storePublicKey_noPrivateSettings() {
        Test.startTest();

            SSHServices.storePublicKey(TEST_KEY_OWNER_ID, TEST_PUBLIC_KEY);

        Test.stopTest();

        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY);
    }

    private static testMethod void retrieveField_nullFieldReference() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY, testManagementKey);

        Test.startTest();

            try {
                SSHServices.retrieveField(TEST_KEY_OWNER_ID, null);

                System.assert(false, 'An exception should be thrown when attempting to retrieve with a null field reference.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(System.Label.SSH_User_Key_Invalid_Field_Error), 'The proper exception should be thrown when attempting to retrieve with a null field reference.');
            }

        Test.stopTest();
    }

    private static testMethod void retrievePublicKey() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY, testManagementKey);

        Test.startTest();

            String actualPublicKey = SSHServices.retrievePublicKey(TEST_KEY_OWNER_ID);

        Test.stopTest();

        System.assertEquals(TEST_PUBLIC_KEY, actualPublicKey, 'The decrypted public key should match.');
    }

    private static testMethod void retrievePrivateKey() {
        String TEST_PRIVATE_KEY = 'Test Private Key';
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Private_Key__c, TEST_PRIVATE_KEY, testManagementKey);

        Test.startTest();

            String actualPrivateKey = SSHServices.retrievePrivateKey(TEST_KEY_OWNER_ID);

        Test.stopTest();

        System.assertEquals(TEST_PRIVATE_KEY, actualPrivateKey, 'The decrypted private key should match.');
    }

    private static testMethod void retrievePassphrase() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Passphrase__c, TEST_PASSPHRASE, testManagementKey);

        Test.startTest();

            String actualPassphrase = SSHServices.retrievePassphrase(TEST_KEY_OWNER_ID);

        Test.stopTest();

        System.assertEquals(TEST_PASSPHRASE, actualPassphrase, 'The decrypted passphrase should match.');
    }

    private static testMethod void retrieveKeysAndPassphrase() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(TEST_PUBLIC_KEY, TEST_PRIVATE_KEY, TEST_PASSPHRASE, testManagementKey);

        Test.startTest();

            Map<String, String> sshVals = SSHServices.retrieveKeysAndPassphrase(TEST_KEY_OWNER_ID);

        Test.stopTest();

        System.assertEquals(TEST_PUBLIC_KEY, sshVals.get(SSHServices.PUBLIC_KEY), 'The decrypted public key should match.');
        System.assertEquals(TEST_PRIVATE_KEY, sshVals.get(SSHServices.PRIVATE_KEY), 'The decrypted private key should match.');
        System.assertEquals(TEST_PASSPHRASE, sshVals.get(SSHServices.PASS_PHRASE), 'The decrypted passphrase should match.');
    }

    private static testMethod void retrieveKeysAndPassphrase_throwsException_whenNoKeysExist() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);

        Test.startTest();

            try {
                SSHServices.retrieveKeysAndPassphrase(TEST_KEY_OWNER_ID);
                System.assert(false, 'An Exception should be thrown when no key exists');
            } catch (Exception e) {
                System.assertEquals(System.Label.VC_Keypair_Retrieval_Error, e.getMessage(),
                    'The correct exception message should have been thrown');
            }

        Test.stopTest();

    }

    private static testMethod void retrieveKeysAndPassphrase_withMultipleUsers() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);

        List<User> users = new List<User>();
        users.add( TestingUtils.createUser( TestingUtils.ADMIN_USER.ProfileId, 'username1@testusenames.com' ));
        users.add( TestingUtils.createUser( TestingUtils.ADMIN_USER.ProfileId, 'username2@testusenames.com' ));

        List<Id> userIds = new List<Id>();
        for(User user: users){
            userIds.add(user.Id);
        }
        for(Integer i = 0; i < userIds.size(); i++){
            TestingUtils.createSSHUserKeypair(
                    TEST_PUBLIC_KEY + i, TEST_PRIVATE_KEY + i, TEST_PASSPHRASE + i, testManagementKey, userIds[i]
            );
        }
        Test.startTest();

            Map<Id, Map<String, String>> sshValsMaps = SSHServices.retrieveKeysAndPassphraseForMultipleOwners(userIds);

        Test.stopTest();
        for(Integer i = 0; i < userIds.size(); i++){
            Map<String, String> shhValsMapForSingleUser = sshValsMaps.get(userIds[i]);
            System.assertEquals(TEST_PUBLIC_KEY + i, shhValsMapForSingleUser.get(SSHServices.PUBLIC_KEY), 'The decrypted public key should match.');
            System.assertEquals(TEST_PRIVATE_KEY + i, shhValsMapForSingleUser.get(SSHServices.PRIVATE_KEY), 'The decrypted private key should match.');
            System.assertEquals(TEST_PASSPHRASE + i, shhValsMapForSingleUser.get(SSHServices.PASS_PHRASE), 'The decrypted passphrase should match.');
        }
    }

    private static testMethod void retrievePublicKey_noKeypair() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

        TestingUtils.createSSHPrivateSettings(testManagementKey);

        Test.startTest();

            String actualPublicKey = SSHServices.retrievePublicKey(TEST_KEY_OWNER_ID);

        Test.stopTest();

        System.assertEquals(null, actualPublicKey, 'The decrypted public key should be null when no keypair exists.');
    }

    private static testMethod void retrievePublicKey_noManagementKey() {
        TestingUtils.createSSHPrivateSettings();
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY);

        Test.startTest();

            try {
                String actualPublicKey = SSHServices.retrievePublicKey(TEST_KEY_OWNER_ID);

                System.assert(false, 'An exception should be thrown when no SSH management key exists.');
            } catch (Exception e) {
                System.assertEquals(System.Label.SSH_User_Key_Retrieval_Error + ' Exception type: System.SecurityException', e.getMessage(), 'The proper exception type should be thrown when no SSH management key exists.');
            }

        Test.stopTest();
    }

    private static testMethod void retrievePublicKey_noPrivateSettings() {
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY);

        Test.startTest();

            try {
                String actualPublicKey = SSHServices.retrievePublicKey(TEST_KEY_OWNER_ID);

                System.assert(false, 'An exception should be thrown when no private setting exists.');
            } catch (Exception e) {
                System.assertEquals(System.Label.SSH_User_Key_Retrieval_Error + ' Exception type: System.SecurityException', e.getMessage(), 'The proper exception type should be thrown when no private setting exists.');
            }

        Test.stopTest();
    }

    private static testMethod void userHasExistingKeypair_nullUserId() {
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Private_Key__c, 'Test Private Key');

        Test.startTest();

            Boolean userHasExistingKeypair = SSHServices.userHasExistingKeypair(null);

        Test.stopTest();

        System.assertEquals(false, userHasExistingKeypair, 'No keypair should exist for a null user ID.');
    }

    private static testMethod void userHasExistingKeypair_noKeypair() {
        String testUserHandle = 'Test User Handle';

        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Private_Key__c, 'Test Private Key');

        UnitTest.addData(new List<User>{new User()}).tag(testUserHandle);
        UnitTest.get(testUserHandle).dummyInsert();
        Id testUserId = new List<Id>(UnitTest.getIds(testUserHandle))[0];

        Test.startTest();

            Boolean userHasExistingKeypair = SSHServices.userHasExistingKeypair(testUserId);

        Test.stopTest();

        System.assertEquals(false, userHasExistingKeypair, 'No keypair should exist for the user.');
    }

    private static testMethod void userHasExistingKeypair_existingKeypair() {
        TestingUtils.createSSHUserKeypair(SSH_Keypair__c.Private_Key__c, 'Test Private Key');

        Test.startTest();

            Boolean userHasExistingKeypair = SSHServices.userHasExistingKeypair(TEST_KEY_OWNER_ID);

        Test.stopTest();

        System.assert(userHasExistingKeypair, 'A keypair should exist for the user.');
    }

    private static testMethod void generateKeypair_nullUserId() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(''));

        Test.startTest();

            try {
                SSHServices.generateKeypair(null);

                System.assert(false, 'An exception should be thrown when a null user ID is provided.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(System.Label.SSH_User_Key_Generation_Error), 'The proper exception should be thrown when a null user ID is provided.');
            }

        Test.stopTest();
    }

    private static testMethod void generateKeypair_httpNotFound() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(JSON.serialize(''), ALMRestServices.HTTP_NOT_FOUND));

        Test.startTest();

            try {
                SSHServices.generateKeypair(TEST_KEY_OWNER_ID);

                System.assert(false, 'An exception should be thrown when an "HTTP Not Found" response is returned.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(String.valueOf(System.Label.HTTP_Error)), 'The proper exception should be thrown when an "HTTP Not Found" response is returned.');
            }

        Test.stopTest();
    }

    private static testMethod void generateKeypair_httpBadRequest() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(JSON.serialize(''), ALMRestServices.HTTP_BAD_REQUEST));

        Test.startTest();

            try {
                SSHServices.generateKeypair(TEST_KEY_OWNER_ID);

                System.assert(false, 'An exception should be thrown when an "HTTP Bad Request" response is returned.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(String.valueOf(System.Label.HTTP_Error)), 'The proper exception should be thrown when an "HTTP Bad Request" response is returned.');
            }

        Test.stopTest();
    }

    private static testMethod void generateKeypair_success() {
        Map<String, String> responseBody = new Map<String, String>{
            'publicKey' => TEST_PUBLIC_KEY,
            'privateKey' => TEST_PRIVATE_KEY,
            'passPhrase' => TEST_PASSPHRASE
        };
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(JSON.serialize(responseBody)));

        System.assertEquals(0, [SELECT Count() FROM SSH_Keypair__c WHERE OwnerId = :TEST_KEY_OWNER_ID], 'The user should begin with no keypairs.');

        Test.startTest();

            SSHServices.generateKeypair(TEST_KEY_OWNER_ID);

        Test.stopTest();

        System.assertEquals(1, [SELECT Count() FROM SSH_Keypair__c WHERE OwnerId = :TEST_KEY_OWNER_ID], 'A single keypair should be successfully created for the user.');
        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Public_Key__c, TEST_PUBLIC_KEY);
        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Private_Key__c, TEST_PRIVATE_KEY);
        assertProperStorage(TEST_KEY_OWNER_ID, SSH_Keypair__c.Passphrase__c, TEST_PASSPHRASE);
    }
}