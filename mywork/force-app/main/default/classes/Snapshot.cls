public with sharing class Snapshot {
	public Snapshot(Integer revision, Datetime commitDate, String notes) {
		this.revision = revision;
		this.commitDate = commitDate;
		this.notes = notes;
	}

    public Integer revision { get; set; }
    public Datetime commitDate { get; set; }
    public String notes { get; set; }
}