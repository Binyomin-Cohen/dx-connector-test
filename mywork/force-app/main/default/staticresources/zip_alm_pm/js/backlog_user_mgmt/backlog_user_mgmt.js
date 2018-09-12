(function() {
  var init = function($, AlmCommon, UserSearch, RequestManager, ApiBuilder, Analytics) {
    "use strict";

    $(function() {
        $( "#alm-container" ).on( "click", ".edit-mode .assign-role", function(){
            var $this = $(this);
            $this.hide();
            $this.parent().find('.user-search-roles').show();
        });

        $( "#alm-container" ).on( "click", ".save-btn", function() {
            AlmCommon.blockUI();
            save();
        });

        $( "#alm-container" ).on( "click", ".edit-btn", function() {
            toggleEditMode('edit', 'btn', 'input');
        });
        $( "#alm-container" ).on( "click", ".user-tile .delete-icon", function() {
            var userId = $(this).closest('.user-tile').data('userid');
            deleteUser(userId);

            var userIndex = UserSearch.existingUsers.indexOf( userId );
            if ( userIndex != -1) {
              AlmCommon.setHasUnsavedChanges(true);
              UserSearch.existingUsers.splice(userIndex, 1);
            }
        });

        $( "#alm-container" ).on( "click", "#cancel-assigned-users", function() {
            document.location.reload();
        });

        AlmCommon.addBeforeUnloadEventListener();

        RequestManager.invokeFunction(getUsers, [function (result, event) {
          if (event.status) {
            UserSearch.loadUsers(UserSearch.parseSearchResults(result));
          } else if (event.message) {
            AlmCommon.showError(event.message);
          } else {
            AlmCommon.showError('Failed to get users.');
          }

          RequestManager.completeFunction();
        }]);

        RequestManager.invokeFunction(getRoles, [function (result, event) {
          if (event.status) {
            UserSearch.loadRoles(result.map(function (item) {
              return {
                label: AlmCommon.getSObjValue(item, "Name"),
                value: item.Id
              };
            }));
          } else if (event.message) {
            AlmCommon.showError(event.message);
          } else {
            AlmCommon.showError('Failed to get roles.');
          }
          
          RequestManager.completeFunction();
        }]);

        RequestManager.invokeFunction(loadBacklogUsers);
    });

    function toggleEditMode(type, from, to) {
        AlmCommon.toggleEditMode(type, from, to, '#');
        $('#action-panel').toggle();
        $('#detail-body').toggleClass('edit-mode');
    }

    function hasErrors() {
        return $('#detail-body').find('.message').length > 0;
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

    function finishSave() {
      AlmCommon.unblockUI();
      if ( !hasErrors() ) {
        AlmCommon.setHasUnsavedChanges(false);
        toggleEditMode('edit', 'input', 'btn');
        logAnalytics();
        setInitialUserCountHiddenInput();
      }
      UserSearch.initAutoCompleteRoles();
      $('#detail-body .user-tile').show();
    }

    function logAnalytics() {
      var initialUserCount = $('#initial-user-count').val(),
          currentUserCount = UserSearch.existingUsers.length;
      if (currentUserCount > initialUserCount) {
        Analytics.trackEvent('Assigned Users', 'Save Assignment', 'Assigned Users - Add Users');
      } else {
        Analytics.trackEvent('Assigned Users', 'Save Assignment', 'Assigned Users - Remove Users');
      }
    }
    
    function setInitialUserCountHiddenInput() {
      $('#initial-user-count').val(UserSearch.existingUsers.length);
    }
    
    function finishLoad() {
      UserSearch.existingUsers.length = 0;
      $('#detail-body .user-tile').each(function( index, value) {
        UserSearch.existingUsers.push( $(value).data('userid') );
      });

      UserSearch.initAutoCompleteRoles();
      UserSearch.initAutoComplete("#search-input", '#edit-input-container');

      $('#detail-body .user-tile').show();

      setInitialUserCountHiddenInput();
      
      RequestManager.completeFunction();
    }

    function finishModifyUsers() {
      UserSearch.initAutoCompleteRoles();
      $('#detail-body .user-tile').show();
    }

    return new ApiBuilder({
      pure : {
        finishModifyUsers : finishModifyUsers,
        finishSave : finishSave,
        finishLoad : finishLoad
      },
      testOnly: {

      }
    }).getApi();
  };

  define([
    'jquery',
    'jquery-ui',
    'js_alm_common',
    'alm_autocomplete',
    'user_search',
    'common/request-manager',
    'api_builder',
    'try!analytics'
  ], function() {
    var $ = arguments[0];
    var AlmCommon = arguments[2];
    var UserSearch = arguments[4];
    var RequestManager = arguments[5];
    var ApiBuilder = arguments[6];
    var Analytics = arguments[7];

    var API = init($, AlmCommon, UserSearch, RequestManager, ApiBuilder, Analytics);
    window.BW = window.BW || {};
    window.BW.userMgmt = API;

    return API;
  });
})();
