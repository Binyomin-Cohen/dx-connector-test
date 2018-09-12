({
  displayProfilePermissions: function(component, event, helper ) {
    helper.displayProfilePermissions( component, $(event.currentTarget) );
  },
  deleteProfile: function(component, event, helper) {
    event.stopPropagation();
    helper.handleDeleteClick(component, event, component.get("v.profile.profileName"));
  }
})