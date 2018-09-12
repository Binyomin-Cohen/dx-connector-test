public with sharing class LimitServices {

    /**
    * Gets the remaining number of callouts that can be made due to governor limits
    */
    public static Integer getRemainingCalloutsAvailable() {
        return Limits.getLimitCallouts() - Limits.getCallouts();
    }

    /**
    * Gets the remaining number of future calls that can be made. (methods with the @future annotation)
    */
    public static Integer getRemainingFutureCallsAvailable() {
        return Limits.getLimitFutureCalls() - Limits.getFutureCalls();
    }

    /**
    * Gets the remaining number of DML records that can be manipulated.
    */
    public static Integer getRemainingDMLRecordsAvailable() {
        return Limits.getLimitDMLRows() - Limits.getDMLRows();
    }

    /**
    * Gets the remaining query count of DML records.
    */
    public static Integer getRemainingQueryRowsAvailable() {
        return Limits.getLimitQueryRows() - Limits.getQueryRows();
    }

}