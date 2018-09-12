public with sharing class SSHServices {
    public static final String MANAGEMENT_ENCRYPTION_ALGORITHM = 'AES256';
    public static final Integer MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH = 256;
    public static String PUBLIC_KEY = 'publicKey';
    public static String PRIVATE_KEY = 'privateKey';
    public static String PASS_PHRASE = 'passphrase';
    public static final String KEYGEN_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/keygen';

    /**
    * Generates a keypair for the user with the given ID.
    * @param userKeyOwnerId - The ID of the user for whom to create a keypair.
    */
    public static void generateKeypair(Id userKeyOwnerId) {
        try {
            String keygenResponseString = null;
            try {
                keygenResponseString = ALMRestServices.makeSensitiveHTTPRequest(
                    ALMRestServices.RequestMethod.POST,
                    KEYGEN_ENDPOINT,
                    null,
                    JSON.serialize(new SSHKeygenRequest()),
                    null
                );
            } catch (Exception e) {
                throw new ALMException(System.Label.HTTP_Error);
            }

            SSHKeygenResponse keygenResponse = (SSHKeygenResponse)JSON.deserialize(keygenResponseString, SSHKeygenResponse.class);

            storeField(userKeyOwnerId, SSH_Keypair__c.Public_Key__c, keygenResponse.publicKey);
            storeField(userKeyOwnerId, SSH_Keypair__c.Private_Key__c, keygenResponse.privateKey);
            storeField(userKeyOwnerId, SSH_Keypair__c.Passphrase__c, keygenResponse.passPhrase);
        } catch (Exception e) {
            if (e instanceof ALMException) {
                // Only custom exceptions with sanitary content should be exposed.
                throw e;
            } else {
                throw new ALMException(System.Label.SSH_User_Key_Generation_Error + ' Exception type: ' + e.getTypeName());
            }
        }
    }

    /**
    * Stores an encrypted public key string in a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be updated.
    * @param userPublicKey - The public key string data that will be stored in the keypair.
    * @throws ALMException
    */
    public static void storePublicKey(Id userKeyOwnerId, String userPublicKey) {
        storeField(userKeyOwnerId, SSH_Keypair__c.Public_Key__c, userPublicKey);
    }

    /**
    * Stores an encrypted private key string in a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be updated.
    * @param userPrivateKey - The private key string data that will be stored in the keypair.
    * @throws ALMException
    */
    public static void storePrivateKey(Id userKeyOwnerId, String userPrivateKey) {
        storeField(userKeyOwnerId, SSH_Keypair__c.Private_Key__c, userPrivateKey);
    }

    /**
    * Stores an encrypted key passphrase string in a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be updated.
    * @param userPassphrase - The key passphrase string data that will be stored in the keypair.
    * @throws ALMException
    */
    public static void storePassphrase(Id userKeyOwnerId, String userPassphrase) {
        storeField(userKeyOwnerId, SSH_Keypair__c.Passphrase__c, userPassphrase);
    }

    /**
    * Stores an encrypted field string in a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be updated.
    * @param userKeyFieldReference - The reference to the string field of the key that will be updated.
    * @param userFieldContent - The field string data that will be stored in the keypair.
    * @throws ALMException
    */
    public static void storeField(Id userKeyOwnerId, Schema.SObjectField userKeyFieldReference, String userFieldContent) {
        try {
            Blob managementKey = getManagementKey();
            if (managementKey == null) {
                throw new ALMException(System.Label.SSH_Management_Key_Retrieval_Error);
            }

            String encryptedField =
                EncodingUtil.base64Encode(
                    Crypto.encryptWithManagedIV(
                        MANAGEMENT_ENCRYPTION_ALGORITHM,
                        managementKey,
                        Blob.valueOf(userFieldContent)
                    )
                );

            SSH_Keypair__c keypair = null;
            try {
                keypair = queryKeypair(userKeyOwnerId, userKeyFieldReference);
                keypair.put(userKeyFieldReference, encryptedField);
            } catch (Exception e) {
                throw new ALMException(System.Label.SSH_User_Key_Invalid_Field_Error);
            }

            upsert keypair;
        } catch (Exception e) {
            if (e instanceof ALMException) {
                // Only custom exceptions with sanitary content should be exposed.
                throw e;
            } else {
                throw new ALMException(System.Label.SSH_User_Key_Storage_Error + ' Exception type: ' + e.getTypeName());
            }
        }
    }

    /**
    * Retrieves an encrypted public key string from a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be read.
    * @return - The public key string data that will be read from the keypair.
    * @throws ALMException
    */
    public static String retrievePublicKey(Id userKeyOwnerId) {
        return retrieveField(userKeyOwnerId, SSH_Keypair__c.Public_Key__c);
    }

    /**
    * Retrieves an encrypted private key string from a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be read.
    * @return - The private key string data that will be read from the keypair.
    * @throws ALMException
    */
    public static String retrievePrivateKey(Id userKeyOwnerId) {
        return retrieveField(userKeyOwnerId, SSH_Keypair__c.Private_Key__c);
    }

    /**
    * Retrieves an encrypted key passphrase string from a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be read.
    * @return - The key passphrase string data that will be read from the keypair.
    * @throws ALMException
    */
    public static String retrievePassphrase(Id userKeyOwnerId) {
        return retrieveField(userKeyOwnerId, SSH_Keypair__c.Passphrase__c);
    }

    /**
    * Retrieves a map of public key, private key, passphrase to their encrypted values from a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be read.
    * @return - a map of public key, private key, passphrase to their encrypted values
    * @throws ALMException
    */
    public static Map<String, String> retrieveKeysAndPassphrase(Id userKeyOwnerId){

        List<Id> userKeyOwnerIds = new List<Id>();
        userKeyOwnerIds.add(userKeyOwnerId);
        Map<Id, Map<String, String>> userToKeysAndPassphraseMap = retrieveKeysAndPassphraseForMultipleOwners(userKeyOwnerIds);

        if (!userToKeysAndPassphraseMap.containsKey(userKeyOwnerId)) {
            throw new ALMException(System.Label.VC_Keypair_Retrieval_Error);
        }

        return userToKeysAndPassphraseMap.get(userKeyOwnerId);

    }

    public static Map<Id, Map<String, String>> retrieveKeysAndPassphraseForMultipleOwners(List<Id> userKeyOwnerIds){

        Map<String, Schema.SObjectField> sshFieldNamesToSObjectFields = new Map<String, Schema.SObjectField>();
        sshFieldNamesToSObjectFields.put(PUBLIC_KEY, SSH_Keypair__c.Public_Key__c);
        sshFieldNamesToSObjectFields.put(PRIVATE_KEY, SSH_Keypair__c.Private_Key__c);
        sshFieldNamesToSObjectFields.put(PASS_PHRASE, SSH_Keypair__c.Passphrase__c);

        Map<Id, Map<String, String>> keysAndPassphrases = new Map<Id, Map<String, String>>();

        try{
            List<SSH_Keypair__c> keypairs = queryKeypairs(userKeyOwnerIds);

            Blob managementKey = getManagementKey();
            if (managementKey == null) {
                throw new ALMException(System.Label.SSH_Management_Key_Retrieval_Error);
            }


            for(SSH_Keypair__c keypair: keypairs){

                Map<String, String> keysAndPassphrase = new Map<String, String>();

                for(String valToRetrieve: sshFieldNamesToSObjectFields.keySet()){

                    Schema.SObjectField field =  sshFieldNamesToSObjectFields.get(valToRetrieve);

                    String encryptedField = String.valueOf( keypair.get(field) );

                    if (String.isBlank(encryptedField)) {
                        throw new ALMException(System.Label.SSH_Management_Key_Retrieval_Error);
                    }

                    String decryptedField = decryptField(encryptedField, managementKey);

                    keysAndPassphrase.put( valToRetrieve, decryptedField);
                }
                keysAndPassphrases.put(keypair.OwnerId, keysAndPassphrase);
            }

        } catch (Exception e) {
            //not sure about following message
            throw new ALMException(System.Label.SSH_User_Key_Invalid_Field_Error);
        }
        return keysAndPassphrases;
    }

    private static String decryptField(String encryptedField, Blob managementKey){
        return Crypto.decryptWithManagedIV(
                MANAGEMENT_ENCRYPTION_ALGORITHM,
                managementKey,
                EncodingUtil.base64Decode(encryptedField)
        ).toString();
    }

    /**
    * Retrieves an encrypted string field from a user's keypair.
    * @param userKeyOwnerId - The ID of the owner of the keypair that will be read.
    * @param userKeyFieldReference - The reference to the string field of the keypair that will be retrieved.
    * @return - The field string data that will be read from the keypair.
    * @throws ALMException
    */
    public static String retrieveField(Id userKeyOwnerId, Schema.SObjectField userKeyFieldReference) {
        try {
            String encryptedField = null;
            try {
                SSH_Keypair__c keypair = queryKeypair(userKeyOwnerId, userKeyFieldReference);
                encryptedField = String.valueOf(keypair.get(userKeyFieldReference));
            } catch (Exception e) {
                throw new ALMException(System.Label.SSH_User_Key_Invalid_Field_Error);
            }

            if (String.isBlank(encryptedField)) {
                return null;
            }

            Blob managementKey = getManagementKey();
            if (managementKey == null) {
                throw new ALMException(System.Label.SSH_Management_Key_Retrieval_Error);
            }

            String decryptedField =
                Crypto.decryptWithManagedIV(
                    MANAGEMENT_ENCRYPTION_ALGORITHM,
                    managementKey,
                    EncodingUtil.base64Decode(encryptedField)
                ).toString();

            return decryptedField;
        } catch (Exception e) {
            if (e instanceof ALMException) {
                // Only custom exceptions with sanitary content should be exposed.
                throw e;
            } else {
                throw new ALMException(System.Label.SSH_User_Key_Retrieval_Error + ' Exception type: ' + e.getTypeName());
            }
        }
    }

    /**
    * Determines whether or not the user associated with the given user ID has an existing keypair.
    * @param userId - The user ID with which to check for existing keypairs.
    * @return - Whether or not the user has an existing keypair.
    */
    public static Boolean userHasExistingKeypair(Id userId) {
        Integer numberKeypairs = [
            SELECT Count()
            FROM SSH_Keypair__c
            WHERE OwnerId = :userId
        ];

        return numberKeypairs > 0;
    }

    private static Blob getManagementKey() {
        Blob managementKey = null;

        ALM_Private__c privateSettings = ALM_Private__c.getOrgDefaults();

        if (String.isBlank(privateSettings.SSH_Management_Key__c)) {
            managementKey = Crypto.generateAesKey(MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);

            try {
                privateSettings.SSH_Management_Key__c = EncodingUtil.base64Encode(managementKey);
                upsert privateSettings;
            } catch (Exception e) {
                throw new ALMException(System.Label.SSH_Management_Key_Creation_Error);
            }
        } else {
            managementKey = EncodingUtil.base64Decode(privateSettings.SSH_Management_Key__c);
        }

        return managementKey;
    }

    private static SSH_Keypair__c queryKeypair(Id userKeyOwnerId, Schema.SObjectField fieldReference) {
        userKeyOwnerId = String.escapeSingleQuotes(userKeyOwnerId);

        String queryString = 
            'SELECT Id, ' + fieldReference.getDescribe().getName() + ' ' +
            'FROM ' + SObjectServices.getFullyQualifiedName('SSH_Keypair__c') + ' ' +
            'WHERE OwnerId = :userKeyOwnerId ' +
            'ORDER BY CreatedDate DESC ' +
            'LIMIT 1';
        List<SSH_Keypair__c> keypairs = Database.query(queryString);

        return keypairs.isEmpty() ? new SSH_Keypair__c(OwnerId = userKeyOwnerId) : keypairs[0];
    }

    private static SSH_Keypair__c queryKeypair(Id userKeyOwnerId) {

        List<SSH_Keypair__c> keypairs =
            [SELECT Id, Passphrase__c, Private_Key__c, Public_Key__c
                FROM SSH_Keypair__c
                WHERE OwnerId = :userKeyOwnerId
                ORDER BY CreatedDate DESC
                LIMIT 1];

        return keypairs.isEmpty() ? new SSH_Keypair__c(OwnerId = userKeyOwnerId) : keypairs[0];
    }

    private static List<SSH_Keypair__c> queryKeypairs(List<Id> userKeyOwnerIds) {

        List<SSH_Keypair__c> keypairs =
        [SELECT Id, OwnerId, Passphrase__c, Private_Key__c, Public_Key__c
        FROM SSH_Keypair__c
        WHERE OwnerId IN: userKeyOwnerIds
        ORDER BY CreatedDate DESC];

        return keypairs;
    }

    private class SSHKeygenRequest {
        public Id orgId;

        public SSHKeygenRequest() {
            orgId = UserInfo.getOrganizationId();
        }
    }

    private class SSHKeygenResponse {
        public String publicKey;
        public String privateKey;
        public String passPhrase;
    }
}