(function() {
  var init = function ($, AlmCommon, ComboBox, ApiBuilder, moment, BacklogFilter, BacklogUtils, RequestManager, Analytics) {
    "use strict";
    var CONFLICT_RESPONSE_CODE = 409,
     ERROR_RESPONSE_CODE = 500,
     STATUS_COL_SELECTOR = 'td[data-local-field="Status__c"]',
     userDateTimeInfo,
     fieldTypes,
     picklistMap,
     queuedEvents = [],
     queueTimeout,
     previousYPosition = 0,
     previousBannerHeight = 0,
     viewingCustomBacklog = false,
     inactiveStatuses = [],
     TABLE_MAX_HEIGHT = 310,
     SCROLL_EVENT_THRESHOLD = 5,
     VERTICAL_FILTER_PANEL_STICKY_OFFSET = 170;

    //on document ready
    $(function () {
        if (typeof Sarissa !== 'undefined' && Sarissa && Sarissa.originalXMLHttpRequest) { // Browser is IE.
          $.ajaxSetup({ // Override originalXMLHttpRequest to address CometD Streaming in IE (Item-04395)
            xhr: function() {
              try {
                  return new Sarissa.originalXMLHttpRequest();
              } catch ( e ) {}
            }
          });
        }

        // engaging edit mode
        $(document).on("click", ".view-priority, .unprioritized-warning-sign", function () {
            $(this).closest("tr").addClass("edit-mode").find('input').focus();
        });

        $(document).on("click", ".upload-action", function () {
          Analytics.trackEvent('Bulk Import Backlog Items', 'Open Bulk Import');
        });
        
        $(document).on("keypress", ".edit-mode input", function(evt){
          AlmCommon.performActionOnEnter($(this), evt, bulkEditPriority);
        });

        //clear errors
        $(document).on("click", ".message .close", function () {
            $(this).closest(".msg-panel").empty();
            var $rows = $(".alm-table tbody tr.conflicted");
            $rows.removeClass('conflicted');
        });

        $('#alm-container').on('click', '#unprioritized-header', function() {
          $(this).toggleClass('closed');
          $('tr.unprioritized').toggle();
        });

        AlmCommon.enableShiftSelect({
          container : "#alm-container",
          parent: ".select",
          selector : "table.alm-table tbody label.checkbox span"
        });

        $( "#alm-container" ).on( "click", ".select-all-checkbox", function() {
          var $table = $(this).closest('table');
          $table.find( 'input[type="checkbox"]').filter(function() {
            return $(this).closest('tr').is(':visible');
          }).prop( "checked", $(this).prop( "checked" ) );
        });

        $( "#alm-container" ).on( "click", ".banner-wrap .message .cancel-btn", function(){
          AlmCommon.closePageMessage($(this).parents().closest('.message'), "[id$='custom-messages']", ".message", adjustPageMessages);
        });

        $( "#alm-container" ).on( "click", ".load-more-btn", loadRemainingItems);

        viewingCustomBacklog = $('#viewing-custom-backlog').val() === 'true';

        // TODO: On page refresh when scrolled down page, top position is not correct
        var backlogHeaderOffset = 0;
        if ($('#backlog-table thead')[0] !== undefined) {
          backlogHeaderOffset = $('#backlog-table thead').offset()['top'];
        }
        $(document).scroll(function(){
          var scrollTopPosition = window.scrollY || document.body.scrollTop || document.documentElement.scrollTop;
          if ( Math.abs(previousYPosition - scrollTopPosition) <= SCROLL_EVENT_THRESHOLD || scrollTopPosition == previousYPosition || scrollTopPosition <= backlogHeaderOffset) return;
          if(scrollTopPosition > previousYPosition && getPageMessages().length == 0) { // Scroll Down
            if (!$('.banner-wrap').hasClass('minimized')){
              toggleBanner(true);
            }
          } else {
            if ($('.banner-wrap').hasClass('minimized')){ // Scroll Up
              toggleBanner(false);
            }
          }
          previousYPosition = scrollTopPosition;
        });

        $('#backlog-filter-panel > .page-block-panel-body').scroll(function() {
          $('#backlog-filter-panel .ui-menu:visible').each(function(index) {
            var id = $(this).prop('id');
            if (id) {
              var index = id.slice(id.lastIndexOf('-') + 1) - 1;
              var $filterInput = 
                $('#backlog-filter-panel > .page-block-panel-body')
                .find('.page-block-panel-section:eq(' + index + ') .alm-combobox')
              var offset = $(this).offset({
                top : $filterInput.offset().top + $filterInput.height()
              });
            }
          });
        });

        $( "#alm-container" ).on( "click", ".alm-action-btn.alm-btn.new-btn", function(){
          Analytics.trackEvent('Backlog', 'Create Backlog Item', 'Backlog - Create Single Backlog Item');
        });
        
        // $('#alm-container').on('click', '#auto-prioritization-button-container button', function() {
        //   setBacklogAutoPrioritizationBehavior($(this).data('behavior'));
        // });

        init();

        previousBannerHeight = $('.banner-wrap').height();
        $(window).on("resize", function(){
          BacklogUtils.doWindowResize();
          var currentBannerHeight = $('.banner-wrap').height();
          if (previousBannerHeight != currentBannerHeight){
            adjustPageMessages();
          }
          previousBannerHeight = currentBannerHeight;

          $('#backlog-table thead.is_stuck + div.table-header-spacer').css('height',  $('#backlog-table thead').height());
        });
    });

    function addUnprioritizedRow($row) {
      $row.removeClass("prioritized").addClass("unprioritized");
      var warning = $('<img title="These items are un-priortized.  Click or drag and drop to assign them a priority" class="unprioritized-warning-sign" src="/s.gif" />')
        .tooltip();
      $row.find('.priority').append(warning);
      $('#unprioritized-header').after($row);
      initDraggable();
    }

    function makeRowPrioritized($row) {
      $row.removeClass("unprioritized").addClass("prioritized");
    }

    /**
     * Detaches prioritized rows in the provided backlog table
     * table - optional parameter specifying the table from which to detach prioritized rows. Defaults to the primary backlog table.
     * @return {Array}  array of jquery wrapped elements
     */
    function detachPrioritizedRows(table) {
      // If the table argument cannot be resolved, default to the primary backlog table.
      if ($(table)[0] === undefined) {
        table = '#backlog-table';
      }

      var prioritizedRows = [];

      $(table).find('tr.prioritized').detach().each(function(){
        prioritizedRows.push( $(this) );
      });
      return prioritizedRows;
    }

    function initColResizable() {
      var $table = $("#alm-table-panel .alm-table");

      //force table size to be in px
      $table.width($table.width());

      $table.colResizable({
        liveDrag:false,
        gripInnerHtml:"<div class='grip'></div>",
        draggingClass:"dragging",
        hoverCursor: "col-resize",
        dragCursor: "col-resize",
        postbackSafe: false,
        minWidth: 60
      });
    }

    function animateCells($cells, duration) {
        $cells.addClass("drag-helper").removeClass("drag-helper", duration);
    }

    /**
     * Backlog Item used for sending data to remote actions
     * @constructor
     */
    function BacklogItem($backlogRow) {
      this.id = $backlogRow.data('backlog-id');
      this.priority = $backlogRow.data('priority');
      if (this.priority === "") {
        this.priority = null;
      }
      this.oldPriority = $backlogRow.data('old-priority');
      this.status = $backlogRow.find(STATUS_COL_SELECTOR).data('fieldvalue');
      if (this.status === "") {
        this.status = null;
      }
    }

    function BacklogItemRow($backlogRow) {
      BacklogItem.call(this, $backlogRow);
      this.$row = $backlogRow;
    }

    BacklogItemRow.prototype = Object.create(BacklogItem.prototype);
    BacklogItemRow.prototype.constructor = BacklogItemRow;

    BacklogItemRow.prototype.updateRow = function(updatedRecordMsg) {
      var key,
       updatedSObj = updatedRecordMsg.data.sobject;

      for (key in updatedSObj) {
        if (updatedSObj.hasOwnProperty(key)) {
          var value = updatedSObj[key];
          value = (value === null || value === undefined) ? '' : value;

          var $cell = this.$row.find('td.' + key);
          if ($cell.length && $cell.text() !== value) {
            var type = fieldTypes[key] ? fieldTypes[key].toLowerCase() : null;
            switch(type) {
              case 'boolean':
                var $img = $cell.find('img');
                if (value === true) {
                  $img.attr('src', '/img/checkbox_checked.gif')
                    .attr('alt', 'Checked')
                    .attr('title', 'Checked');
                } else {
                  $img.attr('src', '/img/checkbox_unchecked.gif')
                  .attr('alt', 'Not Checked')
                  .attr('title', 'Not Checked');
                }
                $cell.data('fieldvalue', value);
                break;
              case 'reference':
                //TODO: not supported currently
                break;
              case 'date':
                setDateField($cell, value);
                $cell.data('fieldvalue', $cell.text());
                break;
              case 'datetime':
                setDateField($cell, value, true);
                $cell.data('fieldvalue', $cell.text());
                break;
              case 'picklist':
                if (picklistMap && picklistMap[key]){
                  $cell.text(picklistMap[key][value]);
                  $cell.data('fieldvalue', value);
                  break;
                }
              default:
                $cell.text(value);
                $cell.data('fieldvalue', value);
                break;
            }
          }
        }
      }
    }

    function getUserDateTimeInfo() {
      if (!userDateTimeInfo) {
        var locale = $('#user-locale').val();
        if (locale) {
          locale = locale.replace('_', '-');
        }

        userDateTimeInfo = {
          locale : locale,
          timezone : $('#user-timezone').val()
        };
      }

      return userDateTimeInfo;
    }

    function setBacklogStatus($backlogRows, newStatus) {
      $backlogRows.find(STATUS_COL_SELECTOR).data( 'fieldvalue', newStatus )
                                            .find( 'span').text( newStatus );
    }

    /**
     * Sets the formatted date field on a DOM element.
     */
    function setDateField($cell, value, isDateTime) {
      var formatOptions = {
          format: 'l',
       },
       locale = getUserDateTimeInfo().locale;

      if (!value) {
        $cell.text('');
        return;
      } else if (isDateTime) {
        formatOptions.format = 'l LT';
        formatOptions.timeZone = getUserDateTimeInfo().timezone;
      } else {
        value = moment.utc(value);
      }

      $cell.text( AlmCommon.formatDateTime(value, locale, formatOptions) );
    }

    function beginSave() {
      AlmCommon.toggleSave();
      AlmCommon.clearMsgs(adjustPageMessages);
    }

    function bulkEditPriority() {
        Analytics.trackEvent('Backlog', 'Prioritize Backlog Item', 'Backlogs - Prioritize By Priority Number');
        // fix for IE focus bug
        window.focus();

        var originalWindowScrollTop = $(window).scrollTop();

        var edits = [],
         outOfBoundsRows = [],
         rows = [],
         unprioritized = [],
         $unprioritizedSection = $("#unprioritized-header"),
         maxPriority = $('tr.prioritized').last().data('priority'),
         $allUnprioritizedRows = $('tr.unprioritized'),
         moreRecordsToLoad = $('#load-more-row').length != 0;


        $allUnprioritizedRows.each(function() {
          var $this = $(this);
          $this.data('unprioritized-position', $allUnprioritizedRows.index($this));
        });

        $("#alm-table-panel .alm-table tbody tr").not( $unprioritizedSection ).detach().each(function () {
          var $row = $(this);
          if ($row.hasClass("edit-mode")) {
            var $input = $row.find(".edit-priority input"),
             priority = Number( $input.val() );

            $row.removeClass("edit-mode");

            if (priority < 1 || isNaN( priority )) {
              $input.val( $row.data('priority') );
              if ($row.hasClass("unprioritized")) {
                unprioritized.push($row.get(0))
              } else {
                rows.push($row);
              }
            } else {
              $row.data('priority', priority);

              if (priority > maxPriority && moreRecordsToLoad) {
                outOfBoundsRows.push($row);
              } else {
                makeRowPrioritized($row);
                edits.push($row);
              }
            }
          } else if ($row.hasClass("unprioritized")) {
            unprioritized.push($row.get(0))
          } else {
            rows.push($row);
          }
        });

        $unprioritizedSection.after(unprioritized);
        sortTableByPriority(edits, rows);

        RequestManager.invokeFunction(renumber);

        RequestManager.invokeFunction(updateOutOfBoundsPriorities, [outOfBoundsRows]);

        updateUnprioritizedCount();

        if (edits.length > 0) {
          var rowsToAnimate = [];

          var headerMinimizedHeight = $('#backlog-table thead').height();
          var headerFullHeight = headerMinimizedHeight + $('.banner-wrap').height() - 2;

          var currentHeaderHeight = $('.banner-wrap').hasClass('minimized') ? headerMinimizedHeight : headerFullHeight;

          // If scrolling to the target position will result in a downward scroll (and there are no page messages), the header will be minimized. An upward scroll will imply a full header.
          var positionOffset = ((originalWindowScrollTop < (edits[0].offset().top - currentHeaderHeight)) && getPageMessages().length === 0) ?
            headerMinimizedHeight :
            headerFullHeight;

          if (!$('#backlog-table thead').hasClass('is_stuck')) {
            positionOffset += headerFullHeight;
          }

          window.scrollTo(0, edits[0].offset().top - positionOffset);

          // If the highest-priority element is less than one window's length from the bottom of the page, scrolling to it will cause header issues. Toggling the banner into the minimized state helps alleviate this.
          if ((edits[0].offset().top - (originalWindowScrollTop + positionOffset)) >= 0) {
            toggleBanner(true);
          }

          edits.forEach(function(element) {
            rowsToAnimate.push(element.get(0));
          });
          animateCells( $(rowsToAnimate).find("td"), 3000);
        } else {
          // All edits have been moved out of the loaded list, so maintain the screen's current position.
          window.scrollTo(0, originalWindowScrollTop);
        }
        Analytics.trackEvent('Backlog Item', 'Prioritization', 'Bulk Edit');
    }

    function bulkEditStatuses() {
      beginSave();

      var backlogsToSave = [],
       newStatus = $('#backlog-status').val(),
       $matchingRows = $('.alm-table tbody tr input.row-select:checked').prop( 'checked', false).closest('tr');
      $('.alm-table thead tr input.select-all-checkbox').prop( 'checked', false);

      $matchingRows.each(function(){
        backlogsToSave.push( new BacklogItem($(this)) );
      });

      AlmCommon.clearMsgs(adjustPageMessages);

      updateStatuses(backlogsToSave, newStatus, function(result, event){
        if (event.status) {
          if (result.isSuccess) {
            var matchingCellsFiltered = [],
             matchingCells = [];
            setBacklogStatus($matchingRows, newStatus);

            $matchingRows.each(function(){
              var cell = $(this).find(STATUS_COL_SELECTOR).get(0);
              if ($(this).hasClass('filter-match')) {
                matchingCellsFiltered.push( cell );
              } else {
                matchingCells.push( cell );
              }
            });
            $(matchingCellsFiltered).addClass("reverse-animate").removeClass("reverse-animate", 3000);
            animateCells( $(matchingCells), 3000);

            window.setTimeout(function(){
              BacklogFilter.filterByCriteria();
              if (result.inactive) {
                $matchingRows.remove();
                RequestManager.invokeFunction(renumber);
              }
            }, 3000);
          } else {
            if (result.errorCode == CONFLICT_RESPONSE_CODE) {
              handleConflict( result)
            } else {
              addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.ERROR, result.errorMsg);
            }
          }
        } else if (event.message){
          addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.ERROR, event.message);
        }

        window.setTimeout(function(){
          AlmCommon.toggleSave();
        }, 1000);
      });

      $('#backlog-status').val('');
      setBulkActionDisabled();
    }

    function initBulkActions() {
      $('#alm-container').on('click', function(event) {
        if ($(event.target).is('#actions-btn, #actions-btn > img')
             && !$('#actions-btn').hasClass('inactive')) {
          $('#bulk-actions .bulkflyout').show();
        } else {
          $('#bulk-actions .bulkflyout').hide();
        }
      });

      ComboBox.init({
        inputSelector : "#backlog-status",
        parentContainer : '#bulk-actions',
        appendTo : '#bulk-actions',
        isMultiSelect : false,
        selectAction : function selectCallback(){
          var status = $('#backlog-status').val(),
          matches = $('#backlog-status').closest('.alm-combobox').find('.filter-values option[value="' + getBacklogItemStatusValueFromPicklistLabel(status) + '"]');
          if (status !== '' && matches.length > 0) {
            $('#bulk-actions .status-confirm').toggle('slide', { direction : "left" });
          }
        }
      });

      $( "#alm-container" ).on( "click", 'table.alm-table input[type="checkbox"]', setBulkActionDisabled);
      $('#alm-container').on('click', '#bulk-actions .bulk-continue', bulkEditStatuses);

      $('#alm-container').on('click', '#bulk-actions a.cancel', function() {
        $(this).blur();
        $('#bulk-actions .status-confirm').toggle('slide', { direction : "left" });
      });

      $('#change-status-option').on('click', function(){
        $('#bulk-actions .alm-combobox')
        .css('display', 'inline-block')
        .find('#backlog-status')
        .focus();
      });

      $('#send-to-top-option').on('click', sendToTop);
      $('#send-to-bottom-option').on('click', sendToBottom);

      setBulkActionDisabled();
    }

    function initSortable() {
        $("#prioritized-section").sortable({
            disabled: Number($('#permission-level').val()) < AlmCommon.PERMISSION_LEVEL.FULL,
            containment: "#alm-table-panel",
            items: "> tr.prioritized",
            placeholder: "drop-placeholder",
            cursor: "move",
            axis: "y",
            scrollSpeed : 10,
            scrollSensitivity : 40,
            helper: function (e, tr) {
                var $originals = tr.children(),
                 $helper = tr.clone();
                $helper.children().each(function (index) {
                    //force the width to be in a non relative measure
                    var $original = $originals.eq(index);
                    $(this).width($original.width())
                     .height($original.height())
                     .css('vertical-align', 'middle')
                     .css('padding', $original.css('padding'))
                     .addClass("drag-helper");
                });
                $helper.height(tr.height());
                $helper.width(tr.width());
                $helper.css('left', '20px');
                return $helper;
            },
            stop: function (event, ui) {
                if (ui.helper) {
                  ui.helper.remove();
                }
                RequestManager.invokeFunction(renumber);
                ui.item.children().addClass("drag-helper")
                window.setTimeout(function () {
                    ui.item.addClass("moved");
                    ui.item.children().removeClass("drag-helper", 1500);
                    ui.item.removeClass("moved");
                }, 100);
                Analytics.trackEvent('Backlog', 'Prioritize Backlog Item', 'Backlogs - Prioritized By Drag and Drop');
            },
            receive: function( event, ui ) {
              ui.helper.addClass("prioritized");
              ui.helper.removeClass("unprioritized");
              animateCells(ui.helper.find('td'), 1500);
              window.setTimeout(function () {
                ui.item.remove();
                updateUnprioritizedCount();
              }, 40);
            }
        }).addClass('filtered');
    }

    function initDraggable() {
      var activeScrollAreas = [];
      $("tr.unprioritized").draggable({
          disabled: Number($('#permission-level').val()) < AlmCommon.PERMISSION_LEVEL.FULL,
          containment: "#alm-table-panel",
          connectToSortable : "#prioritized-section",
          cursor: "move",
          axis: "y",
          helper: function () {
            var tr = $(this),
              $originals = tr.children(),
              $helper = tr.clone();
            $helper.children().each(function (index) {
              //force the width to be in a non relative measure
              var $original = $originals.eq(index);
              $(this).width($original.width())
              .height($original.height())
              .css('vertical-align', 'middle')
              .css('padding', $original.css('padding'))
              .addClass("drag-helper");
            });
            $helper.height(tr.height());
            $helper.width(tr.width());
            $helper.css('right', '40px');
            return $helper;
          },
          scrollSpeed : 10,
          scrollSensitivity : 40,
          drag: function(event, ui) {
            AlmCommon.handleDroppableScroll(event, ui, activeScrollAreas);
          },
          start: function(event, ui) {
            $(this).hide();
            activeScrollAreas = AlmCommon.buildDroppableScrollAreas('#alm-table-panel');
          },
          stop: function(event, ui) {
            var $row = $(this);
            window.setTimeout(function () {
              $row.show();
            }, 50);
          },
          revert: "invalid"
      });
  }

    function init() {
      AlmCommon.blockUI('#backlog-display-panel');
      BacklogFilter.initFilters();
      initBulkActions();
      afLoadBacklogItems();
      loadFieldTypes();
      // setSelectedBacklogAutoPrioritizationBehavior($('input[id$="auto-prioritization-behavior"]').val());
    }

    function initPushTopics() {
      remoteGetInactiveStatuses(function(result, event) {
        if (event.status) {
          inactiveStatuses = result;

          getPushTopic(function(result, event) {
            if (event.status) {
              startSubscription(result);

            } else if (event.message){
              addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.ERROR, event.message);
            }
          });
        } else if (event.message) {
            addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.ERROR, event.message);
        }
      });
    }

    function loadFieldTypes() {
      remoteGetFieldTypes(function(result, event) {
        if (event.status) {
            fieldTypes = result.typeMap;
            picklistMap = result.picklistMap;
        } else if (event.message){
            addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.ERROR, event.message);
        }
      });
    }

    function loadRemainingItems() {
      $('#load-more-row').remove();
      showAdditionalItemsPlaceholder();
      afLoadAllRemainingItems();
    }

    function finishAdditionalItemLoad(){
      $('#prioritized-section').append($('#additional-backlog-item-table tr'));
      AlmCommon.unblockUI('.additional-items-placeholder div');
      $('.additional-items-placeholder').remove();
      RequestManager.invokeFunction(renumber);
      BacklogFilter.filterByCriteria();
    }

    function finishSpecificItemLoad() {
      sortTableByPriority(detachPrioritizedRows('#additional-backlog-item-table'), detachPrioritizedRows('#backlog-table'));
      RequestManager.invokeFunction(renumber);
    }

    function finishLoadingBacklog() {
      $('.alm-table').css({visibility: 'visible'});

      BacklogUtils.doWindowResize();
      AlmCommon.unblockUI('#backlog-display-panel');

      initSortable();
      initDraggable();

      updateUnprioritizedCount();

      initPushTopics();

      showAdditionalItemsPlaceholder();
      afLoadAdditionalBacklogItems();
      BacklogFilter.filterByCriteria();

      $('.banner-wrap').stick_in_parent({
        parent: $('#alm-container'),
        bottoming : false
      });

      $('#backlog-table thead, #backlog-filter-container').stick_in_parent({
        parent:$('#alm-container'),
        offset_top: 80,
        bottoming : false,
        spacer: false
      })
      .on('sticky_kit:stick', function(){
         $('#backlog-filter-panel .page-block-panel-body').css('max-height', $(window).height() - VERTICAL_FILTER_PANEL_STICKY_OFFSET );
         $('#backlog-table thead.is_stuck + div.table-header-spacer').css('height',  $('#backlog-table thead').height());
      })
      .on('sticky_kit:unstick', function(){
         $('#backlog-filter-panel .page-block-panel-body').css('max-height', $(window).height() - BacklogUtils.VERTICAL_FILTER_PANEL_OFFSET );
      });

      $('#backlog-table thead').after('<div class="table-header-spacer"></div>');
    }

    /**
     * Adds a page message AND adjust stick elements
     */
    function addPageMessageToBanner(messageType, message, options){
      options = $.extend({showCloseButton:true, callback : adjustPageMessages}, options);
      AlmCommon.addPageMessage(messageType, message, options);
    }

    /**
     * If page messages are on the screen, resets the minimized state and adjust sticky elements
     */
    function adjustPageMessages(){
      if (getPageMessages().length != 0){
        toggleBanner(false);
      }
      adjustStickyElements();
    }

    /**
     * Adjust sticky elements with a new top offset of the banner height.
     */
    function adjustStickyElements(){
      var stickyElementSelector = '#backlog-table thead, #backlog-filter-container';
      var newStickyOffset = $(".banner-wrap").height();
      $(stickyElementSelector).css({top:newStickyOffset});
      AlmCommon.reInitializeStickyOptions(stickyElementSelector, {
        parent:$('#alm-container'),
        offset_top: newStickyOffset,
        bottoming : false
      });
    }

    /**
     * @return a list of page message elements on the page, either standard or custom
     */
    function getPageMessages(){
      return $("[id$='custom-messages'], [id$='apex-messages']").children();
    }

    /**
     * @param minimize Boolean to minimize the banner and reposition other elements
     */
    function toggleBanner(minimize){
      if (minimize === true && getPageMessages().length === 0){
        $('.banner-wrap, #backlog-table thead, #saving-container, #backlog-filter-container').addClass('minimized');
      } else {
        $('.banner-wrap, #backlog-table thead, #saving-container, #backlog-filter-container').removeClass('minimized');
      }
    }

    function showAdditionalItemsPlaceholder() {
      var colCount = $('#backlog-table thead th').length;
      var placeholder = $('<tr class="additional-items-placeholder"><td colSpan="' + colCount + '"><div></div></td></tr>');
      $('#prioritized-section').append(placeholder);
      AlmCommon.blockUI('.additional-items-placeholder div');
    }

    function renumber() {
      var backlogsToSave = [],
        priority = 0;

      $(".alm-table .prioritized").not(".ui-sortable-helper").each(function () {
        priority++;
        var $row = $(this);
        $row.find(".view-priority").text(priority);
        $row.find(".edit-priority input").val(priority);
        $row.data('priority', priority);

        $row.removeClass('conflicted');

        if (priority != $row.data('old-priority')) {
          backlogsToSave.push( new BacklogItem($row) );
        }
        $row.data('old-priority', priority);
      });

      if (backlogsToSave.length > 0) {
        updatePriorities(backlogsToSave);
      } else {
        RequestManager.completeFunction();
      }
    }

    function setBulkActionDisabled() {
      var checkedRows = $('#backlog-display-panel .alm-table').find( 'input:checked' ).length;

      if ($('#bulk-actions .status-confirm').is(':visible')) {
        $('#bulk-actions .status-confirm').toggle('slide', { direction : "left" });
      }

      if ( checkedRows > 0 ) {
        $('#actions-btn')
         .prop("disabled", false).removeClass('inactive');
      } else {
        $('#actions-btn')
         .prop("disabled", true).addClass('inactive');
        $('#backlog-status').closest('.alm-combobox').hide();
      }
    }

    function showWarning(message) {
        var warningMsg = $( templates["warning_msg"].render({
            "subject" : "Attention",
            "message" : message
        }) );
        $('.msg-panel').append( warningMsg );
    }

    function handleConflict(conflictResult) {
      var $tableBody = $('#backlog-display-panel tbody');
      if (conflictResult.recordIds) {
        conflictResult.recordIds.forEach( function(recordId) {
          $tableBody
          .find('tr[data-backlog-id="'+ recordId +'"]')
          .addClass('conflicted');
        });
      }
      AlmCommon.clearMsgs(adjustPageMessages);
      addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.WARNING, conflictResult.errorMsg);
    }

    function getBacklogItemStatusValueFromPicklistLabel(label){
      var statuses = AlmCommon.getSObjValue(picklistMap, 'Status__c', {})
      for ( var apiName in statuses ) {
        if ( statuses.hasOwnProperty(apiName) && statuses[apiName] === label ) {
            return apiName;
        }
      }
    }

    function handleStreamingUpdate(message) {

        if (message.data.event.type === "updated") {
            queuedEvents.push( message );
            if( queueTimeout ) {
                window.clearTimeout( queueTimeout );
            }

            queueTimeout = window.setTimeout(function() { doHandleStreamingUpdate() }, 100);
        }
    }

    function doHandleStreamingUpdate() {
      var messages = [],
       editedRows = [],
       recordsToLoad = [],
       $tableBody = $('#backlog-display-panel tbody'),
       hasEditingConflict = false,
       maxPriorityLoaded = $('#backlog-table').find('tr.prioritized').last().data('priority');
      //cancel any in progress drags
      //$(".alm-table tbody").sortable("cancel");
      while (queuedEvents.length > 0) { messages.push( queuedEvents.shift()  ); }

      var backlogItemIdsWithInactiveStatus = [];
      for (var i = 0; i < messages.length; i++) {
          var message = messages[i],
           priority = AlmCommon.getSObjValue(message.data.sobject, viewingCustomBacklog ? "Custom_Priority__c" : "Priority__c"),
           status  = AlmCommon.getSObjValue(message.data.sobject, "Status__c"),
           $row = $tableBody.find('tr[data-backlog-id="'+ message.data.sobject.Id +'"]'),
           backlogItem = new BacklogItemRow($row),
           isRowLoaded = $row.length;

          if (priority === "") {
            priority = null;
          }

          if (!isRowLoaded) {
            if (new Number(priority) < maxPriorityLoaded) {
              recordsToLoad.push(message.data.sobject.Id);
            }
            continue;
          }

          if (backlogItem.priority != priority) {
              var $priorityCell = $row.find('td.priority'),
               editedValue = $priorityCell.find('.edit-priority input').val();
              if (editedValue && backlogItem.priority != editedValue) {
                  $row.addClass("conflicted").removeClass("edit-mode");
                  hasEditingConflict = true;
                  //Fix for IE focus issue
                  $priorityCell.find('.edit-priority input').blur();
              }
              $priorityCell.find('.edit-priority input').val(priority);
              $priorityCell.find('.view-priority').text(priority);

              if($row.data('old-priority') == '') {
                  makeRowPrioritized( $row );
              }

              $row.data('priority', priority);
              $row.data('old-priority', priority);

              if ($row.data('priority') == null) {
                  addUnprioritizedRow( $row );
              } else {
                  editedRows.push( $row.detach() );
              }
          } else if(backlogItem.status != status) {
              setBacklogStatus($row, status);
              animateCells($row.find(STATUS_COL_SELECTOR), 5000);

              if ($.inArray(status, inactiveStatuses) !== -1) {
                backlogItemIdsWithInactiveStatus.push(message.data.sobject.Id);
              }
          }

          backlogItem.updateRow(message);
      }

      if (backlogItemIdsWithInactiveStatus.length > 0) {
        window.setTimeout(function() {
          backlogItemIdsWithInactiveStatus.map(function(backlogItemId) {
            $tableBody.find('tr[data-backlog-id="'+ backlogItemId +'"]').remove();
          });
          RequestManager.invokeFunction(renumber);
        }, 5000);
      }

      updateUnprioritizedCount();

      if (editedRows.length > 0) {
          var rowsToAnimate = [],
           otherRows = detachPrioritizedRows('#backlog-table');

          editedRows.forEach(function (element) {
              rowsToAnimate.push(element.get(0));
          });

          sortTableByPriority(editedRows, otherRows);
          var $rowsToAnimate = $(rowsToAnimate);
          animateCells($rowsToAnimate.find('td.priority'), 5000);

          if (hasEditingConflict) {
              $rowsToAnimate.filter('.conflicted').get(0).scrollIntoView(false);
              AlmCommon.clearMsgs(adjustPageMessages);
              addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.WARNING, "There are multiple users grooming this backlog. Another user has edited this record.");
          }
      }

      if (recordsToLoad.length > 0) {
        afLoadSpecificItems(recordsToLoad.join(','));
      } else {
        RequestManager.invokeFunction(renumber);
      }

      RequestManager.completeFunction();
    }

    function sendToTop() {
      sendItems(true);
    }

    function sendToBottom() {
      sendItems(false);
    }

    /**
     * Send selected backlog items to the top or bottom of the prioritized list
     * @param {Boolean} sendToTop
     */
    function sendItems(sendToTop) {
      var $selectedRows = $('.alm-table tbody tr input.row-select:checked')
      .prop( 'checked', false)
      .closest('tr');

      $selectedRows.detach().each(function () {
        var $row = $(this);
        if ($row.hasClass("unprioritized")) {
          makeRowPrioritized($row);
        }
      });

      var $prioritized = $('tr.prioritized').first();

      if (sendToTop && $prioritized.length) {
        $prioritized.before($selectedRows);
      } else if ($('#load-more-row').length) {
        $('#load-more-row').before($selectedRows)
      }  else {
        $('#prioritized-section').append($selectedRows);
      }
      RequestManager.invokeFunction(renumber);

      $selectedRows.eq(0).get(0).scrollIntoView(false);
      animateCells( $selectedRows.find("td.priority"), 3000);
      updateUnprioritizedCount();
      setBulkActionDisabled();
      Analytics.trackEvent('Backlog Item', 'Prioritization', 'Bulk Send');
    }

    /**
     * Sorts the rows of the table and re-inserts them into the DOM
     * Assumes that the rows are currently detatched.
     * @param {Array} editedRows - the rows of the table that have updated values
     * @param {Array} otherRows - All other rows in the table that not been updated
     */
    function sortTableByPriority(editedRows, otherRows) {
        //sort the edited rows by priority
        editedRows.sort(function (a, b) {
            return $(a).data('priority') -
                   $(b).data('priority');
        });

        editedRows.forEach(function (element) {
            var rowIndex = element.data('priority') - 1;
            otherRows.splice(rowIndex, 0, element);
        });

        $("#prioritized-section")
          .append(otherRows)
          .append($('#load-more-row'));
    }

    function reprioritizeRow($row, newPriority) {
        var reprioritized = false;
        $('#backlog-display-panel tbody tr').each(function(){
            var priority = Number($(this).data('priority'));
            if (priority >= newPriority) {
                $( this ).before( $row );
                reprioritized = true;
                return false;
            }
        });
        if (!reprioritized) {
            $('#prioritized-section').append($row);
        }
    }

    /**
     * Update the priorities of records that are being moved outside of the loaded priorities
     * @param {Array} rows  - the rows being moved outside of the loaded priorities
     */
    function updateOutOfBoundsPriorities(rows) {
      if (rows.length == 0) {
        RequestManager.completeFunction();
        return;
      }

      var columnCount = rows[0].find('td').length,
       backlogItemsToUpdate = [],
       backlogItemIds = [],
       prioritizedOffset = 0,
       unprioritizedOffset = -1;

      rows.forEach( function($row) {
        var backlogItem = new BacklogItem($row);
        backlogItemsToUpdate.push(backlogItem);
        backlogItemIds.push(backlogItem.id);
        var rowPlaceholder = $(
          templates["backlog_item_moved_placeholder"].render(
            $.extend({
              columnCount : columnCount,
              name : $row.find('.Name').text()
            },
            backlogItem
          ))
        );

        if ($row.hasClass("unprioritized")) {
          var position = $row.data('unprioritized-position') - unprioritizedOffset,
           $unprioritizedItems = $('#unprioritized-header, tr.unprioritized');

          unprioritizedOffset++;

          if (position > $unprioritizedItems.length - 1) {
            $('tr.prioritized:first').before(rowPlaceholder);
          } else {
            $unprioritizedItems.eq(position).before(rowPlaceholder);
          }
        } else {
          prioritizedOffset++
          var rowPosition = $('tr.prioritized').eq(backlogItem.oldPriority - prioritizedOffset);

          if (rowPosition.length) {
            rowPosition.before(rowPlaceholder);
          } else {
            $('#load-more-row').before(rowPlaceholder);
          }
        }

        window.setTimeout(function() {
          rowPlaceholder.remove();
        }, 5000);
      });
      updatePriorities(backlogItemsToUpdate);
      afUnloadBacklogItems(backlogItemIds);
    }

    function updatePriorities(backlogsToSave) {
      beginSave();
      remoteUpdatePriorities(backlogsToSave, function(result, event) {
        if (event.status) {
          if (!result.isSuccess) {
            if (result.errorCode == CONFLICT_RESPONSE_CODE) {
              handleConflict( result);
            } else {
              addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.ERROR, result.errorMsg);
            }
          }

        } else if (event.message){
          addPageMessageToBanner(AlmCommon.MESSAGE_TYPE.ERROR, event.message);
        }

        window.setTimeout(function(){
          AlmCommon.toggleSave();
        }, 1000);
      });
    }

    function updateUnprioritizedCount() {
      var count = $('#alm-table-panel tr.unprioritized').length,
       $header = $('#unprioritized-header');

      $header.find('.count').text( count );

      if (count > 0) {
        $header.show();
      } else {
        $header.hide();
      }
    }

    // function setBacklogAutoPrioritizationBehavior(behavior) {
    //   var autoPrioritizationBehaviorSelector = 'input[id$="auto-prioritization-behavior"]';

    //   if (behavior.toUpperCase() !== 'OFF') {
    //     Analytics.trackEvent('Backlog', 'Auto Prioritize On');
    //   }
      
    //   if (behavior.toUpperCase() !== $(autoPrioritizationBehaviorSelector).val().toUpperCase()) {
    //     $(autoPrioritizationBehaviorSelector).val(behavior);
    //     setSelectedBacklogAutoPrioritizationBehavior(behavior);
    //     afSetBacklogAutoPrioritizationBehavior();
    //   }
    // }

    // function setSelectedBacklogAutoPrioritizationBehavior(behavior) {
    //   $('#auto-prioritization-button-container button').removeClass('selected');
    //   $('#auto-prioritization-button-container button[data-behavior="' + behavior + '"]').addClass('selected');
    // }

    return new ApiBuilder({
      pure: {
        bulkEditPriority: bulkEditPriority,
        init: init,
        finishAdditionalItemLoad: finishAdditionalItemLoad,
        finishSpecificItemLoad: finishSpecificItemLoad,
        finishLoadingBacklog: finishLoadingBacklog,
        handleStreamingUpdate: handleStreamingUpdate,
        showWarning: showWarning,
        sendToBottom: sendToBottom,
        sendToTop: sendToTop,
        adjustPageMessages: adjustPageMessages,
        addPageMessageToBanner: addPageMessageToBanner,
        updateUnprioritizedCount: updateUnprioritizedCount
      },
      testOnly: {
        bulkEditStatuses: bulkEditStatuses,
        BacklogItemRow : BacklogItemRow,
        loadRemainingItems : loadRemainingItems,
        getFilterInputs : BacklogFilter.getFilterInputs,
        getCurrentSelectedValues : BacklogFilter.getCurrentSelectedValues,
        clearFilterSelections : BacklogFilter.clearFilterSelections,
        resetFilterByCriteria : BacklogFilter.resetFilterByCriteria,
        filterByCriteria : BacklogFilter.filterByCriteria,
        initSortable : initSortable,
        resetUserDateTimeInfo: function() {
          userDateTimeInfo = null;
        },
        sortTableByPriority : sortTableByPriority,
        detachPrioritizedRows : detachPrioritizedRows,
        initPushTopics : initPushTopics//,
        // setBacklogAutoPrioritizationBehavior : setBacklogAutoPrioritizationBehavior,
        // setSelectedBacklogAutoPrioritizationBehavior : setSelectedBacklogAutoPrioritizationBehavior
      }
    }).getApi();
  };// end init()

  define(
    [
      'jquery',
      'jquery-ui',
      'js_alm_common',
      'combobox',
      'api_builder',
      'cometd/jquery_cometd',
      'moment',
      'external/jquery.sticky-kit',
      'backlog_management/utils',
      'backlog_management/filter',
      'common/request-manager',
      'try!analytics'
    ], function() {

    var $ = arguments[0];
    var AlmCommon = arguments[2];
    var ComboBox = arguments[3];
    var ApiBuilder = arguments[4];
    var moment = arguments[6];
    var BacklogUtils = arguments[8];
    var BacklogFilter = arguments[9];
    var RequestManager = arguments[10];
    var Analytics = arguments[11];

    var API = init($, AlmCommon, ComboBox, ApiBuilder, moment, BacklogFilter, BacklogUtils, RequestManager, Analytics);

    window.BW = window.BW || {};
    window.BW.backlog = API;

    return API;
  });

})();