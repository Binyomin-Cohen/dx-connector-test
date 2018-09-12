({
  doInit : function(component, event, helper) {
    var instanceId = component.get('v.instanceId'),
        popupId = (new Date()).getTime()+'';
    component.set("v.popupId", popupId);

    if (instanceId) {
      helper.getAuthStatus(component);
    }

    helper.toggleDisable(component);
  },

  authorizeInstanceClick : function(component, event, helper) {
    helper.authorizeInstance(component);
  },

  getAuthStatus : function(component, event, helper) {
    helper.getAuthStatus(component);
  },

  cancelChangeAuth: function(component, event, helper) {
    component.set("v.isChangingAuth", false);
    var oauthCard = component.find('oauth-container');
    $A.util.addClass(oauthCard, 'authorized');
    $A.util.removeClass(oauthCard, 'unauthorized');
  },

  changeAuthorizedCredentials: function(component, event, helper) {
    if (event.target.className.indexOf('oauth-user-cancel') == -1 
      && component.get('v.isAuthorized') === true) {
      component.set("v.isChangingAuth", true);
      helper.promptChangeAuthorizedCredentials(component);
    }
  },

  handleToggleDisable : function(component, event, helper) {
    helper.toggleDisable(component);
  }

});
