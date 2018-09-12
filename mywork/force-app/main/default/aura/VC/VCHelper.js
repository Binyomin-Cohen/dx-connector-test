({

  togglePublicKey : function(component) {
    var templateText = component.find('template-key');
    var publicKeyTextArea = component.find('public-key');
    var clipboardCopyLink = component.find('copy-to-clipboard-link');

    $A.util.toggleClass(templateText, 'invisible');
    $A.util.toggleClass(publicKeyTextArea, 'invisible');
    $A.util.toggleClass(clipboardCopyLink, 'invisible');

    if ($A.util.hasClass(publicKeyTextArea, 'invisible')) {
      component.set('v.existingKeyLabel', 'SHOW KEY');
    } else {
      component.set('v.existingKeyLabel', 'HIDE KEY');
    }
  },

  addPageMessage : function(type, message) {
    var pageMessageAddEvent = $A.get('e.c:pageMessageAdd');
    pageMessageAddEvent.setParams({
      'type' : type,
      'message' : message
    });
    pageMessageAddEvent.fire();
  },

  clearPageMessages : function(type, message) {
    $A.get('e.c:pageMessagesClear').fire();
  },

  copyToClipboard: function(component, textToCopy) {
    var placeHolderDomElement = document.createElement('textarea');
    placeHolderDomElement.value = textToCopy;
    document.body.appendChild(placeHolderDomElement);
    placeHolderDomElement.focus();
    placeHolderDomElement.select();
    document.execCommand('copy');
    document.body.removeChild(placeHolderDomElement);
    component.find("copy-to-clipboard-link").focusButton();
  },

  generateKeys : function(component, event, helper) {
    var action = component.get('c.generateKeypair');
    action.setCallback(this, function(data) {
      var options = {
        successCb : function() {
          helper.clearPageMessages();

          component.set('v.userHasExistingKeypair', true);
          var repoSection = component.find('repo-section');
          $A.util.toggleClass(repoSection, 'section-disabled');
          BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Version Control', 'Generate User SSH Key');
        },
        errorCb : function(errorMessage) {
          helper.addPageMessage("error", errorMessage);
        }
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  },

  showPublicKey : function(component, event, helper) {
    var publicKeyOnPage = component.get('v.publicKey');
    if ($A.util.isEmpty(publicKeyOnPage)) {
      var action = component.get('c.retrievePublicKey');
      action.setCallback(this, function(data) {
        var options = {
          successCb : function() {
            helper.clearPageMessages();
            component.set('v.publicKey', data.getReturnValue());
            helper.togglePublicKey(component);
          },
          errorCb : function(errorMessage) {
            helper.addPageMessage("error", errorMessage);
          }
        };
        BW.LTCommon.auraCallbackHandler(data, options);
      });
      $A.enqueueAction(action);
    } else {
      helper.clearPageMessages();
      helper.togglePublicKey(component);
    }
  }
});