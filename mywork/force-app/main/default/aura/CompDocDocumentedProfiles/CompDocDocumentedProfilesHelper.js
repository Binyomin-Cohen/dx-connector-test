({
  addEventListeners: function(component) {
    $(document).on("click", "#delete-modal .continue-btn", function() {
      BW.AlmCommon.unblockUI();
    });
  },
  loadProfiles: function(component) {
    var getProfilesAction = component.get("c.getProfileData");
    getProfilesAction.setParams({
      backlogItemId : component.get("v.backlogItemId")
    });

    getProfilesAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var profileData = data.getReturnValue();
        component.set("v.profiles", profileData.profileSelections);
        component.set("v.documentedComponents", profileData.documentedComponentsJSON);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(getProfilesAction);
  },
  deleteAllProfiles: function(component) {
    var profiles = component.get("v.profiles"),
    profileComponentIds =  [],
    profileKeys = [];

    var appEvent = $A.get("e.c:asyncSaveEvent");
    appEvent.setParams({ "isSaveComplete" : false });
    appEvent.fire();

    profiles.forEach(function(profile) {
      profileComponentIds.push(profile.backlogComponentId);
      profileKeys.push(profile.key);
    });

    var deleteAction = component.get("c.deleteSelectedComponents");
    deleteAction.setParams({
      backlogComponentIds : profileComponentIds
    });

    deleteAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        component.set("v.profiles", []);
        //TODO: Confirm this is not needed anymore.
        //BW.ComponentSearch.removeComponents(profileKeys);
        var appEvent = $A.get("e.c:asyncSaveEvent");
        appEvent.setParams({ "isSaveComplete" : true });
        appEvent.fire();
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(deleteAction);
  },
  handleDeleteAllClick: function(component) {
    var modalText = "Are you sure you want to remove <br/>all profiles?";

    $('#delete-modal #modal-text').html(modalText);

    BW.AlmCommon.displayModal({
      content: $("#delete-modal"),
      width: '30%'
    });
    var self = this;
    $("#delete-modal .subtle-btn").off("click").on( "click", $A.getCallback(function() {
      BW.AlmCommon.unblockUI();
      self.deleteAllProfiles(component);
    }));
  },
  saveProfile: function(component, event) {
    var profileData = event.getParam("data");
    var saveAction = component.get("c.saveDocumentedProfile");
    saveAction.setParams({
      backlogComponentId : profileData.backlogComponentId,
      includeEntireProfile : profileData.includeEntireProfile,
      selectedPermissionsJSON : JSON.stringify(profileData.selectedPermissions),
      autoIncludeDocumentedComponents: profileData.autoIncludePermissions
    });

    var appEvent = $A.get("e.c:asyncSaveEvent");
    appEvent.setParams({ "isSaveComplete" : false });
    appEvent.fire();

    saveAction.setCallback(this, function(data) {
      var options = {};
      options.cb = function() {
        var appEvent = $A.get("e.c:asyncSaveEvent");
        appEvent.setParams({ "isSaveComplete" : true });
        appEvent.fire();
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(saveAction);
  }

})
