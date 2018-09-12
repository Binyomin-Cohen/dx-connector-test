/**
 * Depends
 *   - jQuery
 *   - BlockUI library
 */
 (function(global) {

  var init = function ($, moment, ApiBuilder) {
      "use strict";

      var KEYCODE_ENTER = 13;
      var KEYCODE_ESCAPE = 27;
      var KEYCODE_ARROWLEFT = 37;
      var KEYCODE_ARROWUP = 38;
      var KEYCODE_ARROWRIGHT = 39;
      var KEYCODE_ARROWDOWN = 40;
      var KEYCODE_A = 65;

      var KEYSTRING_ARROWLEFT = "arrow_left";
      var KEYSTRING_ARROWUP = "arrow_up";
      var KEYSTRING_ARROWRIGHT = "arrow_right";
      var KEYSTRING_ARROWDOWN = "arrow_down";

      var MESSAGE_TYPE = {
          ERROR : 'error',
          SUCCESS : 'success',
          INFO : 'info',
          WARNING : 'warning'
      };

      var NTH_CHILD_SUPPORT,
        hasUnsavedChanges = false;

      var SFDC_CONTAINER_HEIGHT = 218;

      var JOB_TYPE = {
          SCAN : 'scan',
          BUTR : 'butr',
          SYNC : 'sync'
      };

      var PERMISSION_LEVEL = {
        NONE : 0,
        READ_ONLY : 1,
        FULL : 2
      };

      /**
      * Adds a function to be executed before the unloading of the page.
      * @param func - The function to be executed.
      */
      function addBeforeUnloadEventListener(func) {
        var beforeUnload = func || this.unloadPage;
        if (global.addEventListener) {
          global.addEventListener("beforeunload", beforeUnload);
        } else {
          attachEvent('onbeforeunload', beforeUnload);
        }
      }

      function blockUI( selector ) {
          var options = {
              message: "<div id='block-ui'><img src='/s.gif' /></div>",
              css: { border: 'none', background: 'none' }
          };
          if(selector) {
              $(selector).block( options );
          }
          else {
              $.blockUI( options );
          }
      }

      function blockUIOffCenter( selector, cssOptions ) {
          var options = {
              message: "<div id='block-ui'><img src='/s.gif' /></div>",
              centerY: false
          };

          options.css = $.extend({ border: 'none', background: 'none' }, cssOptions);

          if(selector) {
              $(selector).block( options );
          }
          else {
              $.blockUI( options );
          }
      }


      /**
      * Displays a blocking modal window to the user.
      * @param options
      * @param options.content - The content of the modal to be displayed.
      * @param options.container - The container within which to attach the modal as a child.
      * @param options.width - Optionally set the width
      */
      function displayModal(options) {

        options = $.extend({
          content: "",
          width: '63%',
          height: '78%',
          overflow: 'auto'
        }, options);

        var modalOptions = {
          message: options.content,
          centerX: false,
          css: {
            cursor: 'auto',
            width:  options.width,
            top: 0,
            left:  0,
            bottom:  0,
            right:  0,
            border: 'none',
            background: 'none',
            position: 'fixed',
            height: options.height,
            margin: 'auto',
            overflow: options.overflow
          }
        };

        if (options.container === undefined) {
          $.blockUI(modalOptions);
        } else {
          $(options.container).block(modalOptions);
        }
        $('.blockOverlay').css({ cursor: 'auto', position: 'fixed' });
        $('.blockElement').css({ top: 0 });
      }

      /**
       * Adds event handler for <c:pageBlockPanelSection> headers
       * @param container - optional parameter for parent container to delegate event handling
       */
      function enableTwistyPageBlockPanelSections(container) {
        container = container || '#alm-container';
          $(container).on('click', '.page-block-panel-section-header a.section-title', function() {
            $(this).closest('.page-block-panel-section').toggleClass('expanded');
        });
      }

      /**
       * Adds event handler for <c:simpleAccordion> headers
       * @param container - optional parameter for parent container to delegate event handling
       */
      function enableSimpleAccordions(container) {
          var element = container || '#alm-container';
          $(element).on('click', '.simple-accordion-header', function() {
              $(this).closest('.simple-accordion').toggleClass('expanded');
         });
      }

      function unblockUI( selector ) {
          if(selector) {
              $(selector).unblock();
          }
          else {
              $.unblockUI();
          }
      }

      function isNthChildSupported() {
          if( NTH_CHILD_SUPPORT === undefined ) {

              NTH_CHILD_SUPPORT = false;
              var test =  $('<ul id="nth-child-test"><li/><li/><li/></ul>').appendTo($('body')),
               style = $('<style type="text/css">#nth-child-test li:nth-child(even){height:10px;}</style>').appendTo($('head'));

              if(test.children('li').eq(1).height() == 10) {
                  NTH_CHILD_SUPPORT = true;
              }
              test.remove();
              style.remove();
          }
          return NTH_CHILD_SUPPORT;
      }

      /**
      * Perform some action (execute callback) when a target arrow key is pressed.
      * @param properties
      *   $el - The element that is watching for an event.
      *   evt - The event that has been triggered.
      *   keys - An array of target keys that should execute the callback (e.g. ["arrow_left", "arrow_up", "arrow_right", "arrow_down"]).
      *   callback - The callback function to execute conditionally.
      */
      function performActionOnArrowKeyPress(properties) {
        var $el = properties.$el;
        var evt = properties.evt;
        var keys = properties.keys;
        var callback = properties.callback;

        if($.inArray(KEYSTRING_ARROWLEFT, keys) !== -1) {
          performActionOnKeyPress($el, evt, KEYCODE_ARROWLEFT, callback);
        }
        if($.inArray(KEYSTRING_ARROWUP, keys) !== -1) {
          performActionOnKeyPress($el, evt, KEYCODE_ARROWUP, callback);
        }
        if($.inArray(KEYSTRING_ARROWRIGHT, keys) !== -1) {
          performActionOnKeyPress($el, evt, KEYCODE_ARROWRIGHT, callback);
        }
        if($.inArray(KEYSTRING_ARROWDOWN, keys) !== -1) {
          performActionOnKeyPress($el, evt, KEYCODE_ARROWDOWN, callback);
        }
      }

      function performActionOnEnter($el, evt, callback) {
        performActionOnKeyPress($el, evt, KEYCODE_ENTER, callback);
      }

      function performActionOnEscape($el, evt, callback) {
        performActionOnKeyPress($el, evt, KEYCODE_ESCAPE, callback);
      }

      /**
       * Perform some action (execute callback) when pressing ctrl-a or cmd-a
       */
      function performActionOnSelectAll($el, evt, callback) {
        if (evt.ctrlKey || evt.metaKey) {
          performActionOnKeyPress($el, evt, KEYCODE_A, callback);
        }
      }

      /**
       * Perform some action (execute callback) if the triggered event is from the specified
       * targetKey
       * @param {Element|jQuery} context element
       * @param {Event} the triggered event
       * @param {Integer} target keycode
       * @param {Function} callback function to execute if event matches keycode
       */
      function performActionOnKeyPress($el, evt, targetKey, callback) {
        var key;
        if(global.event) {
          key = global.event.keyCode;     //IE
        }
        else {
          key = evt.which;     //firefox
        }

        // Return/Enter Key
        if(key == targetKey) {
          evt.preventDefault();
          callback($el);
        }
      }

      function stripeTable(selector) {
          if (!isNthChildSupported()) {
              var $table = $( selector );
              $table.find('tr').each(function(i) {
                  var styleClass = (i % 2 == 0) ? 'row-b' : 'row-a';
                  $(this).addClass( styleClass );
              });
          }
      }

      /**
       * Decodes an html encoded string i.e. '&amp;' returns '&'
       * Only use for trusted input as this exposes an XSS vulnerability
       */
      function htmlDecode(value) {
          if (value) {
              return $('<div />').html(value).text();
          } else {
              return '';
          }
      }

      /**
       * Escapes an id for use in jQuery selectors
       */
      function escapeId(id){
          return id.replace(/:/g,"\\\:");
      }

      /**
       * Display confirmation message if the user has unsaved changes
       * @return true if there are no changes or the user confirms
       */
      function confirmUnsavedChanges() {
        if (hasUnsavedChanges) {
          return this.unloadPage(null, true);
        } else {
          return true;
        }
      }

      function hasSaveErrors() {
        return $('[id$=has-save-errors]').val() === "true";
      }

      function getHasUnsavedChanges() {
        return hasUnsavedChanges;
      }

      function setHasUnsavedChanges(value) {
        hasUnsavedChanges = value;
      }

      /**
       * Display warning message when the page is being unloaded
       * @param {Event}   - the event
       * @param {boolean} - optional parameter to force the dialog to be shown using a confirm dialog
       *  instead of the browser unload dialog
       * adapted from this mdn article - https://developer.mozilla.org/en-US/docs/Web/Reference/Events/beforeunload
       */
      function unloadPage(e, forceConfirm) {
        var confirmationMessage = "Warning: There are unsaved changes on this page. Are you sure you want to close it?";
        if (hasUnsavedChanges) {
          if (forceConfirm === true) {
            return global.confirm(confirmationMessage);
          } else {
            (e || global.event).returnValue = confirmationMessage;     //Gecko + IE
              return confirmationMessage;                                //Webkit, Safari, Chrome etc.
          }
        }
      }

      /**
      * Gets the value of an sObject field taking into account package namespace
      * @param {{object}} sObject
      * @param {string} fieldName
      * @param {string|number|object} defaultVal - Defaults to empty string
      */
      function getSObjValue(sObject, fieldName, defaultVal) {
        if(!sObject) {
          return null;
        }
        if(typeof defaultVal === 'undefined') {
          defaultVal = '';
        }
        return sObject[fieldName] || sObject['alm_pm2__'+ fieldName] || defaultVal;
      }


    /**
     * @callback shiftClickCallback -
     * @param {jQuery} selected - jQuery wrapped set of matching items
     * @param {Boolean} isChecked - indicates if the items are being checked
     */

    /**
    * Enable shift + select functionality on a set of checkboxes. To work with Firefox and checkbox labels,
    *  set the selector to be on label instead of the checkbox
    *
    * @param {Object} options - param object
    * @param {String} options.container - selector for parent element to delegate event handling to
    * @param {String} options.parent - selector for parent element that contains the checkbox
    * @param {String} options.selector- selector for the set of elements
    * @param {shiftClickCallback} options.callback- optional callback function to execute on set of matched elements
    *   instead of default behavior of checking checkbox
    *
    *  Adapted from https://gist.github.com/DelvarWorld/3784055
    */
    function enableShiftSelect(options) {
       var lastChecked,
        callback = options.callback,
        defaultCallback = options.defaultCallback,
        parent = options.parent,
        selector = options.selector;

       $(options.container).on('click', selector, function(evt) {
         if(!lastChecked) {
           lastChecked = this;
           return;
         }

         if(evt.shiftKey) {
           var $boxes = $(selector),
             start = $boxes.index(this),
             end = $boxes.index(lastChecked),
             selected = $boxes.slice(Math.min(start, end), Math.max(start, end) + 1);

           if (callback && typeof callback === 'function') {
             callback(selected, lastChecked.checked || $(lastChecked).hasClass('selected'));
           } else {
             var checkboxes = (parent === undefined) ? selected : selected.closest(parent).find('input[type="checkbox"]');
             var isChecked = (parent === undefined) ? lastChecked.checked : $(lastChecked).closest(parent).find('input[type="checkbox"]').prop('checked');
             checkboxes.prop('checked', isChecked)
              .trigger('change');

             if (defaultCallback && typeof defaultCallback === 'function') {
               defaultCallback(checkboxes, isChecked);
             }
           }
           //prevent checkbox from being checked by browser
           evt.preventDefault();
         }

         lastChecked = this;
       });
    }

    function toggleSave() {
      $( '#saving-container' ).toggle('slide', {
        duration : 400,
        direction : "up"
      });
    }


    /**
     * @description  Toggles a button to edit mode. See sprint release button for example
     *
     * @param  {String} type - the identifier for the container. i.e. 'release'
     * @param  {String} from - the identifier for the current element in focus. i.e. 'input'
     * @param  {String} to - the identifier for the element to toggle to. i.e. button
     *
     */
    function toggleEditMode(type, from, to, attribute) {
      var attr = attribute || '.';

      if (from === 'btn') {
        $(attr + type + '-' + from + '-container').children().prop('disabled', true);
      } else if (to === 'btn') {
        $(attr + type + '-' + to + '-container').children().prop('disabled', false);
      }

      $(attr + type + '-' + from + '-container').toggle('slide', { direction : "left" });
      $(attr + type + '-' + to + '-container').toggle('slide', {
        direction : "left",
        queue : false,
        complete: function() {
          if (to === 'input') {
            $(attr + type + '-input').focus();
          }
        }
      });
      this.clearMsgs();
    }

    /**
     * @description  Toggles a sliding tray between open and closed
     * @param        {String|Element|jQuery} tray - The element or selector of the tray to toggle
     * @param        {String|Element|jQuery} trayHandle - The element or selector of the tray-handle to toggle
     * @param        {String} handlePosition - The position of the handle when tray is open. For example: "300px"
     * @param        options - optional arguments
     * @param        options.expandParent - boolean that controls if the parent element will be expanded to fit the
     *                                      tray. Defaults to false
     * @param        options.parentEl - optionally specify a parent to expand other than the direct parent
     * @param        options.parentMinHeight - optionally specify a minimum height for the parent. defaults to the tray height
     * @param        options.onStartHandler - optionally specify an event handler to call onStart of handle animation with arguments
                                            tray, trayHandle, handlePosition passed in as arguments
     * @param        options.onCompleteHandler - optionally specify an event handler to call onComplete of handle animation with arguments
                                            tray, trayHandle, handlePosition passed in as arguments
     */
    function toggleSlidingTray(tray, trayHandle, handlePosition, options) {
      var $handle = $(trayHandle),
        $tray = $(tray);

      options = $.extend({
        backgroundSiblings: false,
        expandParent : false,
        parentEl : $tray.parent(),
        parentMinHeight: $tray.outerHeight()
      }, options);

      if ($handle.hasClass("close")) {
        $tray.hide("slide", {
          direction: "left",
          queue: false,
          complete: function() {
            if (options.expandParent === true) {
              var parentEl = options.parentEl;
              parentEl.animate({height: parentEl.data('original-height')}, {
                complete: function() {
                  parentEl.css({
                    height: "auto",
                    minHeight: parentEl.data('original-min-height')
                  });
                },
                queue: false
              });
            }

            var originalZIndex = $handle.data('original-z-index');
            if (originalZIndex !== undefined) {
              $handle.css('z-index', originalZIndex);
            } else {
              $handle.css('z-index', 1);
            }
          }
        });
        $handle.animate({left: "0px"}, {
          start : function() {
            if (Object.prototype.toString.call(options.onStartHandler) == "[object Function]"){
              options.onStartHandler(tray, trayHandle, handlePosition);
            }
          },
          complete: function() {
            $handle.removeClass("close");
            if (Object.prototype.toString.call(options.onCompleteHandler) == "[object Function]"){
              options.onCompleteHandler(tray, trayHandle, handlePosition);
            }
          },
          queue: false
        });
      } else {
        if (options.expandParent === true) {
          var parentEl = options.parentEl;
          parentEl.data('original-height', parentEl.height());
          parentEl.data('original-min-height', parentEl.css("minHeight"));
          if (parentEl.height() < options.parentMinHeight) {
            parentEl.animate({height: options.parentMinHeight}, {
              queue: false,
              complete: function() {
                parentEl.css("minHeight", options.parentMinHeight);
              }
            });
            $handle.get(0).scrollIntoView(true);
          } else {
            parentEl.css("minHeight", options.parentMinHeight);
          }

        }

        $handle.data('original-z-index', $handle.css('z-index'));
        $handle.css('z-index', $tray.css('z-index') + 1);

        $tray.show("slide", {
          direction: "left",
          queue: false
        });
        $handle.animate({left: handlePosition}, {
          start : function() {
            if (Object.prototype.toString.call(options.onStartHandler) == "[object Function]"){
              options.onStartHandler(tray, trayHandle, handlePosition);
            }
          },
          complete: function() {
            $handle.addClass("close");
            if (Object.prototype.toString.call(options.onCompleteHandler) == "[object Function]"){
              options.onCompleteHandler(tray, trayHandle, handlePosition);
            }
          },
          queue: false
        });
      }
    }


    /**
     * Resizes the height of containers on a page when a browser gets resized.  Vertical scrollbar is added
     * for the container
     *
     *  @param {String} mainContainer - selector for the main container on the page
     *  @param {String} subContainer- selector for secondary container on the page, ie. filter panels
     *  @param {Number} offsetForPage- the amount of offset needed on for the page to get rid
     *  of the browser's vertical scrollbar
     *  @param {Number} offsetForSub- the amount of height to subtract on the secondary container
     *  to match the height of the main container
     *  @param {Object} [options] -
     */
    function windowResize(mainContainer, subContainer, offsetForPage, offsetForSub, options) {
      var PAGE_OFFSET = offsetForPage,
          MIN_WINDOW_HEIGHT = 639,
          SUB_CONTAINER_OFFSET = offsetForSub,
          windowHeight = $(global).height();

      options = $.extend({
        minWindowHeight : MIN_WINDOW_HEIGHT
      }, options);

      if( windowHeight < options.minWindowHeight) {
        windowHeight = options.minWindowHeight;
      }

      var height = windowHeight - (SFDC_CONTAINER_HEIGHT + PAGE_OFFSET);

      $(mainContainer).height( height );
      $(subContainer).height( height - SUB_CONTAINER_OFFSET);
    }

    /**
     * Changes the height of a set of elements based on the window height and offsets.
     */
    function resizeElements(elements, options) {
      elements.forEach(function(el) {
        var $element = $(el.element),
            offset = el.offset;
        windowResize($element, '', offset, 0, options);
      });
    }

    function reInitializeStickyOptions(selector, options){
      if (!selector || options === undefined || $(selector).stick_in_parent === undefined) return;
      $(selector).trigger("sticky_kit:detach");
      $(selector).stick_in_parent(options);
    }

    /**
     * @param pageMessageElement message element that should be closed
     * @param messagesSelector parent selector with child messages that contain the message and close button
     * @param childrenSelector children selector that should will filter the children of messagesSelector
     * @param removePageMessageHandler callback function should accept the index of the message to close AND pageMessageElement
     */
    function closePageMessage(pageMessageElement, messagesSelector, childrenSelector, removePageMessageHandler) {
      if (!messagesSelector) return;
      var messageToClose = $(pageMessageElement);
      var messageIndexToClose = $(messagesSelector).children(childrenSelector).index($(messageToClose));
      messageToClose.remove();
      if (typeof removePageMessageHandler === 'function' ){
        removePageMessageHandler(messageIndexToClose, pageMessageElement);
      }
    }

    /**
     * Displays a page message in any element with a class of <tt>.page-messages .msg-panel</tt>.
     * Format of message relies heavily on .page-messages class messages.
     *
     * @param {String} messageType - the type of message supported by page_message.mustache template
     * @param {String} message - the text that will be displayed on the page.
     * @param {String} options.clearPriorMessages - removes previous messages
     * @param {String} options.showCloseButton - toggle showing the close button
     * @param {String} options.messagePanel - the panel to display messages in.
     *
     */
    function addPageMessage(messageType, message, options) {
      if (!messageType || !message) return;
      options = options || {};

      message = parsePageMessage(message);

      var showCloseButton = options.showCloseButton !== undefined ? options.showCloseButton : false;

      if(options.clearPriorMessages) {
        clearMsgs();
      }

      var pageMessage = $( templates["page_message"].render({
        "message" : message,
        "showErrorContainer" : messageType == MESSAGE_TYPE.ERROR,
        "showSuccessContainer" : messageType == MESSAGE_TYPE.SUCCESS,
        "showInfoContainer" : messageType == MESSAGE_TYPE.INFO,
        "showWarningContainer" : messageType == MESSAGE_TYPE.WARNING,
        "showCloseButton" : showCloseButton
      }));
      var $msgPanel = (options.messagePanel === undefined) ? $('.page-messages .msg-panel') : $(options.messagePanel);
      $msgPanel.append( pageMessage ).show();

      if($msgPanel[0] !== undefined) {
        $msgPanel[0].scrollIntoView();
      }

      if (typeof options.callback === 'function' ){
        options.callback();
      }

    }

    function addErrorMessage(message, options) {
      addPageMessage(MESSAGE_TYPE.ERROR, message, options);
    }
    function addWarningMessage(message, options) {
      addPageMessage(MESSAGE_TYPE.WARNING, message, options);
    }
    function addInfoMessage(message, options) {
      addPageMessage(MESSAGE_TYPE.INFO, message, options);
    }
    function addSuccessMessage(message, options) {
      addPageMessage(MESSAGE_TYPE.SUCCESS, message, options);
    }


    /**
     * Displays an error message in any element with a class of <tt>msg-panel</tt>.
     *
     * @param {String} message - the text that will be displayed on the page.
     * @param        options - optional arguments
     * @param        options.clearPriorMessages - boolean that controls if prior error messages on screen get cleared.
     * @param        options.messagePanel - The panel to display messages in. The custom error panel must have an error text element with the class "error-text"
     * @param        options.standardTemplate - A boolean denoting whether or not a standard error message template should be used.
     * @param        options.template - The name of the template to be used for a custom error message (if options.standardTemplate is false).
     *
     */
    function showError(message, options) {
      options = options || {};

      if(!options.messagePanel) {
        defaultErrorMsg(message, options);
      } else {
        customErrorMsg(message, options);
      }
    }

    function defaultErrorMsg(message, options) {
      message = parsePageMessage(message);
      if (options.clearPriorMessages) {
        clearMsgs();
      }

      var errorMsg = $( templates["error"].render({
        "message" : message
      }) );

      var $msgPanel = $('.msg-panel');
      $msgPanel.append( errorMsg ).show();
      if($msgPanel[0] !== undefined) {
        $msgPanel[0].scrollIntoView();
      }
    }

    function customErrorMsg(message, options) {
      message = parsePageMessage(message);
      var $errorPanel = $(options.messagePanel);
      if($errorPanel.length === 0) {
        throw new Error('Unable to find error panel element.');
      }
      var $errorTextElem = null;

      if(options.clearPriorMessages) {
        clearMsgs();
      }

      var errorMsg;
      if(options.standardTemplate === true) {
        errorMsg = $(templates["error"].render({
          "message" : message
        }));
      } else if(options.template !== undefined) {
        errorMsg = $(templates[options.template].render({
          "message" : message
        }));
      } else {
        errorMsg = message;
      }

      $errorTextElem = $errorPanel.find('.error-text');
      if($errorTextElem.length === 0) {
        throw new Error(
          'Unable to find error text element. An element with class "error-text" is required.'
        );
      }

      $errorTextElem.append(errorMsg);
      $errorTextElem.attr("title", errorMsg);

      // Check for default error class and add (used to hide all messages later)
      if(!$errorPanel.hasClass('bw-error')) {
        $errorPanel.addClass('bw-error')
      }

      $errorPanel.show();
      $errorPanel[0].scrollIntoView();
    }

    function parsePageMessage(message) {
      if (message.indexOf('Error parsing json response:') > -1 && 
        message.indexOf('Logged in?') > -1) {
          message = 'Your session has timed out. Please log back in to continue.';
      }
      return message;
    }

    function animateScrollToElement($element) {
      var messageOffset = $element.offset();
      if (messageOffset !== undefined) {
        $('html, body').animate({
          scrollTop: $element.offset().top
        });
      }
    }

    function clearMsgs(callback) {
      var $msgPanel = $('.msg-panel, [id$="apex-messages"]'),
       hasMessages = $msgPanel.children('.message').length;
      $msgPanel.empty();
      // Clear out custom messages
      $('.bw-error')
        .hide()
        .find('.error-text')
        .empty();
      if (typeof callback === 'function' && hasMessages){
        callback();
      }
    }

    // Detect an event targeting some element that is not in the set of elements provided.
    function eventOccursOutsideElements(event, elements) {
      return $(event.target).parents(elements.join()).length === 0;
    }


    /**
     * Enables scrolling within a droppable element while dragging a draggble element near the border.
     * @param {Event} event - The drag event
     * @param {Object} ui - Reference to jQuery drag event handler
     * @param {Array} activeScrollAreas - Array of objects with the following properties:
     *    - {jQuery} - The droppable element in which scrolling occurs
     *    - {Integer} top, bottom, left, right
     */
    function handleDroppableScroll(event, ui, activeScrollAreas) {
      var scrollSensitivity =  20;
      var scrollSpeed =  20;
      activeScrollAreas.forEach(function(el) {
        if (event.pageX - el.left < scrollSensitivity && el.left < event.pageX) {
          el.droppable.scrollLeft( el.droppable.scrollLeft() - scrollSpeed );
        } else if (el.right - event.pageX  < scrollSensitivity && el.right > event.pageX) {
          el.droppable.scrollLeft( el.droppable.scrollLeft() + scrollSpeed );
        }
        if (event.pageY - el.top < scrollSensitivity && el.top < event.pageY) {
          el.droppable.scrollTop( el.droppable.scrollTop() - scrollSpeed );
        } else if (el.bottom - event.pageY < scrollSensitivity && el.bottom > event.pageY) {
          el.droppable.scrollTop( el.droppable.scrollTop() + scrollSpeed );
        }
      });
    }

    /**
     * @param {jQuery|String} areas - set of jquery wrapped elements or a selector for the areas to build
     * @return {Array} - Array of DroppableScrollArea
     */
    function buildDroppableScrollAreas(areas) {
      var scrollAreas = [];
      $(areas).each(function() {
        scrollAreas.push( new DroppableScrollArea($(this)) );
      });
      return scrollAreas;
    }

    /**
     * Represents an area that can be scrolled when dragging an element into it
     *
     * @param {jQuery} $el  - jQuery element or droppable
     * @constructor
     */
    function DroppableScrollArea($el) {
      this.droppable = $el,
      this.top =  $el.offset().top,
      this.left = $el.offset().left,
      this.bottom =  $el.offset().top + $el.innerHeight(),
      this.right = $el.offset().left + $el.innerWidth()
    }

    function getUrlParameter(parameter) {
      var params = global.location.search.substr(1).split('&');

      for (var i = 0; i < params.length; i++) {
          var p = params[i].split('=');
          if (p[0] == parameter) {
              return decodeURIComponent(p[1]);
          }
      }
      return null;
    }

    /**
    * Returns a copy of the global location with the given parameter removed from the query string.
    * @param {string} parameter - The parameter to remove from the query string.
    * @param {string} query - Optionally, the query string to remove the parameter from.
    * @return {string} - A copy of the global location with the given parameter removed from the query string
    */
    function removeUrlParameter(parameter, query) {
      var queryString = query || global.location.search;

      var startIndex = queryString.search("[?&]" + parameter + "=");
      if (startIndex < 0) {
        return queryString;
      }
      ++startIndex;

      var endIndex = queryString.length;
      if (queryString.indexOf("&", startIndex) > 0) {
        endIndex = queryString.indexOf("&", startIndex) + 1;
      } else {
        --startIndex;
      }

      return queryString.replace(queryString.substring(startIndex, endIndex), "");
    }

    /**
    * Formats a date and returns default ISO formatted string if browser
    * does not support Intl.DateTimeFormat Object
    * @param {string|integer} dateTime
    * @param {string} locale
    * @param {{object}} options. See https://msdn.microsoft.com/en-us/library/ie/ff743760%28v=vs.94%29.aspx for more information
    */
    function formatDateTime(dateTime, locale, options) {
      if(!moment) {
        throw 'This function requires momentjs to be loaded!';
      }

      var m = moment(dateTime);
      m.locale(locale);

      if(options.timeZone) {
        m.tz(options.timeZone);
      }
      return m.format(options.format);
    }

    /**
    * Retrieves just the message text from a page error
    * Ex. If the message is "Error: An error has occurred" it will return "An error has occurred"
    * @return {string}
    */
    function getErrorMessageText() {
      if ($('.page-messages li')[0]) {
        var messages = "";
        $('.page-messages li').each(function(){ messages += $(this).text() + "\n"; });
        return messages;
      } else {
        return $('.page-messages .messageText').text().replace($('.page-messages .messageText span').text(), '');
      }
    }

    /**
    * Removes duplicate prefix text from the provided text, splitting on a delimiter (provided optionally).
    * Example: "Deployment Name: Deployment Name: Error!" becomes "Deployment Name: Error!".
    * @param {string} text - The text to trim.
    * @param {string} delimiter - The delimiter to split the text on.
    * @return {string} - The trimmed text.
    */
    function trimDuplicateTextPrefix(text, delimiter) {
      if (delimiter === undefined) {
        delimiter = ":";
      }

      var textTokens = text.split(delimiter);
      if (textTokens.length >= 2 && textTokens[0].trim() === textTokens[1].trim()) {
        text = text.replace(textTokens[0] + delimiter, "").trim();
      }

      return text;
    }

    /**
    * Dereferences a nested property path relative to a given object.
    * Note: this does not take sObject namespace into account.
    * @see {@link getSobjValue}
    * @param {object} object - the object to which the nested property path is relative
    * @param {string} path - the property path to dereference within the given object, with levels separated by dots
    * @return {object} - the dereferenced object if the path can be resolved from the object, or undefined if it cannot
    */
    function getProperty(object, path) {
      if ((path !== null) && (path !== undefined) && (path.length > 0)) {
        var splitPath = path.split('.');

        while ((object !== null) && (object !== undefined) && (splitPath.length > 0)) {
          object = object[splitPath.shift()];
        }
      }

      return (object !== null ? object : undefined);
    }

    /**
    * Determines whether or not the given object is null or undefined.
    * @param object - An object to test against null and undefined.
    * @return - Whether or not the given object is null or undefined.
    */
    function isNullOrUndefined(object) {
      return ((object === null) || (object === undefined));
    }

    /**
    * Programmatically import CSS via javascript
    * @param {string} id - The ID of the link elem (will create if doesn't exist)
    * @param {string} href
    */
    function importCSS(id, href) {
      if (!document.getElementById(id)) {
        var head  = document.getElementsByTagName('head')[0];
        var link  = document.createElement('link');
        link.id   = id;
        link.rel  = 'stylesheet';
        link.type = 'text/css';
        link.href = href;
        link.media = 'all';
        head.appendChild(link);
      }
    }

    /**
    * Returns the version of Internet Explorer or a -1
    * (indicating the use of another browser).
    * DISCLAIMER: Feature detection is a better way to determine
    * if something is available in the browser (use that instead if you can). This is the only way
    * however to do certain things like conditionally import CSS across any version of IE
    * since conditional CSS was discontinued in IE 10+
    * @return {float} - IE version number or -1 if it is not IE
    */
    function getInternetExplorerVersion() {
      var rv = -1;

      // IE < 11 will have MSIE in useragent
      // IE 11 uses Trident
      if (navigator.appName === 'Microsoft Internet Explorer') {
        var ua = navigator.userAgent;
        var re  = new RegExp("MSIE ([0-9]{1,}[\.0-9]{0,})");
        if (re.exec(ua) != null)
          rv = parseFloat( RegExp.$1 );
      } else if (navigator.appName === 'Netscape') {
        var ua = navigator.userAgent;
        var re  = new RegExp("Trident/.*rv:([0-9]{1,}[\.0-9]{0,})");
        if (re.exec(ua) != null)
          rv = parseFloat( RegExp.$1 );
      }
      return rv;
    }

    /**
    * Appends the given CSS href to the head if the browser
    * detected is a version if Internet Explorer
    * DISCLAIMER: Uses useragent parsing
    * @param {string} id - The ID of the link elem (will create if doesn't exist)
    * @param {string} href - The href to load if IE
    */
    function addIEConditionalCSS(id, href) {
      if(getInternetExplorerVersion() < 0) {
        return;
      }
      importCSS(id, href);
    }

    /**
    * Watches any input with style class "watch-changes" and calls the
    * callback passing the changed element
    * @param {function} cb
    */
    function onWatchedInputChange(cb) {
      $('input.watch-changes').bind('input', function() {
        cb($(this));
      });
    }

    /**
    * Replaces all special characters in html (<code>"'&<>"</code>) with their html entity  &quote; .etc
    * @param {string} str The source string
    * @return {string} A replacement string or the original object if the parameter is not a string or undefined;
    */
    function htmlEscape(str) {
      var specialChars = /[\"\'&<>]/;

      if (typeof str == "string" && specialChars.test(str)) {
          return str.replace(/&/g, '&amp;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
      } else {
        return str;
      }
    }

    function htmlUnescape(str) {
      var escapedChars = /&quot;|&#39;|&amp;|&lt;&gt;/;

      if (typeof str == "string" && escapedChars.test(str)) {
        return str.replace(/&quot;/g, '"')
          .replace(/&#39;/g, '\'')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&amp;/g, '&');
      } else {
        return str;
      }
    }

    /**
     * Perfoms location navigation whether in lightning experience or in classic
     * @param {string} str The target url
     */
    function navigateTo(targetUrl) {
      if (this.inLightning()) {
        sforce.one.navigateToURL(targetUrl);
      }
      else{
        this.sfClassicRedirect(targetUrl);
      }
    }

    /**
     * Detects whether we are in lightning experience or classic
     * @return {boolean} the indication of if we are in lightning
     */
    function inLightning() {
      if( (typeof sforce != 'undefined') && (sforce.one) ) {
        return true;
      }
      return false;
    }

    /**
     * Performs a redirect in salesforce classic
     * @param {string} str The target url
     */
    function sfClassicRedirect(targetUrl) {
      window.location.href=targetUrl;
    }

    /**
     * Detects if a certain pagemessages block is populated
     * @param {string} str The dom id of the pagemessages block
     * @return {boolean} the indication of if the pagemessageblock is populated
     */
    function pageMessagesPopulated(pageMessageDomId) {
      var $elem = $('[id="'+pageMessageDomId+'"]');
      return !(isNullOrUndefined($elem) || isNullOrUndefined($elem.text()) || $elem.text() === '');
    }

    var api = {
      pure: {
        addBeforeUnloadEventListener : addBeforeUnloadEventListener,        
        getInternetExplorerVersion: getInternetExplorerVersion,
        addIEConditionalCSS: addIEConditionalCSS,
        blockUI : blockUI,
        blockUIOffCenter : blockUIOffCenter,
        buildDroppableScrollAreas : buildDroppableScrollAreas,
        clearMsgs : clearMsgs,
        confirmUnsavedChanges : confirmUnsavedChanges,
        displayModal : displayModal,
        enableSimpleAccordions : enableSimpleAccordions,
        enableShiftSelect : enableShiftSelect,
        enableTwistyPageBlockPanelSections : enableTwistyPageBlockPanelSections,
        escapeId : escapeId,
        formatDateTime: formatDateTime,
        getErrorMessageText: getErrorMessageText,
        getProperty : getProperty,
        getSObjValue : getSObjValue,
        getUrlParameter : getUrlParameter,
        removeUrlParameter : removeUrlParameter,
        handleDroppableScroll : handleDroppableScroll,
        hasSaveErrors : hasSaveErrors,
        getHasUnsavedChanges : getHasUnsavedChanges,
        setHasUnsavedChanges : setHasUnsavedChanges,
        htmlDecode : htmlDecode,
        htmlEscape : htmlEscape,
        htmlUnescape : htmlUnescape,
        isNthChildSupported : isNthChildSupported,
        performActionOnArrowKeyPress : performActionOnArrowKeyPress,
        performActionOnEnter: performActionOnEnter,
        performActionOnEscape: performActionOnEscape,
        performActionOnSelectAll: performActionOnSelectAll,
        resizeElements : resizeElements,
        showError : showError,
        stripeTable : stripeTable,
        toggleSave: toggleSave,
        toggleEditMode: toggleEditMode,
        toggleSlidingTray: toggleSlidingTray,
        unblockUI : unblockUI,
        unloadPage : unloadPage,
        windowResize : windowResize,
        trimDuplicateTextPrefix: trimDuplicateTextPrefix,
        isNullOrUndefined : isNullOrUndefined,
        reInitializeStickyOptions: reInitializeStickyOptions,
        closePageMessage: closePageMessage,
        addPageMessage: addPageMessage,
        addErrorMessage: addErrorMessage,
        addWarningMessage: addWarningMessage,
        addInfoMessage: addInfoMessage,
        addSuccessMessage: addSuccessMessage,
        eventOccursOutsideElements: eventOccursOutsideElements,
        onWatchedInputChange: onWatchedInputChange,
        navigateTo: navigateTo,
        sfClassicRedirect : sfClassicRedirect,
        inLightning : inLightning,
        pageMessagesPopulated : pageMessagesPopulated,
        animateScrollToElement: animateScrollToElement,
        MESSAGE_TYPE: MESSAGE_TYPE,
        SFDC_CONTAINER_HEIGHT: SFDC_CONTAINER_HEIGHT,
        KEYSTRING_ARROWUP: KEYSTRING_ARROWUP,
        KEYSTRING_ARROWRIGHT: KEYCODE_ARROWRIGHT,
        KEYSTRING_ARROWDOWN: KEYSTRING_ARROWDOWN,
        KEYSTRING_ARROWLEFT: KEYSTRING_ARROWLEFT,
        JOB_TYPE : JOB_TYPE,
        PERMISSION_LEVEL : PERMISSION_LEVEL
      },
      testOnly: {
        KEYCODE_ENTER : KEYCODE_ENTER,
        KEYCODE_ESCAPE : KEYCODE_ESCAPE,
        KEYCODE_ARROWUP : KEYCODE_ARROWUP,
        KEYCODE_ARROWRIGHT : KEYCODE_ARROWRIGHT,
        KEYCODE_ARROWDOWN : KEYCODE_ARROWDOWN,
        KEYCODE_ARROWLEFT : KEYCODE_ARROWLEFT,
        KEYCODE_A : KEYCODE_A
      }
    };

    if (ApiBuilder !== undefined) {
      // TODO: We need to remove this define module name after
      // we have everything running on AMD and no scripts are loaded inline
      return new ApiBuilder(api).getApi();
    } else {
      return $.extend(api.pure, api.testOnly);
    }
  }; // End init()

  if(typeof define !== 'undefined') {
    // TODO: We need to remove this define module name after
    // we have everything running on AMD and no scripts are loaded inline
    define(
      [
        'jquery',
        'jquery-ui',
        'jquery-blockUI',
        'moment',
        'external/moment/moment-timezone',
        'api_builder'
      ], function() {

      var jQuery = arguments[0];
      var moment = arguments[3];
      var ApiBuilder = arguments[5];

      var API = init(jQuery, moment, ApiBuilder);
      // TODO: Remove this when everything is compatible with AMD
      global.BW = global.BW || {};
      global.BW.AlmCommon = API;
      return global.BW.AlmCommon;
    });
  } else {
    global.BW = global.BW || {};
    global.BW.AlmCommon = init(global.jQuery, global.moment, global.BW.ApiBuilder);
  }
})(this);
