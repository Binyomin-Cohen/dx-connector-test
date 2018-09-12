(function() {
  var init = function ($, AlmCommon, ApiBuilder, OAuth, RequestManager) {
    "use strict";

    //on document ready
    $(function(){
      addEventHandlers();
      initializeSelect();
      loadState();
      RequestManager.invokeFunction(afCheckAuthUser);
      doWindowResize();
      RequestManager.invokeFunction(afExpirePageState);
    });

    function addEventHandlers() {
      $(window).on("resize", doWindowResize);
      $("#alm-container").on("click", ".save-btn:not(.inactive)", save);

      OAuth.init( {
        pageStateConfig : {
          saveAction : afSavePageState,
          expireAction : afExpirePageState
        },
        handleFinishPolling: function() {
          checkAuthStatus(false);
          RequestManager.invokeFunction(afCheckAuthUser);
        }
      });
      AlmCommon.onWatchedInputChange(onInputChange);

      AlmCommon.addBeforeUnloadEventListener();
    }

    function initializeSelect() {
      $('#alm-settings-type-select')
        .val(getCurrentInstanceType())
        .almSelectMenu({
          change: onInstanceTypeChanged,
          isRequired : true,
          placeholder: 'Instance Type',
        });
    }

    function onInstanceTypeChanged( event, ui ) {
      var $this = $(this);
      var value = $this.val();
      $this.siblings('span#alm-settings-type-select-button').addClass('selected');
      $this.siblings('input').val(value).trigger('input');
      $this.almSelectMenu('refresh');
      onInputChange();
    }

    function getCurrentInstanceName() {
      return $('[id$="alm-settings-name-input"]').val();
    }

    function setCurrentInstanceName(name) {
      $('[id$="alm-settings-name-input"]').val(name);
    }

    function getCurrentInstanceType() {
      return $('[id$="alm-settings-types-filter"]').val();
    }

    function setCurrentInstanceType(type) {
      $('#alm-settings-type-select').val(type);
      onInstanceTypeChanged.call($('#alm-settings-type-select'));
    }

    function getCurrentInstanceCustomDomain() {
      return $('[id$="alm-settings-custom-domain-input"]').val();
    }

    function setCurrentInstanceCustomDomain(domain) {
      $('[id$="alm-settings-custom-domain-input"]').val(domain);
    }

    function loadState() {
      var pollOAuthId = AlmCommon.getUrlParameter('pollOAuthId');
      if (pollOAuthId) {
        window.history.pushState('', '', 'AdminAlmSettings');
        OAuth.initPollOAuthUpdate(pollOAuthId, null, null);
      }

      checkAuthStatus(true);

      if ($('input[id$="is-page-restored"]').val() === 'true') {
        setHasUnsavedChanges(true);
      }
    }

    function checkAuthStatus(blockUI) {
      var instanceId = $('#oauth-container').data('instance-id');
      if (instanceId) {
        if(blockUI) {
          AlmCommon.blockUI('#main-content');
        }
        OAuth.getAuthStatus({
          selectedInstanceId : instanceId,
          oauthContainer : '#oauth-container',
          successCallback : function onSuccess(authInfo) {
            var preferredUser = (authInfo === null) ? "" : authInfo.preferred_username;
          
            $('#oauth-container')
             .attr('title', preferredUser)
             .find('.authorized-user').text(preferredUser);
          },
          errorCallback : function onError(err) {
            AlmCommon.showError(err);
            AlmCommon.unblockUI('#main-content');
          },
          onComplete : function onComplete() {
            AlmCommon.unblockUI('#main-content');
          }
        });
      } else {
        AlmCommon.unblockUI('#main-content');
      }
    }

    function save() {
      AlmCommon.blockUI('#main-content');
      AlmCommon.clearMsgs();

      OAuth.setPageStateTriggers(false);

      afSave();
    }

    function setHasUnsavedChanges(hasUnsavedChanges) {
      if (hasUnsavedChanges === true) {
        AlmCommon.setHasUnsavedChanges(hasUnsavedChanges);

        $('.save-btn').removeClass('inactive');
        $('#oauth-container').addClass('disabled');
      } else {
        if (!AlmCommon.hasSaveErrors()) {
          AlmCommon.setHasUnsavedChanges(hasUnsavedChanges);
        }

        $('.save-btn').addClass('inactive');
        $('#oauth-container').removeClass('disabled');
      }
    }

    function onInputChange() {
      setHasUnsavedChanges(true);
    }

    function finishSave() {
      setHasUnsavedChanges(false);

      checkAuthStatus();

      initializeSelect();
      doWindowResize();
    }

    function finishExpire() {
      RequestManager.completeFunction();
    }

    function finishCheckAuthUser() {
      RequestManager.completeFunction();
    }

    function doWindowResize() {
      AlmCommon.windowResize('#main-content .alm-settings', '', 132, 0);
    }

    return new ApiBuilder({
      pure: {
        finishSave: finishSave,
        finishExpire: finishExpire,
        finishCheckAuthUser: finishCheckAuthUser
      },
      testOnly: {
      }
    }).getApi();
  };

  define(
    [
     'jquery',
     'js_alm_common',
     'api_builder',
     'alm_selectmenu',
     "oauth",
     'common/request-manager'
    ], function() {

    var $ = arguments[0];
    var AlmCommon = arguments[1];
    var ApiBuilder = arguments[2];
    var oauth = arguments[4];
    var RequestManager = arguments[5];

    var API = init($, AlmCommon, ApiBuilder, oauth, RequestManager);

    window.BW = window.BW || {};
    window.BW.adminAlmSettings = API;

    return API;
  });

})();