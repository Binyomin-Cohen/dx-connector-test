public with sharing class ApexTestRequest {
    public List<ApexTestClass> testClasses;    
    public Integer maxFailedTests;
    public String testLevel;

    public enum TestLevel {
        Specific,
        Local,
        All
    }
    public static final String TEST_LEVEL_SPECIFIC = 'RunSpecifiedTests';
    public static final String TEST_LEVEL_LOCAL = 'RunLocalTests';
    public static final String TEST_LEVEL_ALL = 'RunAllTestsInOrg';
    public static final Map<TestLevel, String> TEST_LEVEL_MAP = new Map<TestLevel, String>{
        TestLevel.Specific => TEST_LEVEL_SPECIFIC,
        TestLevel.Local => TEST_LEVEL_LOCAL,
        TestLevel.All => TEST_LEVEL_ALL
    };

    public ApexTestRequest() {
        this.testClasses = null;
        this.maxFailedTests = -1;
        this.testLevel = TEST_LEVEL_LOCAL;
    }

    public ApexTestRequest(List<ApexTestClass> testClasses, Integer maxFailedTests, TestLevel testLevel) {
        this.testClasses = testClasses;
        this.maxFailedTests = maxFailedTests;
        this.testLevel = TEST_LEVEL_MAP.get(testLevel);
    }

    public class ApexTestClass {
        public String classId;
        public List<String> testMethods;

        public ApexTestClass(String classId, List<String> testMethods) {
            this.classId = classId;
            this.testMethods = testMethods;
        }
    }
}