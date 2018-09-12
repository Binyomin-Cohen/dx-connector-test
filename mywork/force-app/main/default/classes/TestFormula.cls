@isTest
private class TestFormula {

    static testMethod void evaluateSimpleMergeFields_noMergeFields() {

        Map<String, Object> sourceData = new Map<String, Object>();
        String formulaText = '{No} merge fields here!';
        Formula f = new Formula(formulaText);

        Test.startTest();

            String result = f.evaluateSimpleMergeFields(sourceData);

        Test.stopTest();

        System.assertEquals(formulaText, result, 'Formulas with no merge fields should be unchanged.');
    }

    static testMethod void evaluateSimpleMergeFields_singleMergeField() {

        Map<String, Object> sourceData = new Map<String, Object>{'great' => 'awesome'};
        String formulaText = 'merge fields are {!great}';
        String expectedResult = 'merge fields are awesome';
        Formula f = new Formula(formulaText);

        Test.startTest();

            String result = f.evaluateSimpleMergeFields(sourceData);

        Test.stopTest();

        System.assertEquals(expectedResult, result, 'Formulas should have their merge fields evaluated.');
    }

    static testMethod void evaluateSimpleMergeFields_multipleMergeField() {

        Map<String, Object> sourceData = new Map<String, Object>{'good' => 'bad', 'bad' => 'good'};
        String formulaText = '{!good} is {!bad}';
        String expectedResult = 'bad is good';
        Formula f = new Formula(formulaText);

        Test.startTest();

            String result = f.evaluateSimpleMergeFields(sourceData);

        Test.stopTest();

        System.assertEquals(expectedResult, result, 'Formulas should have their merge fields evaluated.');
    }

    static testMethod void evaluateSimpleMergeFields_noMatchingData() {

        Map<String, Object> sourceData = new Map<String, Object>{'good' => 'bad'};
        String formulaText = '{!good} is {!great}';
        String expectedResult = 'bad is {!great}';
        Formula f = new Formula(formulaText);

        Test.startTest();

            String result = f.evaluateSimpleMergeFields(sourceData);

        Test.stopTest();

        System.assertEquals(expectedResult, result, 'Formulas should have any merge fields with source data evaluated.');
    }

    static testMethod void isDate() {
        String value = '2014-05-08';
        System.assertEquals(true, Formula.isDate(value), 'Dates should return true');

        System.assertEquals(false, Formula.isDate( '2014-05-08T22:08:19.000+0000' ), 'Datetimes should return false');
        System.assertEquals(false, Formula.isDate('woof'), 'Non dates should return false');
        System.assertEquals(false, Formula.isDate('5-5-5'), 'Non dates should return false');
    }

    static testMethod void isDateTime_positive() {
        String value = '2014-05-08T22:08:19.000+0000';
        System.assertEquals(true, Formula.isDateTime(value), 'Datetimes should return true');

        Persona__c p = new Persona__c(Name='p');
        insert p;
        p = [SELECT CreatedDate From Persona__c];
        Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped( JSON.serialize( p ) );
        System.debug(o);
        System.assertEquals(true, Formula.isDateTime((String)o.get('CreatedDate')), 'Datetimes should return true');
    }

    static testMethod void isDateTime_negative() {
        String value = '2014-05-08';
        System.assertEquals(false, Formula.isDateTime(value), 'Dates should return false');

        System.assertEquals(false, Formula.isDateTime( '09azzl982734 ' ), 'Anything not a datetime should return false');
    }

    static testMethod void parseJSONDateTime() {

        Persona__c p = new Persona__c(Name='p');
        insert p;
        p = [SELECT CreatedDate From Persona__c];

        Test.startTest();

            Map<String, Object> jsonValues = (Map<String, Object>) JSON.deserializeUntyped( JSON.serialize( p ) );
            Datetime returnedDateTime = Formula.parseJSONDateTime((String) jsonValues.get('CreatedDate'));
        Test.stopTest();

        System.assertEquals(p.CreatedDate, returnedDateTime, 'Datetime should be parsed to match original time.');
    }

}