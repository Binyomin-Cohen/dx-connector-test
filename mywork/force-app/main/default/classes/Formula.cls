public with sharing class Formula
{
    static Pattern mergeFieldPattern = Pattern.compile('\\{!([^\\{]+)\\}');
    //dates of the form 2014-05-08T22:08:19.000+0000
    static Pattern datetimePattern =
        Pattern.compile('[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]+\\+[0-9]+');
    static Pattern datePattern = Pattern.compile('[0-9]{4}-[0-9]{2}-[0-9]{2}');
    String expression;

    public Formula(String expression)
    {
        this.expression = expression;
    }

    /**
    * Evaluates expression by replacing simple merge fields with data from source data
    *   For example given the expression ' Foo {!bar}' and source data of {'bar' => 'baz'}
    *   'Foo baz' will be returned
    */
    public String evaluateSimpleMergeFields(Map<String, Object> sourceData)
    {
        Matcher matcher = mergeFieldPattern.matcher( expression );
        String evaluatedExpression = expression;

        while( matcher.find() )
        {
            String mergeField = matcher.group(1);
            if( sourceData.containsKey( mergeField ))
            {
                String replacement = String.valueOf( sourceData.get( mergeField) );
                evaluatedExpression = evaluatedExpression.replace( matcher.group(0), replacement );
            }
        }

        return evaluatedExpression;
    }

    public static Boolean isDateTime(String value) {

        Matcher matcher = datetimePattern.matcher( value );
        return matcher.matches();
    }

    public static Boolean isDate(String value) {

        Matcher matcher = datePattern.matcher( value );
        return matcher.matches();
    }

    public static Datetime parseJSONDateTime(String dateString) {
        String s = '{ "d" : "' + dateString +'"  }';

        JSONParser parser = JSON.createParser(s);
        parser.nextToken();
        parser.nextValue();

        Datetime dt = parser.getDateTimeValue();
        return dt;
    }
}