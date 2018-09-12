var BW = BW || {};
BW.AdminConsole = BW.AdminConsole || {};
BW.AdminConsole.Roles = (function ($, AlmCommon) {
  "use strict";
  var rolesToDelete = [];
    //on document ready
    $(function(){
      $( ".save-btn" ).on( "click", saveRolesHandler);
      $( "#role-mgmt-config" ).on( "click", ".new-btn", toggleEditMode);
      $( "#alm-container" ).on( "blur", "#new-input", toggleEditMode);
      $( "#role-mgmt-config" ).on( "mousedown", ".add-btn", addRole);
      $( "#role-mgmt-config" ).on( "keypress", "#new-input", function(evt) {
        AlmCommon.performActionOnEnter( $(this), evt, addRole);
      });

      $( "#role-mgmt-config" ).on( "keypress", ".role-tile input", function(evt) {
          var $this = $(this);
          AlmCommon.performActionOnEnter( $this, evt, function() {
            finishRoleEdit($this);
          });
       });
      $( "#role-mgmt-config" ).on( "blur", ".role-tile input", function() {
        finishRoleEdit($(this));
      });

      $( "#alm-container" ).on( "click", ".warning-buttons .cancel-btn, .sprint-item-warning", function(){
        closeWarning($(this).closest('.alm-warning'));
      });
      $( "#alm-container" ).on( "click", ".warning-buttons .continue-btn", function(){
        var $tile = $(this).closest('.role-tile');
        closeWarning($tile.find('.alm-warning'));
        $tile.find('input').show().focus();
      });

      $( "#role-mgmt-config" ).on( "click", ".role-tile", function(evt) {
        //dont toggle edit mode if there is a warning card or we are already in edit mode
        if ($(this).find('.alm-warning').length > 0 || $(this).find('input').is(':visible')) {
          return;
        }
        var hasUsers = $(this).data('has-users');
        if (hasUsers) {
          var warningCard = templates["sprint_warning"].render({
            "message" : "You are editing a role that has been assigned to multiple users. Your changes will take effect anywhere this role is used."
          });
          $(this).append(warningCard).find('.alm-warning').toggle('slide', { direction : "up" });
          return;
        }
        $(this).find('input').show().focus();
      });

      $( "#role-mgmt-config" ).on( "click", ".delete-icon", deleteRole);

      getAllRoles(function(result, event) {
        if (event.status) {
          renderRoles(result);
        } else if (event.message){
          AlmCommon.showError( event.message);
        }
      });

      doWindowResize();
      $(window).on("resize", doWindowResize);
    });

  function addRole() {
    var newRole = $('#new-input').val();
    AlmCommon.setHasUnsavedChanges(true);
    $('#new-input').val('');

    if (newRole != "") {
      $('#role-panel').prepend(templates["role_card"].render({Name : newRole}));
    }
  }

  function closeWarning($panel) {
    var $warningPanel = $panel || $(this);
    $warningPanel.toggle('slide', {
      direction : "up",
      complete: function() {
        $warningPanel.remove();
      }
    });
  }

  function deleteRole(evt) {
    var $tile = $(this).closest('.role-tile'),
     id = $tile.data('roleid'),
     hasUsers = $tile.data('has-users');
    evt.stopPropagation();
    if (hasUsers) {
      var warningCard = templates["sprint_item_warning"].render({
        "message" : "You are not able to delete this role because it is assigned and in use on one or more records"
      });
      $tile.append(warningCard).find('.sprint-item-warning').toggle('slide', { direction : "up" });
      return;
    }
    AlmCommon.setHasUnsavedChanges(true);
    if ( id.length > 0) {
      rolesToDelete.push(id);
    }
    $tile.remove();
  }

  function doWindowResize() {
    AlmCommon.windowResize('#role-panel', '', 198, 0);
  }

  function finishRoleEdit($input) {
    AlmCommon.setHasUnsavedChanges(true);
    $input.closest('.role-tile').find('.role-label').text($input.val());
    $input.hide();
  }

  function renderRoles(roles) {
    var roleCards = [];
    for(var i = 0; i < roles.length; i++) {
      roles[i].Name = AlmCommon.htmlDecode(roles[i].Name);
      var sprintUsers = AlmCommon.getSObjValue(roles[i], "Spint_Users__r"),
       backlogUsers = AlmCommon.getSObjValue(roles[i], "Backlog_Item_Users__r");
      if ((sprintUsers !== "" && sprintUsers.length > 0)
        || (backlogUsers !== "" && backlogUsers.length > 0)) {
        roles[i]["hasUsers"] = true;
      }
      roleCards.push( templates["role_card"].render(roles[i]) );
    }
    $('#role-panel').append(roleCards);
  }

  function saveRolesHandler() {
    var rolesToUpsert = [];
    $("#role-mgmt-config .role-tile").each(function() {
      rolesToUpsert.push(new UserRole( $(this) ));
    });
    AlmCommon.blockUI('#main-content');
    saveRoles(rolesToUpsert, rolesToDelete, function(result, event) {
      if (event.status) {
        $('#role-panel').empty();
        renderRoles(result);
      }
      else if (event.message){
        AlmCommon.showError( event.message);
      }
      AlmCommon.setHasUnsavedChanges(false);
      AlmCommon.unblockUI('#main-content');
    });
    rolesToDelete = [];
  }

  function toggleEditMode() {
    $('#new-btn-container').toggle('slide', { direction : "left" });
    $('#new-input-container').toggle('slide', {
      direction : "left",
      queue : false,
      complete: function() {
        $('#new-input').focus();
      }
    });
  }

  /**
   * ALM User Role used for sending data to remote actions
   * @constructor
   */
  function UserRole($role) {
      this.Name = $role.find('.role-label').text().trim();
      this.Id = $role.data('roleid');
      if (this.Id === "") {
        this.Id = undefined;
      }
  }

  var api = {};
  return api;
}(jQuery, BW.AlmCommon));
