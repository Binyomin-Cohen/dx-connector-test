({
  authorizeInstance : function(component) {
    var instanceId = component.get('v.instanceId');
    var authorizeAction = component.get('c.auraAuthorizeInstance');
    var self = this;

    authorizeAction.setParams({
      "instanceId" : instanceId,
      "isForTools" : component.get('v.isForTools')
    });

    authorizeAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var authURL = data.getReturnValue();
        self.startPollingForAuthUpdate(component, instanceId);
        // TODO: change the dimensions. Popup won't open without them, though
        var popup = window.open(authURL, component.get("v.popupId"),'height=600,width=500');
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(authorizeAction);

    component.getEvent('authInitEvent').fire();
  },

  promptChangeAuthorizedCredentials: function(component) {
    var oauthCard = component.find('oauth-container');
    $A.util.removeClass(oauthCard, 'authorized');
    $A.util.addClass(oauthCard, 'unauthorized');
  },

  getAuthStatus : function(component) {
    var instanceId = component.get('v.instanceId');
    var getAuthStatusAction = component.get('c.auraGetAuthStatus');
    var self = this;

    getAuthStatusAction.setParams({
      "instanceId" : instanceId,
      "isForTools" : component.get('v.isForTools')
    });

    getAuthStatusAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var authInfo = data.getReturnValue();

        var isAuthorized = (authInfo === null) ? false : authInfo.isAuthorized;
        var isAuthorizedClass = (isAuthorized) ? 'authorized' : 'unauthorized';

        component.set('v.authorizedUser', (isAuthorized) ? authInfo.preferred_username : "");
        component.set('v.isAuthorized', isAuthorized);
        component.set('v.isChangingAuth', false);

        var oauthCard = component.find('oauth-container');
        $A.util.removeClass(oauthCard, 'authorized');
        $A.util.removeClass(oauthCard, 'unauthorized');
        $A.util.addClass(oauthCard, isAuthorizedClass);
        self.fireChangeEvent(component, instanceId, isAuthorized);
      };

      options.errorCb = function(message) {
        var msgType = 'error';
        BW.LTCommon.addPageMessage(msgType, message);
        self.fireChangeEvent(component, instanceId, false);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(getAuthStatusAction);
  },

  fireChangeEvent : function(component, instanceId, isAuthorized) {
   var authChangeEvent = component.getEvent('authChangeEvent');
    authChangeEvent.setParams({
      'instanceId' : instanceId,
      'isAuthorized' : isAuthorized
    });
    authChangeEvent.fire();
  },

  navigateToURL : function(component, url) {
    var navEvent = $A.get("e.force:navigateToURL");

    if (navEvent) {
      //in lightning experience
      navEvent.setParams({
        "url": url
      }).fire();
    } else {
      window.location.href = url;
    }
  },

  getAuthStatusFromCache : function(component, instanceId, cbFn) {
    var authStatusAction = component.get('c.getOAuthInProgressStatusFromCache');

    authStatusAction.setParams({
      "instanceId" : instanceId
    });

    authStatusAction.setCallback(this, function(data) {
      var options = {},
          isInProgress;
      options.successCb = function() {
        isInProgress = data.getReturnValue();
        cbFn(isInProgress);
      };
      options.errorCb = function() {
        isInProgress = false;
        cbFn(isInProgress);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(authStatusAction);
  },

  startPollingForAuthUpdate : function(component, instanceIdToPollFor) {
    var authPollId = '' + (new Date()).getTime();
    component.set('v.authPollId', authPollId);
    this.pollForAuthUpdate(component, instanceIdToPollFor, authPollId);
  },

  pollForAuthUpdate : function(component, instanceIdToPollFor, pollId) {
    var self = this,
        authPollIntervalMs = component.get("v.authPollIntervalMs");

    if (pollId !== component.get('v.authPollId')) {
      return;
    }

    self.getAuthStatusFromCache(component, instanceIdToPollFor, function (isInProgress) {
      if (isInProgress) {
        setTimeout($A.getCallback(function() {
          self.pollForAuthUpdate(component, instanceIdToPollFor, pollId);
        }), authPollIntervalMs);
      } else {
        self.getAuthStatus(component);
      }
    });
  },

  toggleDisable : function(component) {
    var oAuthContainer = component.find('oauth-container');

    if (component.get('v.disable')) {
      $A.util.addClass(oAuthContainer, 'disabled');
    } else {
      $A.util.removeClass(oAuthContainer, 'disabled');
    }
  }

});