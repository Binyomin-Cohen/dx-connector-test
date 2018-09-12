public with sharing class ScanRequest {
	public Id orgId;
    public List<SCANServices.SCANJob> jobs;

    public ScanRequest(List<SCANServices.SCANJob> jobs) {
        orgId = UserInfo.getOrganizationId();
        this.jobs = jobs;
    }
}