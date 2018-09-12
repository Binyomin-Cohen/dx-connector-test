public with sharing class AsyncExLog implements Queueable {
    
    private System.Exception exceptionToLog;
    private ALMLogServices.Application application;
    private ALMLogServices.LogLevel logLevel;
    
    public AsyncExLog(System.Exception exceptionToLog, ALMLogServices.Application application, ALMLogServices.LogLevel logLevel){
        this.exceptionToLog = exceptionToLog;
        this.application = application;
        this.logLevel = logLevel;
    }
    
    public void execute(QueueableContext context) {
        ExLog.log(exceptionToLog, application, logLevel);
    }
}