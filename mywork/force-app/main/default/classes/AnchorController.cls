public class AnchorController {

    @auraEnabled
    public static String getNamespace() {
        return SObjectServices.CURRENT_NAMESPACE;
    }
}