(function () {
  "use strict";

  var init = function($, AlmCommon, ComboBox, ApiBuilder, Analytics) {

    var SPRINT_STATUSES,
        displayedBacklogItems = {},
        totalBacklogItems = -1;

    $(function() {
      $( "#alm-container" ).on( "mousedown", ".save-btn", saveSprint);
      $( "#alm-container" ).on( "click", ".edit-card-icon", showSprintEditMode);
      $( "#alm-container" ).on( "keydown", ".edit-input", function(evt) {
        AlmCommon.performActionOnEnter( $(this), evt, function($el) {
          saveSprint(evt, $el);
          $el.closest('.edit-container').hide();
        });
        AlmCommon.performActionOnEscape( $(this), evt, function($el) {
          $el.closest('.edit-container').hide();
        });
      });
      $( "#alm-container" ).on( "blur", ".edit-input", hideSprintEditMode);
      $( "#alm-container" ).on( "blur", "#new-input", function() {
        AlmCommon.toggleEditMode("new", "input", "btn", "#");
      });
      $( "#alm-container" ).on( "click", "#new-btn-container", function() {
        AlmCommon.toggleEditMode("new", "btn", "input", "#");
      });
      $( "#alm-container" ).on( "keypress", "#new-input", function(evt) {
        AlmCommon.performActionOnEnter( $(this), evt, function() {
          addSprint();
        });
      });
      $( "#alm-container" ).on( "mousedown", ".add-btn", addSprint);
      $( "#alm-container" ).on( "click", ".close-card-icon", deleteSprintConfirm);
      $( "#alm-container" ).on( "click", ".warning-buttons .cancel-btn", cancelConfirm);

      $( "#alm-container" ).on( "click", ".sp-card-metrics-undo", sendIncompleteItemsToBacklogHandler);

      $( "#backlog-list-panel" ).on( "click", ".load-more-btn", function() {
          $("#backlog-list-panel .page-block-content img").removeClass("hidden");
          loadBacklogItems();
      });

      SPRINT_STATUSES = $("#sprint-statuses").val().split(",");

      getAllSprints(  function(result, event) {
        if (event.status) {
          // Decode HTML entities within sprint names before they're displayed on sprint cards.
          for (var i = 0; i < result.activeSprints.length; ++i) {
            result.activeSprints[i].name = AlmCommon.htmlDecode(result.activeSprints[i].name);
          }
          for (var i = 0; i < result.completedSprints.length; ++i) {
            result.completedSprints[i].name = AlmCommon.htmlDecode(result.completedSprints[i].name);
          }

          var sprintPartial = {"sprint_card" : templates["sprint_card"]},
              activeSprintCards = templates["sprint_cards"].render({
                "sprints" : result.activeSprints
              }, sprintPartial),
              completedSprintCards = templates["sprint_cards"].render({
                  "sprints" : result.completedSprints.reverse()
              }, sprintPartial);

          $('#completed-sprints').prepend( completedSprintCards )
              .find( '.sp-card-wrap-hotspot' ).addClass( 'completed' )
              .each(function() {
                if ($(this).data('has-ra-items') === true) {
                  $(this).addClass( 'has-items-for-reassignment' );
                }
              });

          $('#active-sprints').prepend( activeSprintCards );

          enableIncompleteItemsReassignment();
          enableBacklogAssignment();

          setSprintMetricsColor($('#completed-sprints, #active-sprints')
              .find('.incomplete-items, .total-items, .total-effort'));

          initStatusSlider("#sprint-layout .sp-card-wrap");
          doWindowResize();
        } else if (event.message){
          AlmCommon.showError( event.message);
        }
      });

      ComboBox.init({
        inputSelector : '#backlog-selection-input',
        parentContainer : '#backlog-selection-combobox-container',
        appendTo : '#backlog-selection-combobox-container',
        isMultiSelect : false,
        selectAction : function selectCallback() {
          var backlogName = $('#backlog-selection-input').val();
          $('#backlog-selection-input').val('');
          $('#backlog-name').text(backlogName);

          $('#backlog-selection-combobox-container .alm-combobox .filter-values option').each(function (index, element) {
            if ($(element).text() === backlogName) {
              $('#backlog-id').val($(element).val());
            }
          });

          $('#backlog-name-container').show();
          $('#backlog-selection-combobox-container .alm-combobox').hide();

          updateDefaultBacklog($('#backlog-id').val(), function() {
            $('.backlog-items').empty();
            displayedBacklogItems = {};

            AlmCommon.blockUI('#backlog-list-panel');

            loadInitialBacklogItems(function() {
              setTotalBacklogItemsCount();
              AlmCommon.unblockUI('#backlog-list-panel');
            });
          });
        }
      });
      $('#alm-container').on('click', '#backlog-name-container .click-to-edit', function() {
        $('#backlog-name-container').hide();
        $('#backlog-selection-combobox-container .alm-combobox').show();
        $('#backlog-selection-input').focus();
      });
      $('#alm-container').on('blur', '#backlog-selection-input', function() {
        $('#backlog-name-container').show();
        $('#backlog-selection-combobox-container .alm-combobox').hide();
      });

      loadInitialBacklogItems(setTotalBacklogItemsCount);

      $(window).on("resize", doWindowResize);
    });

    /**
     * Calls the remote action function to load the initial set of backlog items to display on the page.
     * @param callback - Callback method to be called after the backlog items have been loaded successfully.
     */
    function loadInitialBacklogItems(callback) {
      var backlogId = $('#backlog-id').val();

      getInitialBacklogItems(backlogId, function(result, event) {
        if (event.status) {
          displayBacklog( result );
          $("#backlog-list-panel .page-block-content img").addClass("hidden");

          if (callback && typeof callback === "function") {
            callback();
          }
        } else if (event.message) {
          AlmCommon.showError( event.message);
        }
      });
    }

    /**
     * Calls the remote action function to get the total number of unassigned backlog items
     * and incomplete sprint items. Saves the returned value to totalBacklogItems
     */
    function setTotalBacklogItemsCount() {
      getBacklogItemsCount($('#backlog-id').val(), getDisplayedBacklogItems(), function(result, event) {
        if (event.status) {
          if (typeof result === 'number') {
            totalBacklogItems = result;
            updateLoadMoreButton();
          }
        } else if (event.message) {
          AlmCommon.showError( event.message );
        }
      });
    }

    /**
     * Calls the remote action function to load a set number of backlog items to display on the page filtering
     * on a list of backlog items that is already displayed on page.
     */
    function loadBacklogItems() {
      $("#backlog-list-panel").find(".page-block-content .load-more-btn").addClass('hidden');
      getAssignableBacklogItems($('#backlog-id').val(), getDisplayedBacklogItems(), function(result, event) {
        if (event.status) {
          displayBacklog( result );
          updateLoadMoreButton();
          $("#backlog-list-panel .page-block-content img").addClass("hidden");
        } else if (event.message){
          AlmCommon.showError( event.message);
        }
      });
    }

    /**
     * Updates the Load More Backlog Item button with the current displayed backlog item count and the total count
     */
    function updateLoadMoreButton() {
      var $button = $("#backlog-list-panel").find(".page-block-content .load-more-btn"),
          displayedCount = getDisplayedBacklogItems().length,
          deltaDisplay = totalBacklogItems - displayedCount,
          nextVal = ( deltaDisplay < 50 && deltaDisplay > -1) ? deltaDisplay : 50;

      if (displayedCount >= totalBacklogItems) {
        $button.addClass('hidden');
      } else {
        var totalText = (totalBacklogItems > 50000) ? "50000+" : totalBacklogItems;
        $button.text("Load the Next " + nextVal + " of " + totalText + " Items ›");
        $button.removeClass('hidden');
      }
    }

    /**
     * Adds the ids of all newly queried backlog items (BacklogItemModel) to the list of displayed backlog items
     * @param newBacklogItems - array of new backlog items to append to the currently displayed backlog items list
     */
    function addToDisplayedBacklogItems(newBacklogItems) {
      if (!newBacklogItems && !newBacklogItems.length) {
        return;
      }

      for (var k = 0; k < newBacklogItems.length; k++) {
        var backlogItem = newBacklogItems[k];
        if (backlogItem && backlogItem.id && !displayedBacklogItems[backlogItem.id]) {
          displayedBacklogItems[backlogItem.id] = true;
        }
      }
    }

    /**
     * Returns the current displayed backlog items
     * @returns {Array} String - of backlog item Ids
     */
    function getDisplayedBacklogItems() {
      return Object.keys(displayedBacklogItems);
    }

    /**
     * Returns the total count of backlog items on the page state
     * @returns {number} total backlog item count
     */
    function getTotalBacklogItems() {
      return totalBacklogItems;
    }

    function enableIncompleteItemsReassignment() {
      var activeScrollAreas = [];

      $( "#completed-sprints .has-items-for-reassignment .incomplete").draggable({
        appendTo: "#alm-container",
        cancel: "a",
        revert: "invalid",
        refreshPositions: true,
        containment: "#alm-container",
        helper : "clone",
        cursor: "move",
        opacity: .7,
        zIndex: 110,
        drag: function(event, ui) {
          AlmCommon.handleDroppableScroll(event, ui, activeScrollAreas);
        },
        start: function(event, ui) {
          $(this).hide();
          $(this).after('<div class="sp-card-metrics drag-src-placeholder"/>');
          activeScrollAreas = AlmCommon.buildDroppableScrollAreas('#sprint-panel > div');
        },
        stop: function(event, ui) {
          $("#completed-sprints").find(".drag-src-placeholder").remove();
          $(this).show();
        }
      });
    }

    function enableBacklogAssignment() {
      var activeScrollAreas = [];
        $( "#backlog-list-panel .bklg-item-card-wrap").draggable({
          cancel: "a",
          revert: "invalid",
          refreshPositions: true,
          containment: "#alm-container",
          helper : "clone",
          cursor: "move",
          opacity: .7,
          zIndex: 100,
          drag: function(event, ui) {
            AlmCommon.handleDroppableScroll(event, ui, activeScrollAreas);
          },
          start: function(event, ui) {
            $(this).hide();
            $(this).after('<div class="drag-src-placeholder"/>');
            activeScrollAreas = AlmCommon.buildDroppableScrollAreas('#sprint-panel > div');
          },
          stop: function(event, ui) {
            $("#backlog-list-panel").find(".drag-src-placeholder").remove();
            $(this).show();
          }
        });

        $('.sp-card-wrap-hotspot').not('.completed').not('.sp-card-default').droppable({
              accept: "#backlog-list-panel .bklg-item-card-wrap, #completed-sprints .has-items-for-reassignment .incomplete",
              hoverClass: "drag-hover",
              drop: function( event, ui ) {
                var $targetSprintCard = $(this),
                 backlogId = ui.draggable.data('backlog-id'),
                 sprintId = $targetSprintCard.data('sprint-id');

                var isBacklogItem = ui.draggable.hasClass("bklg-item-card-wrap");

                if (isBacklogItem) {
                    Analytics.trackEvent('Sprint', 'Item Assigned to Sprint', 'Sprint - Assign by Drag and Drop');
                    addSprintItem(sprintId, backlogId);

                    //Let draggable finish cleaning up after itself before deleting element
                    window.setTimeout(function(){
                        ui.draggable.remove();
                    }, 100);

                    animateDrop( $targetSprintCard.find('.sp-card-metrics') );

                    updateSprintTotals( $targetSprintCard, ui.draggable);
                } else {
                    sendIncompleteItemsToDifferentSprint( ui.draggable.closest('.sp-card-wrap-hotspot'), $targetSprintCard);
                }
              }
        });
    }

    function addSprintItem(sprintId, backlogId) {
      AlmCommon.toggleSave();
      createSprintItem(sprintId, backlogId, function(result, event) {
        AlmCommon.clearMsgs();
        window.setTimeout(AlmCommon.toggleSave, 500);
        if (event.status) {
          if (displayedBacklogItems[backlogId]) {
            delete displayedBacklogItems[backlogId];
          }

          totalBacklogItems--;
          updateLoadMoreButton();
        } else if ( event.message ) {
          AlmCommon.showError( event.message);
        }
      });
    }

    /**
     * @param {Selector|Element|jQuery} sprints to setup statuses for
     */
    function initStatusSlider(sprints) {
      var $sprints = $(sprints);
      $sprints.find(".slider").slider({
        value: 0,
        min: 0,
        max: SPRINT_STATUSES.length - 1,
        step: 1,
        range: 'min',
        disabled: true,
        create: function(event, ui) {
          var $slider = $(this),
           $sliderContainer = $slider.closest('.slider-container'),
           $handle = $slider.find('.ui-slider-handle');
          var $legend = $sliderContainer.find('.ui-slider-legend');
          var status = $legend.data("status-value");
          $slider.slider("option", "value", SPRINT_STATUSES.indexOf(status) );
          $legend.position({
            of: $handle,
            within: $sliderContainer,
            at: "center bottom",
            my: "center bottom-15px",
            collision: "flipfit"
          });
        }
      });
    }

    function updateSprintTotals($sprintCard, $backlogCard) {
        var $incompleteItems = $sprintCard.find('.incomplete-items'),
         $totalItems = $sprintCard.find('.total-items'),
         $totalEffort = $sprintCard.find('.total-effort'),
         $unestimatedTotal = $sprintCard.find('.unestimated-total'),
         effort = $backlogCard.data('backlog-effort');

       $incompleteItems.text( Number( $incompleteItems.text() ) + 1);
       $totalItems.text( Number( $totalItems.text() ) + 1);
       $totalEffort.text( Number( $totalEffort.text() ) + effort);
       if (effort === "") {
           if ($unestimatedTotal.length > 0) {
               $unestimatedTotal.text( Number( $unestimatedTotal.text() ) + 1);
           } else {
               $sprintCard.find('.sp-card-metrics.last').append('<div title="There is 1 un-estimated item in this sprint" class="unestimated-total">1</div>');
           }
       }

       setSprintMetricsColor($incompleteItems);
       setSprintMetricsColor($totalItems);
       setSprintMetricsColor($totalEffort);
    }

    /**
     * Sets the color of the sprint metric <span> tag based on the value.
     * If the value is 0, the text is set to light gray, otherwise the text is black
     *
     * @param metric A JQuery object containing all matching <span> element(s)
     */
    function setSprintMetricsColor(metric) {
      metric.each(function() {
        if ($(this).text() === "0") {
          $(this).addClass("light-gray-text");
        } else {
          $(this).removeClass("light-gray-text");
        }
      });
    }

    /**
     * Perform color animation on $elements
     * @returns $elements
     */
    function animateDrop($elements) {
        return $elements.addClass('drop-alert').removeClass('drop-alert', 3000);
    }

    function addSprint() {
        Analytics.trackEvent('Sprint', 'Create Sprint');
        var newSprintName = $('#new-input').val();
        if (newSprintName != "") {
            var NOT_STARTED = "Not Started";
            $('#new-input').val("");
            var sprintCard = $( templates["sprint_card"].render({
                "name" : newSprintName,
                "status" : NOT_STARTED,
                "statusLabel" : NOT_STARTED,
                "sprintId" : "#",
                "totalItems" : 0,
                "totalEffort" : 0,
                "incompleteItems" : 0,
            }) );
            $('#active-sprints').prepend( sprintCard );
            var blankCards = $('#active-sprints .sp-card-default');

            if (blankCards.length > 0) {
                blankCards.eq(0).remove();
            }

            AlmCommon.toggleSave();
            createSprint( newSprintName, function(result, event) {
                window.setTimeout(AlmCommon.toggleSave, 500);
                if (event.status) {
                    sprintCard.data('sprint-id', result);
                    sprintCard.find('.sprint-name a').attr('href', '/' + result);
                } else if (event.message){
                    AlmCommon.showError( event.message);
                }
            });

            enableBacklogAssignment();

            setSprintMetricsColor(sprintCard.find('.incomplete-items, .total-items, .total-effort'));
            initStatusSlider(sprintCard);
        }
    }

    function cancelConfirm(event) {
        removeSprintWarning( $(this).closest('.sp-card-wrap-hotspot') );
        event.preventDefault();
    }

    function deleteSprintConfirm(event) {
        var $sprintCard = $(this).closest('.sp-card-wrap-hotspot');

        displaySprintWarning($sprintCard, "Are you sure you want to delete this sprint?");

        $sprintCard.find(".continue-btn").click(handleDeleteSprint);

        event.preventDefault();
    }

    function saveSprint(evt, el) {
      var $el = el || $(this),
        $card = $el.closest('.sp-card-wrap-hotspot'),
        newName = $card.find('.edit-input').val();
      if (newName === "") {
        AlmCommon.showError("Sprint name cannot be blank.");
        return;
      }
      $card.find('.sprint-name a').text(newName).attr('title', newName);
      AlmCommon.toggleSave();
      updateSprintName($card.data('sprint-id'), newName, function(result, event) {
        AlmCommon.clearMsgs();
        window.setTimeout(AlmCommon.toggleSave, 500);
        if (!event.status && event.message) {
          AlmCommon.showError( event.message);
        }
      });
    }

    function sendIncompleteItemsToBacklogHandler() {
        var $sprintCard = $(this).closest('.sp-card-wrap-hotspot');

        var warningMsg = "Are you sure you want to send these incomplete items to the backlog?";
        displaySprintWarning($sprintCard, warningMsg);

        $sprintCard.find(".continue-btn").click(function() {
            removeSprintWarning($sprintCard);

            AlmCommon.toggleSave();
            sendIncompleteItemsToBacklog( $sprintCard.data('sprint-id'), function(result, event) {
                window.setTimeout(AlmCommon.toggleSave, 500);
                if (!event.status && event.message){
                    AlmCommon.showError( event.message);
                } else {
                    var newBacklogIds = [];
                    for(var i = 0; i < result.length; i++) {
                        newBacklogIds.push( result[i].id );
                    }
                    //insert re-added backlog items into the backlog list based on priority
                    var nextBacklogItem = result.shift();
                    $('#backlog-list-panel .bklg-item-card-wrap').each(function(index) {
                        if (nextBacklogItem === undefined) {
                            return false; //break
                        }
                        var currentPriority = Number($(this).data('backlog-priority'));
                        if (currentPriority >= nextBacklogItem.priority) {
                            do {
                                $( this ).before( templates["backlog_card"].render( nextBacklogItem ) );
                                nextBacklogItem = result.shift();
                            }
                            while( nextBacklogItem !== undefined && currentPriority >= nextBacklogItem.priority);
                        }
                    });
                    if (nextBacklogItem !== undefined) {
                        result.unshift( nextBacklogItem );
                    }
                    //render any remaining elements
                    displayBacklog( result );
                    $sprintCard.removeClass('has-items-for-reassignment');

                    $('#backlog-list-panel .bklg-item-card-wrap').filter(function() {
                        return newBacklogIds.indexOf( $(this).data('backlog-id') ) != -1;
                    }).addClass('unassigned')
                    .removeClass('unassigned', 3000)[0].scrollIntoView();

                    // Rerender the load more button with new values
                    setTotalBacklogItemsCount();
                }
            });
        });
    }

    function displayBacklog(backlogItems) {
        addToDisplayedBacklogItems( backlogItems );
        // Decode HTML entities within backlog titles before they're displayed on backlog cards.
        for (var i = 0; i < backlogItems.length; ++i) {
          backlogItems[i].title = AlmCommon.htmlDecode(backlogItems[i].title);
        }

        var cardPartial = {"backlog_card" : templates["backlog_card"]},
            backlogCards = templates["backlog_cards"].render({
                "backlog" : backlogItems
            }, cardPartial),
            $pageBlockContent = $('#backlog-list-panel').find('.page-block-content'),
            $backlogItemsContainer = $pageBlockContent.find('.backlog-items');

        $backlogItemsContainer.append( backlogCards );
        if ($backlogItemsContainer.children().length > 0) {
            $pageBlockContent.addClass('available');
        }
        enableBacklogAssignment();
    }

    function displaySprintWarning($sprintCard, warningMsg) {
        var warningCard = templates["sprint_warning"].render({
            "message" : warningMsg
        });

        $sprintCard.append(warningCard)
        .find('.sp-card-wrap-error').toggle('slide', { direction : "up" });
    }

    function removeSprintWarning($sprintCard) {
        var $errorPanel = $sprintCard.find('.sp-card-wrap-error');
        $errorPanel.toggle('slide', {
            direction : "up",
            complete: function() {
                $errorPanel.remove();
            }
        });
    }

    function sendIncompleteItemsToDifferentSprint($sourceSprintCard, $targetSprintCard) {
        var warningMsg = "Are you sure you want to reassign these incomplete items to "
            + $targetSprintCard.data('sprint-name') + "?";

        displaySprintWarning($targetSprintCard, warningMsg)

        $targetSprintCard.find(".continue-btn").click(function() {
          AlmCommon.toggleSave();
          reassignIncompleteItems( $sourceSprintCard.data('sprint-id'), $targetSprintCard.data('sprint-id'), function(result, event) {
                window.setTimeout(AlmCommon.toggleSave, 500);
                if (!event.status && event.message) {
                    AlmCommon.showError(event.message);
                } else {
                    $sourceSprintCard.removeClass('has-items-for-reassignment');
                    result.name = AlmCommon.htmlDecode(result.name);
                    var updatedSprintCard = $( templates["sprint_card"].render(result) );
                    var $updatedSprintCard = $( updatedSprintCard );
                    $targetSprintCard.replaceWith( $updatedSprintCard );
                    animateDrop( $updatedSprintCard.find('.sp-card-metrics') );
                    enableBacklogAssignment();
                }
            });
        });
    }

    function handleDeleteSprint(event) {
      var sprintCard = $(this).closest('.sp-card-wrap-hotspot');
      AlmCommon.toggleSave();
      deleteSprint( sprintCard.data('sprint-id'), function(result, event) {
        window.setTimeout(AlmCommon.toggleSave, 500);
        if (!event.status && event.message) {
          AlmCommon.showError( event.message);
        }
        setTotalBacklogItemsCount();
      });

      sprintCard.remove();
      event.preventDefault();
    }

    /**
     * Returns the number of blank cards that can fit in the sprint window without causing scrollbars
     */
    function getBlankCardCount() {
        var CARD_HEIGHT = 224,
         $sprintPanel = $('#sprint-panel > div');
        //force the scrollbar by showing more cards than fit in the area so we can show poll position
        //as the first active sprint
        var rows = Math.floor( $sprintPanel.height() * 1.5 / CARD_HEIGHT );
        var cols = getCardColumnCount();
        return cols * rows;
    }

    /**
     * Returns the number of cards that can fit in a row in the sprint window
     */
    function getCardColumnCount() {
      var CARD_WIDTH = 300,
      $sprintPanel = $('#sprint-panel > div');
      return Math.floor( $sprintPanel.width() / CARD_WIDTH );
    }

    function doWindowResize() {
      AlmCommon.windowResize('#sprint-panel > div', '#backlog-list-panel > div', 118, 110);

      renderBlankCards();
    }

    function renderBlankCards() {
      // remove all blank cards
      $('div.sp-card-wrap-hotspot.sp-card-default').remove();

      // get the number of active sprints
      var activeSprints = $("#active-sprints .sp-card-wrap").length;

      // get the number of completed sprints
      var completedSprints = $("#completed-sprints .sp-card-wrap-hotspot .completed").length;

      var blankCard = templates["placeholder_card"].render({prefix:'sp'});

      var activeBlankCards = "",
          completedBlankCards = "",
          blankCardsCount = getBlankCardCount() - activeSprints,
          cardColumnCount = getCardColumnCount(),
          completedBlankCardsCount = cardColumnCount - (completedSprints % cardColumnCount);

      for(var i = 0; i < blankCardsCount; i++) {
        activeBlankCards += blankCard;
      }

      for(var i = 0; i < completedBlankCardsCount; i++) {
        completedBlankCards += blankCard;
      }

      $('#completed-sprints').prepend( completedBlankCards );
      $('#active-sprints').append(  activeBlankCards );
      $("#active-sprints .sp-card-wrap")[0].scrollIntoView();
    }

    function hideSprintEditMode() {
      $(this).closest('.sp-card-wrap')
      .find('.edit-container')
      .hide();
    }

    function showSprintEditMode() {
      $(this).closest('.sp-card-wrap')
       .find('.edit-container')
       .show()
       .find('input').focus();
    }

    return new ApiBuilder({
      pure: {
      },
      testOnly: {
        addSprintItem : addSprintItem,
        addToDisplayedBacklogItems : addToDisplayedBacklogItems,
        getDisplayedBacklogItems : getDisplayedBacklogItems,
        getTotalBacklogItems : getTotalBacklogItems,
        loadBacklogItems : loadBacklogItems,
        resetBacklogItemPanelDetails : function() { totalBacklogItems = -1; displayedBacklogItems = {}; },
        sendIncompleteItemsToDifferentSprint : sendIncompleteItemsToDifferentSprint,
        setTotalBacklogItemsCount : setTotalBacklogItemsCount,
        updateLoadMoreButton : updateLoadMoreButton
      }
    }).getApi();
  };

  define([
    'jquery',
    'jquery-ui',
    'alm_autocomplete',
    'js_alm_common',
    'combobox',
    'api_builder',
    'try!analytics'
  ], function() {
    var jQuery = arguments[0];
    var AlmCommon = arguments[3];
    var ComboBox = arguments[4];
    var ApiBuilder = arguments[5];
    var Analytics = arguments[6];

    var API = init(jQuery, AlmCommon, ComboBox, ApiBuilder, Analytics);
    window.BW = window.BW || {};
    window.BW.sprinthome = API;

    return API;
  });

})();
