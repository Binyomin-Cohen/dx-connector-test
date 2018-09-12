/**
 * ExLog is a utility for logging exceptions in a robust manner.
 *
 * @author      Will Saunders
 * @author      Bluewolf
 */

public class ExLog {

    ///////////////////////////////////////////////////////
    //////			Constants
    ///////////////////////////////////////////////////////


    public static final Boolean UNPACK_EXCEPTIONS = true;
    public static final Boolean DONT_UNPACK_EXCEPTIONS = !UNPACK_EXCEPTIONS;

    private static final String TRACE_PREFACE = 'EXCEPTION!!! - ';
    private static final String SINGLE_LINE_DELIM = '\n';
    private static final String DESC_LINE_DELIM = SINGLE_LINE_DELIM + SINGLE_LINE_DELIM;

    private static final Boolean WILL_INSERT = true;
    private static final Boolean WONT_INSERT = !WILL_INSERT;

    private static final Integer DESCRIPTION_MAX_LENGTH = Schema.Logged_Exception__c.Exception_Description__c.getDescribe().getLength();

    private static ExLogConfig exLogConfig = new ExLogConfig();
    private static Map<String, Id> apexClassName2Id = new Map<String, Id>();
    private static List<Logged_Exception__c> logsToFlush = new List<Logged_Exception__c>();
    private static Logged_Exception__c PARENTLESS_LOG_KEY = new Logged_Exception__c();

    public Enum Level { HIGH, MEDIUM, LOW }

    private static Level currentMode = Level.LOW;

    private ExLog() { }

    public static void log( System.Exception exceptionToLog, ExLogConfig exLogConfigParam ) {

        exLogConfig = exLogConfigParam;

        log( exceptionToLog );
    }

    public static void log( System.Exception exceptionToLog ) {

        log( exceptionToLog, null, ALMLogServices.LogLevel.ERROR);
    }

    public static void log( System.Exception exceptionToLog, ALMLogServices.Application application, ALMLogServices.LogLevel logLevel) {

        String appStr = (application == null) ? '' : application.name();
        String logLevelStr = (logLevel == null) ? '' : logLevel.name();
        List<Logged_Exception__c> exLogsToSave = loggedExceptionFactory( exceptionToLog, UserInfo.getUserId(), appStr, logLevelStr );

        saveLogs( exLogsToSave );

    }

    private static List<Logged_Exception__c> loggedExceptionFactory( System.Exception anExToLog, Id whoCausedId, String application, String logLevel) {

        List<Logged_Exception__c> logs = new List<Logged_Exception__c>();

        String className = ( exLogConfig.level == Level.HIGH ) ? extractClassName( anExToLog.getStackTraceString() ) : '';

        Logged_Exception__c exLog = new Logged_Exception__c( Who__c = whoCausedId,
                                                             Type__c = anExToLog.getTypeName(),
                                                             Line_Number__c = anExToLog.getLineNumber(),
                                                             Class_Name__c = className,
                                                             Organization_Id__c = UserInfo.getOrganizationId(),
                                                             Organization_Name__c = UserInfo.getOrganizationName(),
                                                             Exception_Description__c = createExDescription( anExToLog ).abbreviate(DESCRIPTION_MAX_LENGTH),
                                                             Log_Level__c = logLevel,
                                                             Application__c = application);

        if ( exLogConfig.level == Level.HIGH ) {
            exLog.Class_Id__c = resolveClassId( className );
        }

        logs.add( exLog );

        return logs;
    }

    private static String createExDescription( System.Exception anExToLog ) {

        String exDescription = anExToLog.getMessage() + DESC_LINE_DELIM + anExToLog.getStackTraceString();

        if ( anExToLog.getCause() != null )
            exDescription += '\n\n' + createExDescription( anExToLog.getCause() );

        return exDescription;

    }

    private static String extractClassName( String stackTrace ) {

        String className = '';

        List<String> stackPieces = stackTrace.split( ':' );

        if ( !stackPieces.isEmpty() )
            className = stackPieces[0];

        List<String> classNamePieces = className.split( '\\.' );

        className = classNamePieces[0];

        for( Integer i = 1; i < classNamePieces.size() - 1; i++) {
            className += '.' + classNamePieces[i];
        }

        return className;
    }

    private static Id resolveClassId( String className ) {

        if ( apexClassName2Id.containsKey( className ) )
            return apexClassName2Id.get( className );

        Id classId;

        List<String> namePieces = className.split('\\.');

        String codeType = namePieces[0];

        if (namePieces.size() < 2) {
            return null;
        }

        String name = (namePieces.size() == 3) ? namePieces[2] : namePieces[1];

        try {

            if ( codeType == 'Class' ) {

                classId = [ SELECT Id FROM ApexClass WHERE Name LIKE :name+'%' ].Id;

            } else if ( codeType == 'Trigger' ) {

                classId = [ SELECT Id FROM ApexTrigger WHERE Name LIKE :name+'%' ].Id;
            }

            apexClassName2Id.put( className, classId );

            return classId;

        } catch( System.Exception ex ) { }

        return null;

    }

    private static String createExDescription( System.Dmlexception aDmlExToLog ) {

        String dmlExceptionDescription = aDmlExToLog.getNumDml() + ' DML lines involved in this Exception: ' + SINGLE_LINE_DELIM;

        for ( Integer dmlErrIndex = 0; dmlErrIndex < aDmlExToLog.getNumDml(); dmlErrIndex++ )
            dmlExceptionDescription += createDmlExDescription( aDmlExToLog, dmlErrIndex ) + SINGLE_LINE_DELIM;

        return dmlExceptionDescription + DESC_LINE_DELIM + createExDescription( (System.Exception) aDmlExToLog );

    }

    private static String createDmlExDescription( System.Dmlexception aDmlExToLog, Integer dmlErrIndex ) {

        String dmlErrorDescription = aDmlExToLog.getDmlMessage( dmlErrIndex ) + SINGLE_LINE_DELIM;
        dmlErrorDescription += 'Status Code: ' + aDmlExToLog.getDmlStatusCode( dmlErrIndex );
        dmlErrorDescription += ', Type: ' + aDmlExToLog.getDmlType( dmlErrIndex ) + SINGLE_LINE_DELIM;
        dmlErrorDescription += 'on row with' + ( ( aDmlExToLog.getDmlId( dmlErrIndex ) == null ) ? 'out ID ' : ' ID of ' + aDmlExToLog.getDmlId( dmlErrIndex )  + ' ' ) + ', ';
        dmlErrorDescription += 'on fields ' + aDmlExToLog.getDmlFieldNames( dmlErrIndex );

        return dmlErrorDescription;
    }

    private static void saveLogs( List<Logged_Exception__c> logsToSave ) {

        if ( exLogConfig.flushable )
            logsToFlush.addAll( logsToSave );
        else
            insert logsToSave;

    }

    public static void flushLogCache() {

        if ( !logsToFlush.isEmpty() ) {

            insert logsToFlush;

            logsToFlush.clear();

        }

    }

    public class ExLogConfig {
                                                // Defaults
        public ExLog.Level level = 				ExLog.Level.HIGH;
        public Boolean flushable =				false;
        public List<String> peopleToEmail = 	new List<String>();

        public ExLogConfig() { }

    }

    public class ExLogException extends System.Exception { }

}