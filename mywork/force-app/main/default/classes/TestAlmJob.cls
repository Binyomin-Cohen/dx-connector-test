@isTest
private class TestAlmJob {
    private static DateTime startTime;
    private static DateTime endTime;
    private static ALMJob job;

    static void setup(Integer startHour, Integer endHour) {
        setup(startHour, 0, endHour, 0);
    }

    static void setup(Integer startHour, Integer startMinute, Integer endHour, Integer endMinute) {
        startTime = DateTime.newInstance(2016, 1, 1, startHour, startMinute, 0);
        endTime = DateTime.newInstance(2016, 1, 1, endHour, endMinute, 0);

        job = new ALMJob(new ALM_Job__c(
            Scheduled_Start_Time__c = startTime,
            Scheduled_End_Time__c = endTime
          )
        );
    }

    private static testMethod void currentTimeIsBetweenSchedule() {
        Integer currentHour = DateTime.now().hour();
        Integer startHour = currentHour - 1;
        Integer endHour = currentHour + 1;

        setup(startHour, endHour);

        Boolean result = job.currentTimeIsBetweenSchedule();

        System.assertEquals(true, result, 'The current hour should be within the schedule');
    }

    private static testMethod void currentTimeIsBetweenSchedule_currentTimeBeforeStartTime() {
        Integer currentHour = DateTime.now().hour();
        Integer startHour = currentHour + 2;
        Integer endHour = currentHour + 4;

        setup(startHour, endHour);

        Boolean result = job.currentTimeIsBetweenSchedule();

        System.assertEquals(false, result, 'The current hour should not be in the current schedule when it is before the scheduled start time');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_startInvalid() {
        Integer currentHour = DateTime.now().hour();
        Integer startHour = currentHour + 1;
        Integer startMinute = 30;
        Integer endHour = currentHour + 2;
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule();

        System.assertEquals(false, result, 'Current hour is before the scheduled start time');
    }

    private static testMethod void currentTimeIsBetweenSchedule_endTimeBeforeStartTime_outsideRange() {
        Integer currentHour = 8;
        Integer startHour = currentHour + 2;
        Integer startMinute = 30;
        Integer endHour = currentHour - 1;
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(currentHour, 0);

        System.assertEquals(false, result, 'Current time should be past the scheduled time');
    }

    private static testMethod void currentTimeIsBetweenSchedule_endTimeBeforeStartTime_insideRange_beforeMidnight() {
        Integer currentHour = 23;
        Integer startHour = currentHour - 1;
        Integer startMinute = 0;
        Integer endHour = 6;
        Integer endMinute = 0;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(currentHour, 0);

        System.assertEquals(true, result, 'Current time should be in the range when it is after the start time');
    }

    private static testMethod void currentTimeIsBetweenSchedule_endTimeBeforeStartTime_insideRange_afterMidnight() {
        Integer currentHour = 5;
        Integer startHour = 22;
        Integer startMinute = 0;
        Integer endHour = currentHour + 1;
        Integer endMinute = 0;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(currentHour, 0);

        System.assertEquals(true, result, 'Current time should be in the range when it is before the end time');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_endInvalid() {
        Integer currentHour = DateTime.now().hour();
        Integer startHour = currentHour - 5;
        Integer startMinute = 30;
        Integer endHour = currentHour - 2;
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule();

        System.assertEquals(false, result, 'Current hour is after the scheduled end time');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_startAndEndValid() {
        Integer currentHour = DateTime.now().hour();
        Integer startHour = currentHour - 2;
        Integer startMinute = 30;
        Integer endHour = currentHour + 1;
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule();

        System.assertEquals(true, result, 'Current time is between the scheduled start and end times');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_startHourEqualsCurrentHour() {
        Integer currentHour = DateTime.now().hour();
        Integer startHour = currentHour;
        Integer startMinute = 30;
        Integer endHour = currentHour + 1;
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule();

        Integer currentMinute = DateTime.now().minute();
        if (currentMinute >= 30) {
            System.assertEquals(true, result, 'Current minute is equal or after the half hour mark.');
        } else {
            System.assertEquals(false, result, 'Current minute is before the half hour mark.');
        }
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_endHourEqualsCurrentHour() {
        Integer currentHour = DateTime.now().hour();
        Integer startHour = currentHour - 1;
        Integer startMinute = 30;
        Integer endHour = currentHour;
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule();

        Integer currentMinute = DateTime.now().minute();
        if (currentMinute > 30) {
            System.assertEquals(false, result, 'Current minute is after the half hour mark.');
        } else {
            System.assertEquals(true, result, 'Current minute is equal or before the half hour mark.');
        }
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_startHourEqualsCurrentHour_valid() {
        Integer currentHour = 15;
        Integer currentMinute = 30;
        Integer startHour = currentHour;
        Integer startMinute = currentMinute;
        Integer endHour = currentHour + 1;
        Integer endMinute = currentMinute;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(currentHour, currentMinute);

        System.assertEquals(true, result, 'Current minute is equal or after the half hour mark.');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_startHourEqualsCurrentHour_invalid() {
        Integer currentHour = 15;
        Integer currentMinute = 29;
        Integer startHour = currentHour;
        Integer startMinute = 30;
        Integer endHour = currentHour + 1;
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(currentHour, currentMinute);

        System.assertEquals(false, result, 'Current minute is before the half hour mark.');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_endHourEqualsCurrentHour_valid() {
        Integer currentHour = 15;
        Integer currentMinute = 30;
        Integer startHour = currentHour - 1;
        Integer startMinute = 30;
        Integer endHour = currentHour;
        Integer endMinute = currentMinute;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(currentHour, currentMinute);

        System.assertEquals(true, result, 'Current minute is equal or before the half hour mark.');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHour_endHourEqualsCurrentHour_invalid() {
        Integer currentHour = 15;
        Integer currentMinute = 31;
        Integer startHour = currentHour - 1;
        Integer startMinute = 30;
        Integer endHour = currentHour;
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(currentHour, currentMinute);

        System.assertEquals(false, result, 'Current minute is after the half hour mark.');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHourSpread_valid() {
        DateTime now = DateTime.now();
        Integer startHour = now.hour();
        Integer startMinute = 0;
        Integer endHour = now.hour();
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(now.hour(), 15);

        System.assertEquals(true, result, 'A candidate time inside of a half-hour spread should fall within the scheduled interval.');
    }

    private static testMethod void currentTimeIsBetweenSchedule_halfHourSpread_invalid() {
        DateTime now = DateTime.now();
        Integer startHour = now.hour();
        Integer startMinute = 0;
        Integer endHour = now.hour();
        Integer endMinute = 30;

        setup(startHour, startMinute, endHour, endMinute);

        Boolean result = job.currentTimeIsBetweenSchedule(now.hour() + 1, 45);

        System.assertEquals(false, result, 'A candidate time outside of a half-hour spread should fall outside of the scheduled interval.');
    }

    private static testMethod void currentTimeIsBetweenSchedule_scheduledAllDay() {
        Integer startHour = 0;
        Integer startMinute = 0;
        Integer endHour = 0;
        Integer endMinute = 0;

        setup(startHour, startMinute, endHour, endMinute);

        // Assert that all times on a half-hour frequency cycle (starting at midnight) fall within the schedule interval.
        Integer halfHoursInADay = 48;
        for (Integer i = 0; i < halfHoursInADay; ++i) {
            Integer hour = i / 2;
            Integer minute = Math.mod(i, 2) * 30;

            DateTime currentHalfHour = DateTime.newInstance(0, 0, 0, hour, minute, 0);
            System.assertEquals(true, job.currentTimeIsBetweenSchedule(currentHalfHour), 'All candidate times should fall within an interval defined by equal start and end times.');
        }
    }
}