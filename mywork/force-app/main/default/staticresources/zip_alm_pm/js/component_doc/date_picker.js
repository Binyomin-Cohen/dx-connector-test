(function() {
  var init = function ($, AlmCommon, ApiBuilder, moment, aljs) {

    //on document ready
    $(function () {
        initDatepicker();
    });

    function initDatepicker() {
      $("#start-date").datepicker({
        endDateInputId: "end-date"
      });

      $("#end-date").datepicker();
    }

    return new ApiBuilder({
      pure: {

      },
      testOnly: {
      }
    }).getApi();
  };// end init()

  define(
    [
      'jquery',
      'js_alm_common',
      'api_builder',
      'moment',
      'aljs-init',
      'aljs-datepicker'
    ], function() {
    var $ = arguments[0];
    var AlmCommon = arguments[1];
    var ApiBuilder = arguments[2];
    var moment = arguments[3];
    var aljs = arguments[5];

    var API = init($, AlmCommon, ApiBuilder, moment, aljs);
    return API;
  });

})();