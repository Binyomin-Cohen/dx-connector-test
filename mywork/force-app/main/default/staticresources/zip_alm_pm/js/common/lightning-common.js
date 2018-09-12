(function(global) {
  var init = function(ApiBuilder) {

    var MAX_COMPONENT_RECORD_COUNT_THRESHOLD = 1000;

    function addPageMessage(type, message, urlValue, urlTitle, urlLabel, urlAdditionalText) {
      var pageMessageAddEvent = getEvent('pageMessageAdd');
      if (pageMessageAddEvent) {
        pageMessageAddEvent.setParams({
          'type' : type,
          'message' : message,
          'urlValue' : urlValue,
          'urlTitle' : urlTitle,
          'urlLabel' : urlLabel,
          'urlAdditionalText' : urlAdditionalText
        });
        pageMessageAddEvent.fire();
      }
    }

    function getPaginationRecordCountMessage(totalRecordCount, currentPageRecordCount,
                                             currentPageNumber, pageSize, numFormatFn){
      if (!numFormatFn) {numFormatFn = function(x) {return x;};}
      totalRecordCount = totalRecordCount || 0;
      currentPageRecordCount = currentPageRecordCount || 0;
      currentPageNumber = currentPageNumber || 0;
      pageSize = pageSize || 0;
      var pageStartingIndex = totalRecordCount > 0 ? (currentPageNumber-1)*pageSize + 1 : 0;
      var pageEndingIndex = totalRecordCount > 0 ? pageStartingIndex + (currentPageRecordCount - 1) : 0;

      return numFormatFn(pageStartingIndex) + '-' + numFormatFn(pageEndingIndex)
        + ' of ' +  (totalRecordCount > MAX_COMPONENT_RECORD_COUNT_THRESHOLD ?
                     'many' : numFormatFn(totalRecordCount));
    }

    function getPageFromList(totalList, pageNumber, pageSize){
      if (!totalList || totalList.length < 1){
        return [];
      }
      if (pageNumber < 1) pageNumber = 1;
      var startingIndex = (pageNumber-1)*pageSize;
      var endingIndex = startingIndex + pageSize;
      return totalList.slice(startingIndex, endingIndex);
    }

    function compareByLastModifiedDate(comp1, comp2) {
      if (comp1.lastModifiedDate === null || comp1.lastModifiedDate === undefined) {
        return 1;
      } else if (comp2.lastModifiedDate === null || comp2.lastModifiedDate === undefined) {
        return -1;
      } else if (comp1.lastModifiedDate === comp2.lastModifiedDate) {
        return 0;
      } else {
        return (new Date(comp1.lastModifiedDate) > new Date(comp2.lastModifiedDate)) ? -1 : 1;
      }
    }

    /**
     * Log an event to google analytics
     * @param category {String}
     * @param action  {String}
     * @param label   {String} an optional label describing the event
     * @param value   {Number} an optional integer value
    */
    function fireGoogleAnalyticsTrackingEvent(category, action, label, value) {
      var trackingEvent = getEvent('GoogleAnalyticsTrackingEvent');
      if (trackingEvent) {
        trackingEvent.setParams({
          'category' : category,
          'action' : action,
          'label' : label,
          'value' : value
        });
        trackingEvent.fire();
      }
    }


    /**
     * orderedList       list to insert into. Must be pre-sorted
     * elementsToInsert  elements to insert into orderedList. Pre-sort not required
     * compareFn         function used to compare members of orderedList with elementsToInsert
     */
    function insertElementsIntoOrderedList(orderedList, elementsToInsert, compareFn, cb) {
      var elementsToInsertCopy = elementsToInsert.slice();
      elementsToInsertCopy.sort(compareFn);

      // While there are still elements to insert, iter through orderedList from right to left
      // and insert as many of the elementsToInsert as possible (again, starting with rightmost and working left.)
      for(var i = orderedList.length-1; (i>=0 && elementsToInsertCopy.length > 0); i--) {
        for(var j = elementsToInsertCopy.length-1; j>=0; j--) {
          // check whether elementsToInsertCopy[j] should be positioned to the right orderedList[i]
          if (compareFn(elementsToInsertCopy[j], orderedList[i]) >= 0) {
            // insert to the right and remove from elementsToInsert
            orderedList.splice(i + 1, 0, elementsToInsertCopy[j]);
            elementsToInsertCopy.pop();
          } else {
            break;
          }
        }
      };

      // If there are elements left over, they need to be inserted in front of orderedList
      if (elementsToInsertCopy.length > 0) {
        Array.prototype.unshift.apply(orderedList, elementsToInsertCopy);
      }

      return orderedList;
    }

    /**
    * options
    * options.successCb   callback to execute on success
    * options.errorCb   callback to execute on failure
    * options.cb          callback to execute unconditionally
    */
    function auraCallbackHandler(data, options) {
      var state = data.getState();
      options = options || {};

      if (options.cb && typeof options.cb === 'function') {
        options.cb();
      }

      if (state === "SUCCESS") {
        if (options.successCb && typeof options.successCb === 'function') {
          options.successCb();
        }
      } else if (state === "ERROR") {
        var errors = data.getError();
        if (errors) {
          if (errors[0] && errors[0].message) {
            if (options.errorCb && typeof options.errorCb === 'function') {
              options.errorCb(errors[0].message);
            } else {
              throw new Error("Error message: " + errors[0].message);
            }
          }
        } else {
          throw new Error("Unknown error");
        }
      }
    }

    function isListOfStrings(lst){
      // expected homogeneous list of elements
      return lst && lst.length > 0 && typeof lst[0] === 'string';
    }

    function convertStringsToSelectOptions(options) {
      if (isListOfStrings(options)){
        var formattedOptions = [];
        for (var index = 0; index < options.length; index++){
          formattedOptions.push({value:options[index], label: options[index]});
        }
        return formattedOptions;
      }
      return options || [];
    }

    function getEvent(eventName) {
      if (typeof $A === 'undefined') {
        return;
      }

      var lightningEvent = $A.get('e.alm_pm2:' + eventName) || $A.get('e.c:' + eventName);
      return lightningEvent;
    }

    function getSelectOptionValues(options) {
      var values = [];
      if (options && options.length > 0 && typeof options[0] === 'object' && 'value' in options[0]){
        for (var index = 0; index < options.length; index++){
          values.push(options[index].value);
        }
      }
      return values;
    }

    /**
     * Builds a namespace friendly url
     * @param {string} targetUrl The target url
     * @param {string} namespace The namespace that will be appended
     */
    function buildNamespaceFriendlyUrl(targetUrl, namespace) {
      if(namespace) {
        if (namespace.indexOf('__') === -1) {
          namespace += '__';
        }
        
        if (targetUrl && targetUrl.indexOf(namespace) === -1) {
          targetUrl = targetUrl.replace("/apex/", "/apex/" + namespace);
        }
      }
      return targetUrl;
    }

    return new ApiBuilder({
      pure: {
        addPageMessage : addPageMessage,
        auraCallbackHandler: auraCallbackHandler,
        buildNamespaceFriendlyUrl : buildNamespaceFriendlyUrl,
        compareByLastModifiedDate : compareByLastModifiedDate,
        convertStringsToSelectOptions : convertStringsToSelectOptions,
        fireGoogleAnalyticsTrackingEvent : fireGoogleAnalyticsTrackingEvent,
        getPageFromList : getPageFromList,
        getSelectOptionValues : getSelectOptionValues,
        getPaginationRecordCountMessage : getPaginationRecordCountMessage,
        isListOfStrings : isListOfStrings,
        insertElementsIntoOrderedList : insertElementsIntoOrderedList,
        MAX_COMPONENT_RECORD_COUNT_THRESHOLD : MAX_COMPONENT_RECORD_COUNT_THRESHOLD
      },
      testOnly: {
      }
    }).getApi();
  };

  if (typeof define === "function") {
    define([
      'api_builder'
    ], function(ApiBuilder) {
      var API = init(ApiBuilder);
      return API;
    });
  } else {
    global.BW = global.BW || {};
    var API = init(global.BW.ApiBuilder);
    global.BW.LTCommon = API;
    return API;
  }
})(this);
