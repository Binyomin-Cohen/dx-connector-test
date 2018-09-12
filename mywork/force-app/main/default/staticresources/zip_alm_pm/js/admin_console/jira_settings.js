(function() {
  var init = function ($, AlmCommon, ApiBuilder) {
    "use strict";

    //on document ready
    $(function(){
      addEventHandlers();
      doWindowResize();
    });

    function addEventHandlers() {
      $(window).on("resize", doWindowResize);
      $("#alm-container").on("click", ".save-btn", saveCustomSetting);
      $("#alm-container").on("click", "#project-sync", startProjectPull);
    }

    function saveCustomSetting() {
        clearErrorMsg();
        AlmCommon.blockUI('#main-content');
        afSaveCustomSetting();
    }

    function startProjectPull() {
      $(this).addClass('syncing');
      afPullProjects();
    }

    function finishCustomSettingSave() {
        AlmCommon.unblockUI('#main-content');
    }

    function finishProjectPull() {
      $('#project-sync').removeClass('syncing');
    }

    // Clears and hides the error message panel.
    function clearErrorMsg() {
        AlmCommon.clearMsgs();
    }

    function doWindowResize() {
      AlmCommon.windowResize('#main-content .panel-content', '', 132, 0);
    }

    return new ApiBuilder({
        pure: {
            finishCustomSettingSave : finishCustomSettingSave,
            finishProjectPull: finishProjectPull
        },
        testOnly: {

        }
      }).getApi();
  };

  define(
    [
     'jquery',
     'js_alm_common',
     'api_builder'
    ], function() {

    var $ = arguments[0];
    var AlmCommon = arguments[1];
    var ApiBuilder = arguments[2];

    var API = init($, AlmCommon, ApiBuilder);

    window.BW = window.BW || {};
    window.BW.jiraSettings = API;

    return API
  });

})();
