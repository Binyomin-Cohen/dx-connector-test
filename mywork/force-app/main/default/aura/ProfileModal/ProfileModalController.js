({
  init : function(component, event, helper) {
    BW.ProfilesCommon.init({
      inLightning : true
    });
  },
  apply : function(component, event, helper) {
    var data = BW.ProfilesCommon.getSelectedData();
    BW.ProfilesCommon.closeProfilePermissions();
    BW.LTCommon.fireGoogleAnalyticsTrackingEvent('compdoc', 'applyPermissionChanges', 'profiles - apply');
    var saveEvt = component.getEvent("CompDocProfileApply");
    saveEvt.setParam("data", data);
    saveEvt.fire();
  }
})