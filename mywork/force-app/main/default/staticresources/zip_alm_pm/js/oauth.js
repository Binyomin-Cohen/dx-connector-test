(function(global) {
  var init = function($, AlmCommon, ApiBuilder) {

    var PAGE_STATE_MINIMUM_POLL_DELAY = 5000;
    var PAGE_STATE_TRIGGER_NAMESPACE = '.sightline-pagestate';

    var oAuthPopupId = (new Date()).getTime()+'';
    var currentOAuthPollingId = '';
    var pollPageStateTimeoutId = null;

    var config = {
        pageStateConfig : {
          saveDelay : null,
          saveAction : null,
          expireAction : null,
        },
        beforeAuthorizeInstance : null,
        afterAuthorizeInstance : null,
        authorizeInstance : function() {
          beforeAuthorizeInstance();
          authorizeInstance.call(this);
        },
        afterPromptChangeAuthorizedCredentials : null,
        afterCancelChangeAuthorizedCredentials : null,
        promptChangeAuthorizedCredentialsHandler : promptChangeAuthorizedCredentials,
        handleFinishPolling : function(instanceId, $oAuthContainer) {
          //TODO: provide default implementaiton
        }
    };

    function init(customConfig) {
      config = $.extend(config, customConfig);

      $('#alm-container').on(
        'click',
        '.oauth-container:not(.disabled) .unauthorized-icon, .oauth-container:not(.disabled) .unauthorized-text', config.authorizeInstance
      );
      $('#alm-container').on('click', '.oauth-container.authorized', config.promptChangeAuthorizedCredentialsHandler);
      $('#alm-container').on('click', '.oauth-user-cancel', function() {
        cancelChangeAuthorizedCredentials($(this).parent())
      });
    }

    function cancelChangeAuthorizedCredentials(oAuthContainer) {
      var $authCard = oAuthContainer;
      $authCard.removeClass('prompting unauthorized').addClass('authorized');
      $authCard.find('.unauthorized-text').text('Click to authorize');
      $authCard.find('.oauth-user-cancel').hide();
      $authCard.find('.authorized-icon').show();

      if (config.afterCancelChangeAuthorizedCredentials) {
        config.afterCancelChangeAuthorizedCredentials();
      }
    }

    function promptChangeAuthorizedCredentials() {
      var $authCard = $(this);
      $authCard.find('.authorized-icon, .unauthorized-icon').hide();

      $authCard.removeClass('authorized').addClass('prompting unauthorized');

      $authCard.find('.unauthorized-text').text('Change authorized credentials');

      $authCard.find('.oauth-user-cancel').show();

      if (config.afterPromptChangeAuthorizedCredentials) {
        config.afterPromptChangeAuthorizedCredentials();
      }
    }

    function setPageStateTriggers(isActivated) {
      if (AlmCommon.getProperty(config, 'pageStateConfig')) {
        var pageStateConfig = config.pageStateConfig;

        $('[data-page-persistence]').each(function(index, element) {
          var event = $(element).data('page-persistence');

          $(element).off(event + PAGE_STATE_TRIGGER_NAMESPACE);
          if (isActivated) {
            $(element).on(event + PAGE_STATE_TRIGGER_NAMESPACE, function() { startPollPageState(pageStateConfig.saveDelay); });
          }
        });
      }
    }

    function beforeAuthorizeInstance() {
      if (config.beforeAuthorizeInstance) {
        config.beforeAuthorizeInstance();
      }

      savePageState();
      setPageStateTriggers(true);
    }

    function afterAuthorizeInstance(instanceId, $oAuthContainer) {
      if (config.afterAuthorizeInstance) {
        config.afterAuthorizeInstance(instanceId, $oAuthContainer);
      }

      stopPollPageState();
      setPageStateTriggers(false);
      expirePageState();

      config.handleFinishPolling(instanceId, $oAuthContainer);
    }

    /**
     * Depends on remoteAuthorizeInstance being defined
     */
    function authorizeInstance() {
      var $oAuthContainer = $(this).closest('.oauth-container');
      var selectedInstanceId = $oAuthContainer.data('instance-id');

      if (typeof remoteAuthorizeInstance === 'undefined') {
        throw "remoteAuthorizeInstance must be defined in order to use the OAuth component.";
      }

      remoteAuthorizeInstance(selectedInstanceId, function(authURL, event) {
        if (!event.status && event.message) {
          AlmCommon.showError( event.message );
        } else {
          initPollOAuthUpdate(selectedInstanceId, $oAuthContainer, authURL);
        }
      });
    }

    function startPollPageState(delay) {
      if (AlmCommon.getProperty(config, 'pageStateConfig.saveAction')) {
        stopPollPageState();

        delay = (delay && (delay >= PAGE_STATE_MINIMUM_POLL_DELAY)) ? delay : PAGE_STATE_MINIMUM_POLL_DELAY;
        var timeoutId = window.setTimeout(function() {
          savePageState();
        }, delay);

        pollPageStateTimeoutId = timeoutId;
      }
    }

    function stopPollPageState() {
      window.clearTimeout(pollPageStateTimeoutId);
    }

    function savePageState() {
      if (AlmCommon.getProperty(config, 'pageStateConfig.saveAction')) {
        config.pageStateConfig.saveAction();
      }
    }

    function expirePageState() {
      if (AlmCommon.getProperty(config, 'pageStateConfig.expireAction')) {
        config.pageStateConfig.expireAction();
      }
    }

    function initPollOAuthUpdate(selectedInstanceId, $oAuthContainer, authURL) {
      var oAuthPollingId = (new Date()).getTime()+'';
      currentOAuthPollingId = oAuthPollingId;

      var popup = null;
      if (authURL) {
        popup = window.open(authURL, oAuthPopupId, 'height=700,width=500');
      }

      pollOAuthUpdate(selectedInstanceId, $oAuthContainer, popup, oAuthPollingId);
    }

    function pollOAuthUpdate(instanceId, $oAuthContainer, oAuthWindow, oAuthPollingId) {
      if (currentOAuthPollingId !== oAuthPollingId) {
        return;
      }

      var authPollIntervalMs = 3500;
      remoteGetOAuthInProgressStatus(instanceId, function(isInProgress, event) {
        if (!event.status && event.message) {
          if (event.message.indexOf('Logged in?') !== -1 && typeof global.location !== 'undefined') {
            AlmCommon.navigateTo(global.location.href + (global.location.href.indexOf('?') !== -1 ? "&" : "?") + "pollOAuthId=" + instanceId);
          } else {
            AlmCommon.showError( event.message );
          }
          
        } else {
          if ( isInProgress ) {
            if ( AlmCommon.getProperty(oAuthWindow, 'closed') ) {
              expirePageState();
              config.handleFinishPolling(instanceId, $oAuthContainer);
              return;
            }
            setTimeout(function() {
              pollOAuthUpdate(instanceId, $oAuthContainer, oAuthWindow, oAuthPollingId);
            }, authPollIntervalMs);
          } else {
            afterAuthorizeInstance(instanceId, $oAuthContainer);
          }
        }
      });
    }

    /**
     * Asynchronously retrieves the oauth status of an instance
     *
     * Depends on remoteGetAuthStatus being defined
     *
     * @param {Object} config:
     *  {String} selectedInstanceId - The instance id to retrieve an auth user for.
     *  {String} oauthContainer - The selector for the OAuth container.
     *  {Function} successCallback - A callback function that executes on success.
     *    This callback is passed an authInfo object when called.
     *  {Function} errorCallback - A callback function to handle any errors. This
     *    callback is passed an error message string when called.
     *  {Function} onComplete - A callback function to execute when complete.
     *
     */
    function getAuthStatus(config) {

      if (remoteGetAuthStatus === undefined) {
        throw "remoteGetAuthStatus must be defined in order to use the OAuth component."
      }

      remoteGetAuthStatus(config.selectedInstanceId, function(authInfo, event) {
        if (event.status) {
          var isAuthorized = (authInfo === null) ? false : authInfo.isAuthorized;
          var isAuthorizedClass = (isAuthorized) ? 'authorized' : 'unauthorized';
          $(config.oauthContainer)
            .removeClass('authorized unauthorized')
            .addClass(isAuthorizedClass);

          $(config.oauthContainer).removeClass('prompting');
          $(config.oauthContainer).find('.unauthorized-text').text('Click to authorize');
          $(config.oauthContainer).find('.oauth-user-cancel').hide();
          $(config.oauthContainer).find( '.' + ((isAuthorizedClass === 'authorized') ? 'unauthorized' : 'authorized')  + '-icon' ).hide();
          $(config.oauthContainer).find( '.' + isAuthorizedClass + '-icon' ).show();

          if (typeof config.successCallback === 'function') {
            config.successCallback(authInfo);
          }
        } else if (event.message) {
          if (typeof config.errorCallback === 'function') {
            config.errorCallback(event.message);
          }
        }

        if (typeof config.onComplete === 'function') {
          config.onComplete();
        }
      });
    }


    return new ApiBuilder({
      pure: {
        init: init,
        cancelChangeAuthorizedCredentials: cancelChangeAuthorizedCredentials,
        getAuthStatus: getAuthStatus,
        initPollOAuthUpdate : initPollOAuthUpdate,
        setPageStateTriggers : setPageStateTriggers,
        authorizeInstance : authorizeInstance
      },
      testOnly: {
        PAGE_STATE_MINIMUM_POLL_DELAY : PAGE_STATE_MINIMUM_POLL_DELAY
      }
    }).getApi();
  };

  if (typeof define === "function") {

    define(['jquery', 'js_alm_common', 'api_builder'], function($, AlmCommon, ApiBuilder) {
      var API = init($, AlmCommon, ApiBuilder);
      global.BW = global.BW || {};
      global.BW.oauth = API;
      return API;
    });
  } else {
    global.BW = global.BW || {};
    var API = init(global.jQuery, global.BW.AlmCommon, global.BW.ApiBuilder);
    global.BW.oauth = API;
    return API
  }
})(this);