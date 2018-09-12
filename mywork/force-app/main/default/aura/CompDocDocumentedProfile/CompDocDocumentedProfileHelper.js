({
  displayProfilePermissions: function(component, $profileTile) {
      $.blockUI({
        message: $("#permissions-modal"),
        css: {
            cursor: 'default',
            width: '100%',
            top: '0',
            left:  '0',
            bottom:  '0',
            right:  '0',
            border: 'none',
            background: 'none',
            position: 'absolute',
            height: '100%',
            display: 'table'
        },
        onOverlayClick: function() {
          // This check prevents the handler from double-firing.
          if ($('#cancel-profile-modal').is(':hidden')) {
            BW.ProfilesCommon.promptCloseProfilePermissions();
          }
        }
      });
      BW.AlmCommon.blockUI('#permissions-modal');

      // This ensures that clicking out of the modal to close doesn't fail if the permission modal itself is sitting on top of the overlay.
      $('#permissions-modal').parent().on('click', function(event) {
        if (event.target == this) {
          BW.ProfilesCommon.promptCloseProfilePermissions();
        }
      });

      var instanceName = $profileTile.find('.instance').text(),
        profileName = $profileTile.find('.name').text();

      $profileTile.data('instances', [].concat(instanceName));

      $("#permissions-modal")
        .data('instance-name', instanceName)
        .data('selected-profile-key', $profileTile.data('key'))
        .find('.permissions-banner .profile-name').text(profileName);

      window.scrollTo(window.scrollX, 0);

      if (BW.ProfilesCommon.LOADED_PROFILE_TEMPLATES[instanceName]) {
        //allow block ui pre-loader to render and load profile in background
        window.setTimeout(function() {
          BW.ProfilesCommon.loadProfileModal($profileTile, BW.ProfilesCommon.LOADED_PROFILE_TEMPLATES[instanceName]);
        }, 300);
      } else {
          var getProfilesTemplateAction = component.get("c.getProfileTemplate");
          getProfilesTemplateAction.setParams({
            instanceName : instanceName
          });

          getProfilesTemplateAction.setCallback(this, function(data) {
            var options = {};
            options.successCb = function() {
              var profileTemplate = data.getReturnValue();
              BW.ProfilesCommon.LOADED_PROFILE_TEMPLATES[instanceName] = profileTemplate;
              BW.ProfilesCommon.loadProfileModal($profileTile, profileTemplate);
            };
            options.errorCb = function( err ) {
              BW.AlmCommon.showError(event.message);
              BW.AlmCommon.unblockUI();
              console.log(err);
            };
            BW.LTCommon.auraCallbackHandler(data, options);
          });
          $A.enqueueAction(getProfilesTemplateAction);
      }
    },
    deleteProfile: function(component) {
      if (!component.isValid()) {
        console.log('invalid component');
        return;
      }

      var profile = component.get("v.profile"),
      profileComponentIds = [profile.backlogComponentId],
      profileKeys = [profile.key];

      var appEvent = $A.get("e.c:asyncSaveEvent");
      appEvent.setParams({ "isSaveComplete" : false });
      appEvent.fire();

      var deleteAction = component.get("c.deleteSelectedComponents");
      deleteAction.setParams({
        backlogComponentIds : profileComponentIds
      });

      deleteAction.setCallback(this, function(data) {
        var options = {};
        options.successCb = function() {
          //TODO: Confirm this is not needed anymore.
          //BW.ComponentSearch.removeComponents(profileKeys);
          var appEvent = $A.get("e.c:asyncSaveEvent");
          appEvent.setParams({ "isSaveComplete" : true });
          appEvent.fire();
        };
        BW.LTCommon.auraCallbackHandler(data, options);
      });
      $A.enqueueAction(deleteAction);
    },
    handleDeleteClick: function(component, event, profileName) {
      var modalText = "Are you sure you want to remove";
      modalText += " the <br/><b>" + profileName + "</b> profile?";
      $('#delete-modal #modal-text').html(modalText);

      BW.AlmCommon.displayModal({
        content: $("#delete-modal"),
        width: '30%'
      });

      var self = this;
      $("#delete-modal .subtle-btn").off("click").on( "click", $A.getCallback(function() {
        BW.AlmCommon.unblockUI();
        self.deleteProfile(component);
      }));
    }

})