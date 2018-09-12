var BW = BW || {};
BW.sprint = (function ($, AlmCommon) {
    "use strict";

    var COMPLETED_STATUS = "Completed",
      NOT_STARTED_STATUS = "Not Started",
      USER_PANE_WIDTH = 279;

    $(function () {
        var sprintStartDate = getInput('sprint-start-date').val();
        var sprintEndDate = getInput('sprint-end-date').val();

        initStatusSlider();
        initReleaseLookup();

        $.datepicker.setDefaults({
            prevText: "",
            nextText: "",
            dateFormat: "yy-mm-dd"
        });

        $(".chatter-div").click(function() {
          $("#chatter-feed-container").toggle("slide", { direction : "up", duration : 200, complete : setFeedLabel });
        });

        enableSprintItemMove();
        enableUserMove();
        initUserLookup();
        doWindowResize();

        if (getInput("sprint-status").val() === COMPLETED_STATUS) {
            disablePage();
        } else {
            addEventHandlers();
        }
    });

    function setFeedLabel() {
      var txt = $("#chatter-feed-container").is(':visible') ? 'Hide Feed' : 'Show Feed';
      $(".chatter-div > span").text(txt);
    }

    function disablePage() {
        $("#alm-container")
            .addClass("read-only")
            .off();
        disableSprintItemMove();

        AlmCommon.clearMsgs();
    }

    function cancelConfirm(event) {
        var $warningPanel = $(this).closest('.sprint-item-card-wrap').find('.sprint-item-card-confirm');
        $warningPanel.toggle('slide', {
             direction : "left",
             complete: function() {
                $warningPanel.remove();
             }
         });
        $warningPanel.closest('.sprint-item-card-wrap').removeClass('warning-displayed');
        event.stopPropagation();
    }

    function deleteSprintItemConfirm(event) {
        var warningCard = templates["sprint_item_confirm"].render({
            "message" : "Are you sure you want to move this item to the backlog?"
        });
        $(this).closest('.sprint-item-card-wrap')
          .addClass('warning-displayed')
          .append(warningCard)
          .find('.sprint-item-card-confirm')
          .toggle('slide', { direction : "left" });
        event.stopPropagation();
    }

    function displayWarning(event) {
      if ($(event.target).hasClass('card-close') ||
          $(event.target).closest('.sprint-item-card-wrap').hasClass('warning-displayed') ||
          event.target.tagName === 'A') {
        return;
      }
      var warningCard = templates["sprint_item_warning"].render({
        "message" : "You must drag a user card to this item before changing its status"
      });
      $(this).closest('.sprint-item-card-wrap')
        .addClass('warning-displayed')
        .append(warningCard)
        .find('.sprint-item-warning').toggle('slide', { direction : "left" });

      if (!$('#user-pane-handle').hasClass('close')) {
        $('#user-pane-handle').removeClass('glow');
        var intervalId = window.setInterval(function(){
          $('#user-pane-handle').toggleClass('glow');
        }, 750);

        window.setTimeout(function(){
          window.clearInterval(intervalId);
        },2999);
      }
    }

    function closeWarning(event) {
      var $warningPanel = $(this);
        $warningPanel.toggle('slide', {
          direction : "left",
          complete: function() {
          $warningPanel.remove();
        }
      });
      $warningPanel.closest('.sprint-item-card-wrap').removeClass('warning-displayed');
      event.stopPropagation();
    }

    function handleDeleteSprintItem() {
        var $sprintItemCard = $(this).closest('.sprint-item-card-wrap');
        deleteSprintItem( $sprintItemCard.data('sprint-item-id'), function(result, event) {
            if (!event.status && event.message){
                AlmCommon.showError( event.message);
            }
        });

        updateLaneEffort($sprintItemCard.closest('.sprint-lane'), $sprintItemCard.data('effort'), true);
        updateSprintBusinessValueAndDevEffort($sprintItemCard.data('value'), $sprintItemCard.data('effort'))

        $sprintItemCard.toggle('slide', {
            direction : "left",
            complete: function() {
                $sprintItemCard.remove();
            }
        });
        AlmCommon.clearMsgs();
    }

    function getInput(inputId) {
        return $("input[id$='" + inputId + "']");
    }

    function disableSprintItemMove() {
        $(".sprint-item-card-wrap").draggable("destroy");
    }


    function enableUserMove() {

      var activeScrollAreas = [];

      $(".user-list-container .user-tile").draggable({
        cancel: "a",
        revert: "invalid",
        refreshPositions: true,
        containment: "#sprint-body",
        helper : function () {
          return $(this).find(".icon-section img").clone();
        },
        drag: function(event, ui) {
          AlmCommon.handleDroppableScroll(event, ui, activeScrollAreas);
        },
        cursor: "move",
        opacity: .7,
        zIndex: 100,
        start: function() {
          activeScrollAreas = AlmCommon.buildDroppableScrollAreas('#sprint-layout, .sprint-lane .page-block-content');
        },
        stop: function(event, ui) {
          $(".user-list-container").find(".user-drag-src-placeholder").remove();
          $(this).show();
        }
      });

      $(".sprint-lane .sprint-item-card-wrap").droppable({
        accept: ".user-tile",
        hoverClass: "drag-hover",
        drop: function(event, ui) {
          AlmCommon.clearMsgs();
          var $sprintCard = $(this);
          var userId = ui.draggable.data("userid");
          var sprintItemId = $sprintCard.data("sprint-item-id");
          var role = ui.draggable.find("[id$='role-val']").val();

          assignUser(sprintItemId, userId, role, function (result, event) {
            if (!event.status && event.message) {
              AlmCommon.showError(event.message);
            } else {
              var bklgUserId = result;
              var $users = $sprintCard.find(".mini-user-card");
              var $userContainer = $sprintCard.find(".sprint-item-user");
              if ($users.size() > 2) {
                $users.last().remove();
              }

              if ($sprintCard.find('.mini-user-card').length === 0) {
                $sprintCard.find(".sprint-item-user > div").remove();
              }
              $userContainer.prepend(templates["mini_user_card"].render({
                name: ui.draggable.find(".user-section a").text(),
                iconUrl: ui.draggable.find(".icon-section img").attr("src"),
                userId: userId,
                bklgUserId: bklgUserId
              }))
              setUserCardClass($userContainer);
            }
          });
        }
      });
      AlmCommon.clearMsgs();
    }

    function disableUserMove() {
      $(".user-list-container .user-tile").draggable("destroy");
      AlmCommon.clearMsgs();
    }

    function setUserCardClass($userContainer) {
      var count = $userContainer.find('.mini-user-card').length,
          $card = $userContainer.closest(".sprint-item-card-wrap");
      $userContainer.removeClass("x0-users x1-users x2-users x3-users");
      $card.removeClass("no-users");
      if (count == 0) {
        $card.addClass("no-users");
        $userContainer.append("<div>Assign a user</div>");
      }
      $userContainer.addClass("x" + count + "-users");
    }

    function enableSprintItemMove() {
      $( ".sprint-item-card-wrap").draggable({
          cancel: "a, .card-close",
          revert: "invalid",
          containment: "#sprint-layout",
          helper : 'clone',
          cursor: "move",
          opacity: .7,
          zIndex: 200,
          start: function(event, ui) {
              $(this).hide();
              $(this).after('<div class="drag-src-placeholder"/>');
          },
          stop: function(event, ui) {
              $("#sprint-layout").find(".drag-src-placeholder").remove();
              $(this).show();
          }
        });

      $('.sprint-lane .droppable-hover-placeholder').droppable({
          //Only accept it is a card that is not in the current lane
          accept: function(draggable) {
            var $draggable = $(draggable);
            return $draggable.hasClass( 'sprint-item-card-wrap')
             && $draggable.closest('.droppable-hover-placeholder')[0] != this;
          },

          hoverClass: "drag-hover",
          drop: function( event, ui ) {
              var $targetLane = $(this).closest('.sprint-lane'),
               $sourceLane = ui.draggable.closest('.sprint-lane'),
               id = ui.draggable.data('sprint-item-id'),
               effort = ui.draggable.data('effort'),
               statusLabel = $targetLane.data('status-label'),
               status = $targetLane.data('status-api');
             if (status != NOT_STARTED_STATUS) {
               ui.draggable.find('.item-status').text(statusLabel);
             }
             updateSprintItemStatus(id, status, function() {
                 if (!event.status && event.message){
                     AlmCommon.showError( event.message);
                 }
             });

             updateLaneEfforts($sourceLane, $targetLane, effort);
             addCardToLane($targetLane, ui.draggable);
          }
      });
      AlmCommon.clearMsgs();
    }

    function updateLaneEffort($lane, effort, subtract) {
        if (subtract) {
            effort *= -1;
        }
        var oldEffort = $lane.find('.effort-total');
        oldEffort.text(Number(oldEffort.text()) + effort);

        updateLaneItemCount($lane, subtract);
    }

    function updateLaneEfforts($source, $target, effort) {
        updateLaneEffort($source, effort, true);
        updateLaneEffort($target, effort);
    }

    function updateLaneItemCount($lane, subtract) {
      var itemCount = $lane.find('.item-total');
      var newCount;

      if (subtract) {
        newCount = Number(itemCount.text()) - 1;
      } else {
        newCount = Number(itemCount.text()) + 1;
      }

      itemCount.text(newCount);
    }

    /**
     *  Updates the Business Value and Dev Effort values when a backlog item is removed from the sprint
     *
     *  @param {Number} value - The business value of the backlog item that is being removed
     *  @param {Number} effort- The dev effort value of the backlog item that is being removed
     *
     */
    function updateSprintBusinessValueAndDevEffort(value, effort) {
      var oldValue = $("[id$='business-value']").text();
      var oldEffort = $("[id$='dev-effort']").text();

      $("[id$='business-value']").text(oldValue - value);
      $("[id$='dev-effort']").text(oldEffort - effort);
    }

    function addCardToLane($lane, card) {
        var priority = card.data('priority'),
         cardAdded = false;
        $lane.find('.sprint-item-card-wrap').each(function () {
            if (priority < $(this).data('priority')) {
                $(this).before(card);
                cardAdded = true;
                return false; // break
            }
        });

        if (!cardAdded) {
            $lane.find('.page-block-content').append(card);
        }
        if (card.length > 0) {
            window.setTimeout(function(){
                card[0].scrollIntoView();
                card.addClass('drop-alert')
                 .removeClass('drop-alert', 3000);
            }, 100);
        }
    }

    function doWindowResize() {
      var options = { minWindowHeight : 768 },
          userPaneOffset = $('#user-pane').hasClass('edit-mode') ? 356 : 299,
          HORIZONTAL_OFFSET =  $('#user-pane-handle').hasClass('close') ? USER_PANE_WIDTH + 115 : 115;

      $('#sprint-layout').width($(window).width() - HORIZONTAL_OFFSET);
      AlmCommon.resizeElements([
        {
          element: '.sprint-lane .page-block-content',
          offset: 261
        },
        {
          element: '#user-pane .user-list-container',
          offset: userPaneOffset
        },
        {
          element: '.default-drag-helper ',
          offset: 208
        }
      ], options);
      $('#sprint-body').height($('#sprint-layout').height());
    }

    function initUserLookup() {
        $('#alm-container').on('click', '.user-btn', function () {
            $('#user-pane').addClass('edit-mode');
            $('.user-save-container').show();
            AlmCommon.toggleEditMode('user', 'btn', 'input');
            initAutoCompleteRoles();
            disableUserMove();
            doWindowResize();
        });

        BW.usersearch.initAutoComplete('.user-input', '#user-pane');

        getUsers(function (result, event) {
          if (event.status) {
            BW.usersearch.loadUsers(BW.usersearch.parseSearchResults(result));
          } else if (event.message) {
            AlmCommon.showError(event.message);
          } else {
            AlmCommon.showError('Failed to get users.');
          }
        });

        getRoles(function (result, event) {
          if (event.status) {
            BW.usersearch.loadRoles(result.map(function (item) {
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
        });

        $('#user-pane .user-tile').each(function() {
            BW.usersearch.existingUsers.push( $(this).data('userid') );
        });
        AlmCommon.clearMsgs();
    }

    function initAutoCompleteRoles() {
      BW.usersearch.initAutoCompleteRoles();
      $(".user-search-roles").each(function() {
        $(this).almautocomplete("option", "position", {
          my: "left top",
          at: "left bottom",
          collision: "flip",
          within: ".user-list-container"
        });
      });
    }

    function finishSave() {
      AlmCommon.unblockUI();
      if (hasErrors()) {
        initAutoCompleteRoles();
      } else {
        $('#user-pane').removeClass('edit-mode');
        AlmCommon.toggleEditMode('user', 'input', 'btn');
        enableUserMove();
        AlmCommon.setHasUnsavedChanges(false);
      }
    }

    function hasErrors() {
      return $('.msg-panel div').size() > 0;
    }

    function initStatusSlider() {
      var statusLabels = getInput('sprint-statuses').val().split(",");
      var currentStatus = getInput('sprint-status').val();
      $( "#slider" ).slider({
        value: statusLabels.indexOf(currentStatus),
        min: 0,
        max: statusLabels.length-1,
        step: 1,
        range: 'min',
        change: function( event, ui ) {
          var selectedLabel = statusLabels[ui.value];
          getInput('sprint-status').val(selectedLabel);
          setStatusLabel(selectedLabel);
          updateSprint();
          if (getInput("sprint-status").val() === COMPLETED_STATUS) {
            disablePage();
          } else if ($("#alm-container").hasClass("read-only")) {
            enableSprintItemMove();
            enableUserMove();
            addEventHandlers();
            initUserLookup();
            $(".read-only").removeClass("read-only");
          }
        },
        create: function(event, ui) {
          var label = getInput('sprint-status').val();
          setStatusLabel(label);
        },
        slide: function(event, ui) {
          var selectedLabel = statusLabels[ui.value];
          window.setTimeout(function() {
            setStatusLabel(selectedLabel);
          }, 100);
        }
      });
    }

    function setStatusLabel(value) {
      var label = getInput('sprint-statuses').data('status-map')[value];
      if (label === undefined) {
        label = NOT_STARTED_STATUS;
      }
      var $slider = $('.slider-container');
      $slider.find('.ui-slider-legend').remove();
      $slider.append('<div class="ui-slider-legend" data-api-name="' + value + '">' + label + '</div>');

      $('.ui-slider-legend').position({
        of: '.ui-slider-handle',
        within: $slider,
        at: "center bottom",
        my: "center bottom-15px",
        collision: "flipfit"
      });

    }

    function initReleaseLookup() {
        var releaseId = getInput('release-id').val();
        var releasesSearchResultsCache = {};
        $( ".release-input" ).almautocomplete({
          minLength: 2,

          source: function(request, response) {

            var term = request.term;
            if ( term in releasesSearchResultsCache ) {
              response( releasesSearchResultsCache[ term ] );
              return;
            }
            var matchingReleases = [];
            if ( request.term.length > 1 ) {

              searchReleases(term, function(result, event) {
                if (event.status) {

                  for (var i = 0; i < result.length; i++) {
                    var item = result[i],
                    nameLabel = item["Name"];
                    matchingReleases.push( {
                      label : nameLabel,
                      value : item.Id
                    });
                  }
                  releasesSearchResultsCache[ term ] = matchingReleases;
                  response( matchingReleases );
                }
              });
            }
            else {
              response( matchingReleases );
            }
          },

          appendTo: '#release-container',

          select: function( event, ui ) {
            $("#alm-container").off("blur", ".release-input");
            $(this).val(ui.item.label);
            getInput('release-id').val(ui.item.value);
            updateSprint();
            AlmCommon.toggleEditMode('release', 'input', 'card');
            $('.release-card-container .release-name').text(ui.item.label);
            event.preventDefault();
          },

          focus: function( event, ui ) {
            $(this).val(ui.item.name);
            event.preventDefault();
          }
        });

        if (releaseId && releaseId !== '') {
          $(".release-card-container").show();
          var releaseName = getInput('release-name').val();
          $('.release-input').val(releaseName);
          $('.release-card-container .release-name').text(releaseName);
        } else {
          $(".release-btn-container").show();
        }
    }

    function toggleUserPane() {
      var $layout = $("#sprint-layout"),
        $handle = $('#user-pane-handle');
      if ($handle.hasClass("close")) {
        $("#user-pane").hide("slide", {
          direction: "left",
          queue: false
        });
        $handle.animate({left: "-11px"}, {
          complete: function() {
            $handle.removeClass("close");
            $layout.animate({left : "16px"}, {
              complete: function() {
                $layout.width($layout.width() + USER_PANE_WIDTH);
              },
            });
          },
          queue: false
        });
      } else {
        $layout.animate({left: "294px"}, {
          complete: function() {
            $layout.width($layout.width() - USER_PANE_WIDTH)
            $("#user-pane").show("slide", {
              direction: "left",
              queue: false
            });
            $handle.animate({left: "267px"}, {
              complete: function() {
                $handle.addClass("close").removeClass('glow');
              },
              queue: false
            });
          },
          queue: false
        });
      }
    }

    function addReleaseBlurEvent() {
      $("#alm-container").on("blur", ".release-input", function() {
        if (getInput('release-id').val() == '') {
          AlmCommon.toggleEditMode('release', 'input', 'btn');
        } else {
          AlmCommon.toggleEditMode('release', 'input', 'card');
        }
        $("#alm-container").off("blur", ".release-input");
      });
    }

    function addEventHandlers() {
        $("#alm-container").on("click", ".release-btn", function () {
          AlmCommon.toggleEditMode('release', 'btn', 'input');
          addReleaseBlurEvent();
        });

        $("#alm-container").on("click", ".release-card-edit", function () {
          AlmCommon.toggleEditMode('release', 'card', 'input');
          addReleaseBlurEvent();
        });

        $("#alm-container").on("click", ".release-card-close", function () {
            getInput('release-id').val('');
            $('.release-input').val('');
            $('.release-card-container .release-name').text('');
            updateSprint();
            AlmCommon.toggleEditMode('release', 'card', 'btn');
        });

        $( "#alm-container" ).on( "click", ".card-close", deleteSprintItemConfirm);
        $( "#alm-container" ).on( "click", ".continue-btn", handleDeleteSprintItem);
        $( "#alm-container" ).on( "click", ".warning-buttons .cancel-btn", cancelConfirm);

        //DISABLING USER MOVE VALIDATION FOR NOW
        //$( "#alm-container" ).on( "mousedown", ".no-users", displayWarning);
        $( "#alm-container" ).on( "click", ".sprint-item-warning", closeWarning);

        $( "#alm-container" ).on( "click", ".edit-mode .role-section", function() {
            var $link = $(this).find(".assign-role");
            $link.hide();
            $(this).find('.user-search-roles').show().focus();
            AlmCommon.clearMsgs();
        });

        // Deleting a sprint user
        $( "#alm-container" ).on( "click", ".user-tile .delete-icon", function() {
            var userId = $(this).closest('.user-tile').data('userid');
            deleteUser(userId);

            var userIndex = BW.usersearch.existingUsers.indexOf( userId );
            if ( userIndex != -1) {
              AlmCommon.setHasUnsavedChanges(true);
              BW.usersearch.existingUsers.splice(userIndex, 1);
            }
            AlmCommon.clearMsgs();
        });

        $( "#alm-container" ).on( "click", ".save-btn", function () {
            AlmCommon.clearMsgs();
            AlmCommon.blockUI();
            AlmCommon.setHasUnsavedChanges(false);
            save();
        });

        $( "#alm-container" ).on("click", ".start-date, #start-date-caret", function() {
            var $startpicker = $(".start-date-picker-div");
            $startpicker.datepicker({
                onSelect: function(dateStr) {
                    getInput('sprint-start-date').val(dateStr);
                    $startpicker.datepicker().hide();
                    updateSprint();
                    $startpicker.datepicker( "destroy" );
                }
            });
            $startpicker.datepicker().show();
            AlmCommon.clearMsgs();
        });

        $( "#alm-container" ).on("click", ".end-date, #end-date-caret", function() {
            var $endpicker = $(".end-date-picker-div");
            $endpicker.datepicker({
                onSelect: function(dateStr) {
                    getInput('sprint-end-date').val(dateStr);
                    $endpicker.datepicker().hide();
                    updateSprint();
                    $endpicker.datepicker( "destroy" );
                }
            });
            $endpicker.datepicker().show();
            AlmCommon.clearMsgs();
        });

        /* Deleting a user from a sprint item card. */
        $( "#alm-container" ).on("click", ".mini-user-card .delete-icon", function() {
          var $miniCard = $(this).closest('.mini-user-card');
          var bklgUserId = $miniCard.data('bklg-userid');
          var sprintId = getInput("sprint-id").val();
          var sprintItemId = $miniCard.closest('.sprint-item-card-wrap').data('sprint-item-id');
          deleteSprintItemUser(sprintId, bklgUserId, sprintItemId, function (result, event) {
            if (!event.status) {
              showError(event.message);
            } else {
              var $userContainer = $miniCard.closest('.sprint-item-user');
              $userContainer.empty();
              for (var i = 0; i < Math.min(3, result.length); ++i) {
                $userContainer.append(templates["mini_user_card"].render({
                  name: result[i].name,
                  iconUrl: result[i].photoURL,
                  userId: result[i].almUserId,
                  bklgUserId: result[i].record.Id
                }))
              }
              setUserCardClass($userContainer);
            }
          });
          AlmCommon.clearMsgs();
        });

        $("#alm-container").on("click", "#user-pane-handle", toggleUserPane);

        AlmCommon.addBeforeUnloadEventListener();
        $(window).on("resize", doWindowResize);
    }

    var api = {
      finishSave : finishSave,
      initAutoCompleteRoles: initAutoCompleteRoles,
    };

    return api;
}(jQuery, BW.AlmCommon));

