(function() {
  var init = function ($, AlmCommon, ApiBuilder, Analytics) {
    "use strict";

    var CARD_WIDTH = 258,
     CARD_MARGIN = 34;

     var PAGE = {
      BACKLOG_CARD : '.cbklg-card-wrap-hotspot',
    };

    //on document ready
    $(function () {
      init();
    });
    function init() {
      addEventHandlers();
      remoteGetAllCustomBacklogs(  function(result, event) {
        if (event.status) {
          // Decode HTML entities within backlog names before they're displayed on backlog cards.
          for (var i = 0; i < result.length; ++i) {
            result[i].name = AlmCommon.htmlDecode(result[i].name);
          }

          var backlogCardPartial = {"custom_backlog_card" : templates["custom_backlog_card"]},
           customBacklogCards = templates["custom_backlog_cards"].render({
              "custom_backlog_cards" : result,
              "namespace" : $('#alm-container').attr('data-namespace')
           }, backlogCardPartial);

          $('#current-custom-backlogs').prepend( customBacklogCards );

          setDefaultCustomBacklog($('#default-custom-backlog-id').val());
          $('#custom-backlog-panel').show();

          doWindowResize();
        } else if (event.message){
           addErrorMessageToBanner(event.message);
        }
      });

      setupSortableDragAndDrop();

      $(window).on("resize", doWindowResize);
    }

    function addEventHandlers() {
      $("#alm-container").on( "click", initFlyout);
      $( "#alm-container" ).on( "blur", "#new-input", toggleNewCustomBacklogMode);
      $( "#alm-container" ).on( "click", "#new-btn-container", toggleNewCustomBacklogMode);
      $( "#alm-container" ).on( "mousedown", ".add-btn", addCustomBacklog);
      $( "#alm-container" ).on( "keypress", "#new-input", function(evt) {
          AlmCommon.performActionOnEnter( $(this), evt, function() {
              addCustomBacklog();
          });
      });
      $( "#alm-container" ).on( "click", ".edit-card-icon", toggleCustomBacklogEditMode);
      $( "#alm-container" ).on( "blur", ".edit-input", toggleCustomBacklogEditMode);
      $( "#alm-container" ).on( "click", ".banner-wrap .message .cancel-btn", function(){
        AlmCommon.closePageMessage($(this).parents().closest('.message'), "[id$='custom-messages']", ".message");
      });
      $( "#alm-container" ).on( "mousedown", "#current-custom-backlogs .save-btn", function(evt){
        var editCustomBacklogInput = $(this).siblings('.edit-input'),
            customBacklogId = $(this).parents(PAGE.BACKLOG_CARD).data('custom-backlog-id'),
            newCustomBacklogName = editCustomBacklogInput.val();

        editCustomBacklog(editCustomBacklogInput, customBacklogId, newCustomBacklogName);
      });
      $( "#alm-container" ).on( "keypress", ".edit-input", function(evt) {
        AlmCommon.performActionOnEnter( $(this), evt, function($el) {
            var customBacklogId = $el.parents(PAGE.BACKLOG_CARD).data('custom-backlog-id'),
                newCustomBacklogName = $el.val();
            $el.blur();
            editCustomBacklog($el, customBacklogId, newCustomBacklogName);
        });
      });

      $('#alm-container').on('click', '.flyout-menu > ul > li.option-default', updateUserPreferences);
    }

    function setupSortableDragAndDrop() {
      $("#current-custom-backlogs").sortable({
        containment: "#custom-backlog-panel",
        cursor: "move",
        handle: ".handle",
        items: "> .ui-sortable-handle",
        revert: false,
        scroll: true,
        tolerance: "pointer",
        update: updateCustomBacklogSortOrder,
        zIndex: 9999,
        start: function(event, parent) {

          var cardWidth = $(PAGE.BACKLOG_CARD).width();
          $(parent.placeholder).css({
            "visibility": "visible",
            "width": cardWidth
          });
        }
      });
    }

    function updateCustomBacklogSortOrder() {
      var $customBacklogCards = $("#current-custom-backlogs").find(".ui-sortable-handle"),
          customBacklogIds = $customBacklogCards.map(function() {
            return $(this).data("custom-backlog-id");
          }).toArray();

      if (customBacklogIds) {
        remoteUpdateUserSpecificSortState(customBacklogIds.join(','), function(result, event) {
          if (event.message) {
            addErrorMessageToBanner(event.message);
          }
        });
      }
    }

    function initFlyout(event) {
      var target = $(event.target);

      if (target.is('.vertical-ellipsis')) {
        target.closest('.cbklg-card-wrap').find('.flyout-menu').show();
      } else {
        $(".flyout-menu").hide();
      }
    }

    function updateUserPreferences() {
      var card = $(this).parents(PAGE.BACKLOG_CARD),
          isCurrentDefault = card.hasClass('default'),
          id = (isCurrentDefault) ? "" : card.data('custom-backlog-id');

      // if the user clicked the flyout on the backlog that is currently marked as default
      // the user no longer wants the backlog as default so reset the id to empty string
      remoteUpdateUserPreferences(id, function(result, event) {
        if (event.status) {
          setDefaultCustomBacklog(id);
        } else if (event.message) {
          addErrorMessageToBanner(event.message);
        }

      });
    }

    function setDefaultCustomBacklog(requestedId) {
      var customBacklogId,
          card;

      $('.vertical-ellipsis').each(function() {
        card = $(this).closest(PAGE.BACKLOG_CARD);
        customBacklogId = card.data('custom-backlog-id');

        if (customBacklogId === requestedId) {
          card.addClass('default');
        } else {
          card.removeClass('default');
        }
      });
    }

    function doWindowResize() {
      renderBlankCards();
      resizeCards();
    }

    /**
     * Update the backlog card widths to observe custom responsive behavior
     */
    function resizeCards() {
      var totalWidth =  $('#custom-backlog-panel > div').width();

      var cardWidth = getCardWidth(getCardColumnCount(), totalWidth);
      $(PAGE.BACKLOG_CARD).css({"width": cardWidth});

      var inputPadding = 22;
      var $backlogCards = $(PAGE.BACKLOG_CARD);
      //resize edit input so it fills entire card
      $backlogCards.find('.edit-input').width(
        $backlogCards.width() - $backlogCards.find('.save-btn').outerWidth() - inputPadding
      );
    }

    /**
     * Calculates the card width as a percentage based on the size of the area and the number of columns
     * @param {Number} columnCount
     * @param {Number} areaWidth
     * @returns {String}  the card width percent value as a string
     */
    function getCardWidth(columnCount, areaWidth) {
      var marginWidthPercentage = ( 100 * columnCount * CARD_MARGIN ) / areaWidth;
      var percentage = (100 - marginWidthPercentage) / columnCount;

      return percentage + "%";
    }

    function editCustomBacklog(editCustomBacklogInput, customBacklogId, customBacklogName){
      AlmCommon.clearMsgs();
      var originalName = $(editCustomBacklogInput).parents(PAGE.BACKLOG_CARD).data('custom-backlog-name');
      if (customBacklogName !== '' && originalName != customBacklogName){
        AlmCommon.toggleSave();
        remoteUpdateCustomBacklog(customBacklogId, customBacklogName, function(result, event){
          window.setTimeout(AlmCommon.toggleSave, 500);
          var errorMsg = event.message || result.errorMsg;
          if (event.status && result.isSuccess) {
            $(editCustomBacklogInput).parents(PAGE.BACKLOG_CARD)
              .data('custom-backlog-name', customBacklogName)
              .find('.custom-backlog-name a')
              .attr('title', customBacklogName)
              .text(customBacklogName);
            updateCustomBacklogSortOrder();
          } else if (errorMsg) {
            $(editCustomBacklogInput).val(originalName);
            addErrorMessageToBanner(errorMsg);
          }
        });
      }
    }

    function toggleNewCustomBacklogMode() {
      if ($('#new-btn-container').is(':visible')){
        $('#new-input').val('');
      }
      $('#new-btn-container').toggle('slide', { direction : "left" });
      $('#new-input-container').toggle('slide', {
        direction : "left",
        queue : false,
        complete: function() {
          $('#new-input').focus();
        }
      });
    }

    function toggleCustomBacklogEditMode() {
      var editContainer = $(this).closest('.cbklg-card-wrap').find('.edit-container'),
          editInput = editContainer.find('input');
      if (!editContainer.is(':visible')){
        editInput.val(editContainer.parents(PAGE.BACKLOG_CARD).data('custom-backlog-name'));
      }
      editContainer.toggle();
      editInput.focus();
    }

    /**
     * Returns the number of cards that can fit in a row in the backlog window
     */
    function getCardColumnCount() {
      var $customBacklogsPanel = $('#custom-backlog-panel > div');
      return Math.floor( $customBacklogsPanel.width() / (CARD_WIDTH + CARD_MARGIN) );
    }

    /**
     * @param {Number}  columns    The number of columns to be displayed
     * @param {Number}  customBacklogCount    The number of custom backlogs
     * @returns {Number}  the number of blank cards to render on the page
     */
    function getBlankCardCount(columns, customBacklogCount) {

      var MAX_ROWS_BLANK_CARDS = 2;

      if (columns && customBacklogCount / columns < MAX_ROWS_BLANK_CARDS) {
        return columns * MAX_ROWS_BLANK_CARDS - customBacklogCount;
      } else {
        var danglingCards = (customBacklogCount % columns);
        return  danglingCards ? columns - danglingCards : 0;
      }
    }

    function renderBlankCards() {
      // remove all blank cards
      $('div.cbklg-card-wrap-hotspot.cbklg-card-default').remove();

      // get the number of active backlogs
      var currentCustomBacklogs = $("#current-custom-backlogs .cbklg-card-wrap").length;

      var blankCard = templates["placeholder_card"].render({prefix:'cbklg'});

      var activeBlankCards = "",
          blankCardsCount = getBlankCardCount(getCardColumnCount(), currentCustomBacklogs);

      for(var i = 0; i < blankCardsCount; i++) {
        activeBlankCards += blankCard;
      }

      $('#current-custom-backlogs').append(  activeBlankCards );
    }

    function addErrorMessageToBanner(errorMsg){
      AlmCommon.addErrorMessage(errorMsg, {showCloseButton:true});
    }

    function addCustomBacklog() {
      var newCustomBacklogName = $('#new-input').val().trim();
      AlmCommon.clearMsgs();
      if (newCustomBacklogName !== "") {
        Analytics.trackEvent('Backlog', 'Create Backlog', '');
        var customBacklogCard = $( templates["custom_backlog_card"].render({
            "name" : newCustomBacklogName,
            "customBacklogId" : "#",
            "totalItems" : "0",
            "unprioritizedItems" : "0"
        }) );
        AlmCommon.toggleSave();
        remoteCreateCustomBacklog( newCustomBacklogName, function(result, event) {
          window.setTimeout(AlmCommon.toggleSave, 500);
          var errorMsg = event.message || result.errorMsg;
          if (event.status && result.isSuccess) {
            $('#current-custom-backlogs').prepend( customBacklogCard );

            doWindowResize();

            customBacklogCard.data('custom-backlog-id', result.customBacklogId);
            var namespace = $('#alm-container').attr('data-namespace');
            customBacklogCard.find('.custom-backlog-name a').attr('href', '/apex/' + namespace + 'BacklogManagement?backlogid=' + result.customBacklogId);

            updateCustomBacklogSortOrder();
          } else if (errorMsg){
            addErrorMessageToBanner(errorMsg);
          }
        });
      }
      $('#new-input').blur();
    }

    return new ApiBuilder({
      pure: {
      },
      testOnly: {
        addEventHandlers : addEventHandlers,
        addCustomBacklog : addCustomBacklog,
        getBlankCardCount : getBlankCardCount,
        setCardMargin : function(margin) {CARD_MARGIN  = margin},
        getCardWidth: getCardWidth,
        renderBlankCards : renderBlankCards,
        setGetBlankCardCount : function(funct){getBlankCardCount = funct;}
      }
    }).getApi();
  };// end init()

  define(
    [
      'jquery',
      'jquery-ui',
      'js_alm_common',
      'api_builder',
      'try!analytics'
    ], function() {

    var $ = arguments[0];
    var AlmCommon = arguments[2];
    var ApiBuilder = arguments[3];
    var Analytics = arguments[4];

    var API = init($, AlmCommon, ApiBuilder, Analytics);

    window.BW = window.BW || {};
    window.BW.backlogHome = API;

    return API;
  });

})();