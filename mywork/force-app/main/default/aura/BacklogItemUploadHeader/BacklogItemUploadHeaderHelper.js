({
  next : function( component ) {
    var CREATE_RECORD_STEP = 3,
     BACKLOG_MGMT_URL = "/apex/BacklogManagement",
     step = component.get("v.step");
     step++;

    if (step === CREATE_RECORD_STEP) {
      BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Bulk Import Backlog Items', 'Create Backlog Item', 'Backlog - Create Backlog Items in Bulk');
    }
    if (step > CREATE_RECORD_STEP) {
      BW.AlmCommon.navigateTo(BW.LTCommon.buildNamespaceFriendlyUrl(BACKLOG_MGMT_URL, component.get('v.namespace')));      
    }

    component.set("v.step", step);
  },
  previous : function( component ) {
    var step = component.get("v.step");
    step--;
    component.set("v.step", step);
  },
  adjustButtons : function(component) {
    var step = component.get("v.step");
    var nextButton = component.find("nextButton");
    var prevButton = component.find("prevButton");

    var prevButtonDisabled = prevButton.get("v.disabled");
    var nextButtonDisabled = nextButton.get("v.disabled");

    var totalWizardSteps = component.get( "v.stepComponentList" ).length - 1;

    if (step == 0 && !nextButtonDisabled) {
      nextButton.set("v.disabled", true);
    }
    else if (step > 1 && step < totalWizardSteps && nextButtonDisabled){
      nextButton.set("v.disabled", false);
    }
    if ((step == 0 && !prevButtonDisabled) || step >= totalWizardSteps) {
      prevButton.set("v.disabled", true);
    }
    if (step > 0 && prevButtonDisabled){
      prevButton.set("v.disabled", false);
    }
  },
  toggleNextButton : function(component) {
    var enableNextButton = component.get("v.enableNextButton");
    var nextButton = component.find("nextButton");
    var nextButtonDisabled = nextButton.get("v.disabled");

    if( enableNextButton && nextButtonDisabled ){
      nextButton.set("v.disabled", false);
    }
    else if( !enableNextButton && !nextButtonDisabled){
      nextButton.set("v.disabled", true);
    }
  }
})