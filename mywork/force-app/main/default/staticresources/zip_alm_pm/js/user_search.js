/**
 * Depends
 *   - BW
 *   - almautocomplete
 */
(function() {

  var init = function($, AlmCommon, ApiBuilder) {
    var roles = [],
      allUsers = [],
      existingUsers = [];

    function initAutoComplete(inputSelector, containerSelector) {
      $(inputSelector).almautocomplete({
        minLength: 0,

        source: function(request, response) {
          response(allUsers.filter(function(el) {
            return (existingUsers.indexOf(el.value) == -1) &&
                   (el.name.match(new RegExp(request.term, "i")));
          }));
        },

        appendTo: containerSelector,

        select: function( event, ui ) {
            $(this).val('');
            addUser( ui.item.value );
            existingUsers.push( ui.item.value );
            AlmCommon.setHasUnsavedChanges(true);
            event.preventDefault();
        },

        focus: function( event, ui ) {
          event.preventDefault();
        }
      });

      $("#alm-container").on("focus", inputSelector, function () {
        $(this).almautocomplete("search");
      });

      $("#alm-container").on("focus", ".user-search-roles", function () {
        $(this).almautocomplete("search");
      });
    }

    function initAutoCompleteRoles() {
      $("#alm-container").on("click", ".clear-invalid-role-icon", function() {
        $(this).closest(".role-section").find(".user-search-roles").val("");

        // hide the x icon
        $(this).hide();

        $(this).closest(".role-section").find(".user-search-roles").focus();
      });

      $( ".user-search-roles" ).each(function() {
        var $el = $(this);
        $el.almautocomplete({
          minLength: 0,
          source: roles,

          appendTo : $el.closest('.user-tile'),

          position: {
            of : $el.closest('.user-tile')
          },

          select: function( event, ui ) {
            var $this = $(this);
            $this.val(ui.item.label);
            var $roleSection = $this.closest('.role-section');
            $this.hide();
            $this.appendTo($roleSection);
            $roleSection.find('.role-label').text(ui.item.label);
            $roleSection.find("[id$='role-label']").val(ui.item.label);
            $roleSection.find("[id$='role-val']").val(ui.item.value);
            $roleSection.find('.assign-role').show();
            hideXIcon($this.closest(".user-tile"));
            AlmCommon.setHasUnsavedChanges(true);
            event.preventDefault();
          },

          response: function( event, ui) {
            var warningCard = templates["no_matching_role_warning"].render({
              "message" : "Select or type a valid role"
            });

            var card = $(this).closest('.user-tile');
            var numberOfMatchingRoles = ui.content.length;
            var isWarningDisplayed = card.has(".no-matching-role-container").length >= 1;

            if (numberOfMatchingRoles == 0 && !isWarningDisplayed) {
              card.append(warningCard);
              showXIcon(card);
            } else if (numberOfMatchingRoles >= 1 && isWarningDisplayed) {
              card.find(".no-matching-role-container").remove();
              hideXIcon(card);
            }
          },

          focus: function( event, ui ) {
            event.preventDefault();
          },
        });
      });

    }

    function showXIcon(userTileCard) {
      userTileCard.find(".clear-invalid-role-icon").show();
    }

    function hideXIcon(userTileCard) {
      userTileCard.find(".clear-invalid-role-icon").hide();
    }

    function getImgHTML(almUser) {
      var url;

      if(almUser['User__r'] && almUser['User__r']['SmallPhotoUrl']) {
        url = almUser['User__r']['SmallPhotoUrl'];
      } else {
        url = '/profilephoto/005/T'
      }
      return "<img src='" + url + "' class='user-photo' />";
    }

    function parseSearchResults(result) {
      var matchingUsers = [];
      for (var i = 0; i < result.length; i++) {
        var item = result[i],
          nameLabel = AlmCommon.getSObjValue(item, "Name");
          matchingUsers.push({
            label : getImgHTML(item) + nameLabel,
            name  : nameLabel,
            value : item.Id
          });
      }
      return matchingUsers;
    }

    /**
     * Provides a list of roles for the auto-complete.
     * @param inRoles {Array} - An array of objects representing roles. Each object must have the following properties:
     *   - label {String} - the display name of the role
     *   - value {String} - the Id of the record representing this role
     */
    function loadRoles(inRoles) {
      roles = inRoles;
    }

    function loadUsers(inUsers) {
      allUsers = inUsers;
    }

    var pureApi = {
      existingUsers : existingUsers,
      initAutoComplete : initAutoComplete,
      initAutoCompleteRoles : initAutoCompleteRoles,
      loadRoles : loadRoles,
      loadUsers : loadUsers,
      parseSearchResults : parseSearchResults
    };

    if (typeof define !== 'undefined') {
      return new ApiBuilder({
        pure : pureApi,
        testOnly : {}
      }).getApi();
    } else {
      return pureApi;
    }
  };

  window.BW = window.BW || {};
  if (typeof define !== 'undefined') {
    define([
      'jquery',
      'js_alm_common',
      'alm_autocomplete',
      'api_builder'
    ], function() {
      var $ = arguments[0];
      var AlmCommon = arguments[1];
      var ApiBuilder = arguments[3];

      var API = init($, AlmCommon, ApiBuilder);
      window.BW.usersearch = API;

      return API;
    });
  } else {
    window.BW.usersearch = init(jQuery, BW.AlmCommon);
  }
})();
