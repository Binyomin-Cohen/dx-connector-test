(function(global) {
  var init = function($, ApiBuilder, AlmCommon, ComponentSearch, ProfilesCommon) {

    function init() {
      addEventHandlers();
      ProfilesCommon.init({
        includeProfilePermissionsFromSourceOnly:true
      });
    }

    function addEventHandlers() {
      $("#alm-container").on( "click", ".delete-icon", handleDeleteClick);
      $("#alm-container").on( "click", ".delete-all", handleDeleteClick);
      $( document ).on( "click", "#delete-modal .subtle-btn", removeProfile);
      $( document ).on( "click", "#delete-modal .continue-btn", function() {
        AlmCommon.unblockUI();
      });
    }

    function handleDeleteClick(event) {
      var modalText = "Are you sure you want to remove";

      var clickedElement = event.currentTarget;
      if ($(clickedElement).hasClass("delete-all")) {

        $('#profile-to-remove').val('all');

        modalText += "<br/>all profiles?";
      } else {
        var card = clickedElement.parentElement;
        var profileName = $(card.children[1]).text();
        var profileKey = $(card).data('key');

        $('#profile-to-remove').val(profileKey);

        modalText += " the <br/><b>" + profileName + "</b> profile?";
      }

      $('#delete-modal #modal-text').html(modalText);

      AlmCommon.displayModal({
        content: $("#delete-modal"),
        width: '30%'
      });

      event.stopPropagation();
    }

    function removeProfile() {
      AlmCommon.setHasUnsavedChanges(true);
      var profileKeyToRemove = $('#profile-to-remove').val();

      if (profileKeyToRemove == 'all') {
        $('.profile-tile').each(function() {
          ComponentSearch.removeComponent($(this).data('key'));
        });
      } else {
        ComponentSearch.removeComponent(profileKeyToRemove);
      }

      AlmCommon.unblockUI();
      afRemoveProfiles(profileKeyToRemove);
      AlmCommon.blockUI( "div[id$='profile-display']" );
    }

    return new ApiBuilder({
      pure: {
        init: init
      },
      testOnly: {
        addEventHandlers : addEventHandlers,
      }
    }).getApi();
  };

  if (typeof define === "function") {
    define([
      'jquery',
      'api_builder',
      'js_alm_common',
      'client_comp_search_results',
      'common/profiles',
      'external/jquery.sticky-kit'
    ], function($, ApiBuilder, AlmCommon, ComponentSearch, ProfilesCommon) {
      var API = init($, ApiBuilder, AlmCommon, ComponentSearch, ProfilesCommon);
      return API;
    });
  } else {
    var API = init(global.jQuery, global.ApiBuilder, global.BW.AlmCommon, global.ComponentSearch, global.BW.ProfilesCommon);
    return API;
  }
})(this);