@isTest
private class FieldReferenceTest
{
    private static testMethod void testBuild_Schema()
    {
        final Schema.SObjectField FIELD = Instances__c.Instance_Name__c;

        Test.startTest();

            FieldReference ref = FieldReference.build( FIELD );

        Test.stopTest();

        System.assert( ref instanceof FieldReference.SchemaFieldReference,
            'When the field is a schema object it should build a schema reference' );
        System.assertEquals( FIELD, ((FieldReference.SchemaFieldReference)ref).field,
            'The field passed in should be the field reference' );
    }

    private static testMethod void testBuild_Simple()
    {
        final String FIELD = 'Some_Field__c';

        Test.startTest();

            FieldReference ref = FieldReference.build( FIELD );

        Test.stopTest();

        System.assert( ref instanceof FieldReference.SimpleFieldReference,
            'When the field has no period it should build a simple reference' );
        System.assertEquals( FIELD, ((FieldReference.SimpleFieldReference)ref).field,
            'The field passed in should be the field reference' );
    }

    private static testMethod void testBuild_Chained()
    {
        final String RELATIONSHIP = 'Parent_Object__c';
        final String FIELD = 'Some_Field__c';
        final String REFERENCE = RELATIONSHIP + '.' + FIELD;

        Test.startTest();

            FieldReference ref = FieldReference.build( REFERENCE );

        Test.stopTest();

        System.assert( ref instanceof FieldReference.ChainedFieldReference,
            'When the field has a period it should build a chained reference' );

        FieldReference.ChainedFieldReference parent = (FieldReference.ChainedFieldReference)ref;

        System.assertEquals( RELATIONSHIP, parent.field,
            'The relationship name should by the chained reference field' );

        System.assert( parent.next instanceof FieldReference.SimpleFieldReference,
            'The chained reference should be the rest of the string' );
        System.assertEquals( FIELD, ((FieldReference.SimpleFieldReference)parent.next).field,
            'The field passed in should be the field reference' );
    }

    private static testMethod void testGetFrom_Schema()
    {
        final String NAME = 'Snoopy';

        Instances__c snoopy = new Instances__c( Instance_Name__c = NAME );
        FieldReference firstName = new FieldReference.SchemaFieldReference( Instances__c.Instance_Name__c );

        Test.startTest();

            Object retrieved = firstName.getFrom( snoopy );

        Test.stopTest();

        System.assertEquals( NAME, retrieved,
            'The value from the referenced field should be retrieved' );
    }

    private static testMethod void testGetFrom_Simple()
    {
        final String NAME = 'Snoopy';

        Instances__c snoopy = new Instances__c( Instance_Name__c = NAME );
        FieldReference firstName = new FieldReference.SimpleFieldReference( SObjectServices.getFullyQualifiedName('Instance_Name__c') );

        Test.startTest();

            Object retrieved = firstName.getFrom( snoopy );

        Test.stopTest();

        System.assertEquals( NAME, retrieved,
            'The value from the referenced field should be retrieved' );
    }

    private static testMethod void testGetFrom_Chained()
    {
        final String COMPANY = 'Wayne Industries';

        Business_Objective__c wayneIndustries = new Business_Objective__c( Name = COMPANY );
        Project__c batman = new Project__c( Description__c = 'Bruce' );
        batman.putSObject( SObjectServices.getFullyQualifiedName('Business_Objective__r'), wayneIndustries );

        FieldReference child = new FieldReference.SimpleFieldReference( 'Name' );
        FieldReference accountName = new FieldReference.ChainedFieldReference( SObjectServices.getFullyQualifiedName('Business_Objective__r'), child );

        Test.startTest();

            Object retrieved = accountName.getFrom( batman );

        Test.stopTest();

        System.assertEquals( COMPANY, retrieved,
            'The value from the referenced field should be retrieved' );
    }

    private static testMethod void testGetFrom_Chained_Null()
    {
        Project__c orphan = new Project__c( Description__c = 'Oliver' );

        FieldReference child = new FieldReference.SimpleFieldReference( 'Name' );
        FieldReference accountName = new FieldReference.ChainedFieldReference( SObjectServices.getFullyQualifiedName('Business_Objective__r'), child );

        Test.startTest();

            Object retrieved = accountName.getFrom( orphan );

        Test.stopTest();

        System.assertEquals( null, retrieved,
            'Null should be returned if any chained reference is null' );
    }

    private static testMethod void testToString_Schema()
    {
        FieldReference firstName = new FieldReference.SchemaFieldReference( Project__c.Description__c );

        Test.startTest();

            String field = firstName.toString();

        Test.stopTest();

        System.assertEquals( SObjectServices.getFullyQualifiedName('Description__c'), field,
            'The field name should be returned' );
    }

    private static testMethod void testToString_Simple()
    {
        FieldReference firstName = new FieldReference.SimpleFieldReference( 'FirstName' );

        Test.startTest();

            String field = firstName.toString();

        Test.stopTest();

        System.assertEquals( 'FirstName', field,
            'The field name should be returned' );
    }

    private static testMethod void testToString_Chained()
    {
        FieldReference child = new FieldReference.SimpleFieldReference( 'Name' );
        FieldReference accountName = new FieldReference.ChainedFieldReference( 'Account', child );

        Test.startTest();

            String field = accountName.toString();

        Test.stopTest();

        System.assertEquals( 'Account.Name', field,
            'The field name should be returned' );
    }
}