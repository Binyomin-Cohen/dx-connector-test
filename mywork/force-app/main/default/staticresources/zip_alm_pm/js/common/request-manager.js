/**
* Serialize function execution by invoking it through this request manager. Intended for Visualforce action functions, 
* this request manager will take a function definition, an array of arguments, and a variety of other options, and queue 
* the context up along with any other functions invoked through the manager. Currently, the manager does not handle 
* timeouts.
*/

(function() {
  'use strict';

  var init = function ($, AlmCommon, ApiBuilder) {
    // Queues execution objects representing functions to invoke.
    var executionQueue = [];
    // The current execution object.
    var currentExecution = null;

    // A container for various reference counters.
    var counters = {
      // A reference counter for shown objects, allowing objects to be hidden only when no pending requests require them.
      shownObjects : {},
      // A reference counter for hidden objects, allowing objects to be shown only when no pending requests require them.
      hiddenObjects : {},
      // A reference counter for added classes, allowing classes to be removed only when no pending requests require them.
      addedClasses : {},
      // A reference counter for removed classes, allowing classes to be added only when no pending requests require them.
      removedClasses : {}
    };

    /**
    * Serialize function calls through an execution queue.
    * @param func - The function definition to be invoked.
    * @param args - The array of arguments to invoke the function with.
    * @param opts - Options associated with the function call.
    *        opts.autoComplete - Whether or not the execution should automatically yield to the queue upon completion.
    *        opts.debounce - Prevent a function call from immediately following another call to the same function.
    *        opts.callback - Another function to be executed as the execution completes.
    *        opts.objectsToShow - Any objects that should be shown during the span of function execution.
    *        opts.objectsToHide - Any objects that should be hidden during the span of function execution.
    *        opts.classesToAdd - An object containing selector-class pairings to be added during the span of function execution.
    *        opts.classesToRemove - An object containing selector-class pairings to be removed during the span of function execution.
    */
    function invokeFunction(func, args, opts) {
      // If no function was given, return.
      if (func === undefined || func === null) {
        return;
      }

      // Create array out of arguments, if they are not already in an array.
      args = [].concat(args);

      // Create the new execution object.
      var newExecution = {
        func : func,
        args : args,
        opts : opts
      }

      // If there is no current execution and there are no executions already queued, execute the new function immediately.
      if (executionQueue.length === 0 && currentExecution === null) {
        addReferences(newExecution);
        currentExecution = newExecution;
        execute();
      } else {
        // Prevent function spam, if necessary.
        var lastRequest = executionQueue[executionQueue.length - 1] || currentExecution;
        var lastFunc = AlmCommon.getProperty(lastRequest, 'func');
        if ((AlmCommon.getProperty(newExecution, 'opts.debounce') === true) && (newExecution.func === lastFunc)) {
          return;
        }

        // Queue the new execution.
        addReferences(newExecution);
        executionQueue.push(newExecution);
      }
    }

    /**
    * Invoke the function occupying the current context.
    */
    function execute() {
      // If there are objects to show during the function execution, show the objects.
      showObjects(AlmCommon.getProperty(currentExecution, 'opts.objectsToShow'));

      // If there are objects to hide during the function execution, hide the objects.
      hideObjects(AlmCommon.getProperty(currentExecution, 'opts.objectsToHide'));

      // If there are classes to add during the function execution, add the classes.
      addClasses(AlmCommon.getProperty(currentExecution, 'opts.classesToAdd'));

      // If there are classes to remove during the function execution, remove the classes.
      removeClasses(AlmCommon.getProperty(currentExecution, 'opts.classesToRemove'));

      // Execute the function with its arguments.
      currentExecution.func.apply(this, currentExecution.args);

      // Yield to the queue automatically, if required.
      if ((AlmCommon.getProperty(currentExecution, 'opts.autoComplete') === true)) {
        completeFunction();
      }
    }

    /**
    * Complete the current function invocation and execute the next context in the queue, if one exists.
    */
    function completeFunction() {
      if (currentExecution !== null) {
        removeReferences(currentExecution);

        // Perform any callback attached to the current function.
        if (AlmCommon.getProperty(currentExecution, 'opts.callback')) {
          currentExecution.opts.callback();
        }

        // Clear the current execution context.
        currentExecution = null;
      }

      // If any contexts exist in the queue, execute the next one.
      if (executionQueue.length !== 0) {
        currentExecution = executionQueue.shift();
        execute();
      }
    }

    /**
    * Increments reference counters from a given function execution.
    * @param execution - The new function execution.
    */
    function addReferences(execution) {
      // If there are objects to show, add them to the reference counter.
      incrementReferences(AlmCommon.getProperty(execution, 'opts.objectsToShow'), counters.shownObjects);

      // If there are objects to hide, add them to the reference counter.
      incrementReferences(AlmCommon.getProperty(execution, 'opts.objectsToHide'), counters.hiddenObjects);

      // If there are classes to add, add them to the reference counter.
      incrementReferences(AlmCommon.getProperty(execution, 'opts.classesToAdd'), counters.addedClasses);

      // If there are classes to remove, add them to the reference counter.
      incrementReferences(AlmCommon.getProperty(execution, 'opts.classesToRemove'), counters.removedClasses);
    }

    /**
    * Decrements reference counters from a given function execution.
    */
    function removeReferences(execution) {
      // If there are objects shown, subtract them from the reference counter.
      if (AlmCommon.getProperty(execution, 'opts.objectsToShow')) {
        var unusedShownObjects = decrementReferences(execution.opts.objectsToShow, counters.shownObjects);

        // Hide any shown objects that are no longer required to be shown.
        if (unusedShownObjects.length !== 0) {
          hideObjects(unusedShownObjects);
        }
      }

      // If there are objects hidden, subtract them from the reference counter.
      if (AlmCommon.getProperty(execution, 'opts.objectsToHide')) {
        var unusedHiddenObjects = decrementReferences(execution.opts.objectsToHide, counters.hiddenObjects);

        // Show any hidden objects that are no longer required to be hidden.
        if (unusedHiddenObjects.length !== 0) {
          showObjects(unusedHiddenObjects);
        }
      }

      // If there are classes added, subtract them from the reference counter.
      if (AlmCommon.getProperty(execution, 'opts.classesToAdd')) {
        var unusedAddedClasses = decrementReferences(execution.opts.classesToAdd, counters.addedClasses);

        // Remove any added classes that are no longer required to be added.
        if (unusedAddedClasses.length !== 0) {
          removeClasses(unusedAddedClasses);
        }
      }

      // If there are classes removed, subtract them from the reference counter.
      if (AlmCommon.getProperty(execution, 'opts.classesToRemove')) {
        var unusedRemovedClasses = decrementReferences(execution.opts.classesToRemove, counters.removedClasses);

        // Add any removed classes that are no longer required to be removed.
        if (unusedRemovedClasses.length !== 0) {
          addClasses(unusedRemovedClasses);
        }
      }
    }

    /**
    * Increments the reference counts in the given counter, pulling references from the given source.
    * @param source - The source to pull references from.
    * @param counter - The counter storing the relevant reference counts.
    */
    function incrementReferences(source, counter) {
      if (!AlmCommon.isNullOrUndefined(source) && !AlmCommon.isNullOrUndefined(counter)) {
        if (Array.isArray(source)) {
          $.each(source, function(index, object) {
            counter[object] = (counter[object] || 0) + 1;
          });
        } else {
          $.each(source, function(outerIndex, objects) {
            if (AlmCommon.isNullOrUndefined(counter[outerIndex])) {
              counter[outerIndex] = {};
            }
            $.each(objects, function(innerIndex, object) {
              counter[outerIndex][object] = (counter[outerIndex][object] || 0) + 1;
            });
          });
        }
      }
    }

    /**
    * Decrements the reference counts in the given counter, pulling references from the given source.
    * @param source - The source to pull references from.
    * @param counter - The counter storing the relevant reference counts.
    * @return - A collection (either an array or an object) of unused references.
    */
    function decrementReferences(source, counter) {
      var unusedReferences = [];

      if (!AlmCommon.isNullOrUndefined(source) && !AlmCommon.isNullOrUndefined(counter)) {
        if (Array.isArray(source)) {
          $.each(source, function(index, object) {
            if (decrementReference(counter, object) === 0) {
              unusedReferences.push(object);
            }
          });
        } else {
          unusedReferences = {};
          $.each(source, function(outerIndex, objects) {
            $.each(objects, function(innerIndex, object) {
              if (!AlmCommon.isNullOrUndefined(counter[outerIndex])) {
                if (AlmCommon.isNullOrUndefined(unusedReferences[outerIndex])) {
                  unusedReferences[outerIndex] = [];
                }
                if (decrementReference(counter[outerIndex], object) === 0) {
                  unusedReferences[outerIndex].push(object);
                }
              }
            });
          });
        }
      }

      return unusedReferences;
    }

    /**
    * Decrements a single reference count in the given counter for the given object.
    * @param counter - The counter storing the relevant reference counts.
    * @param object - The object to decrement a reference to.
    * @return - The updated reference count of the given object.
    */
    function decrementReference(counter, object) {
      var count = counter[object];

      if (!AlmCommon.isNullOrUndefined(count)) {
        if (count <= 0) {
          delete counter[object];
          return null;
        }

        var newCount = count - 1;
        counter[object] = newCount;

        if (newCount == 0) {
          delete counter[object];
          return 0;
        }

        return count;
      }

      return null;
    }

    /**
    * Show a set of objects (spinners, etc.).
    * @param objects - A set of objects to be displayed.
    */
    function showObjects(objects) {
      if (!AlmCommon.isNullOrUndefined(objects)) {
        $.each(objects, function(index, object) {
          $(object).css('display', 'inline-block');
        });
      }
    }

    /**
    * Hide a set of objects (spinners, etc.).
    * @param objects - A set of objects to be hidden.
    */
    function hideObjects(objects) {
      if (!AlmCommon.isNullOrUndefined(objects)) {
        $.each(objects, function(index, object) {
          $(object).hide();
        });
      }
    }

    /**
    * Add classes to their respective selectors.
    * @param pairs - A map keyed by selector, with an array of classes as values.
    */
    function addClasses(pairs) {
      if (!AlmCommon.isNullOrUndefined(pairs)) {
        $.each(pairs, function(selector, classes) {
          $.each(classes, function(index, classToAdd) {
            $(selector).addClass(classToAdd);
          });
        });
      }
    }

    /**
    * Remove classes from their respective selectors.
    * @param pairs - A map keyed by selector, with an array of classes as values.
    */
    function removeClasses(pairs) {
      if (!AlmCommon.isNullOrUndefined(pairs)) {
        $.each(pairs, function(selector, classes) {
          $.each(classes, function(index, classToRemove) {
            $(selector).removeClass(classToRemove);
          });
        });
      }
    }

    /**
    * Clear the execution queue and any currently-executing contexts.
    */
    function flushState() {
      currentExecution = null;

      executionQueue.length = 0;

      counters.shownObjects = {};
      counters.hiddenObjects = {};
      counters.addedClasses = {};
      counters.removedClasses = {};
    }

    /**
    * Set the current execution context to the given one.
    */
    function setCurrentExecution(execution) {
      currentExecution = execution;
    }

    /**
    * Returns the current execution context.
    */
    function getCurrentExecution() {
      return currentExecution;
    }

    /**
    * Returns the execution queue.
    */
    function getExecutionQueue() {
      return executionQueue;
    }

    /**
    * Return the module API.
    */
    return new ApiBuilder({
      pure: {
        invokeFunction : invokeFunction,
        completeFunction : completeFunction,
      },
      testOnly: {
        setCurrentExecution : setCurrentExecution,
        getCurrentExecution : getCurrentExecution,
        getExecutionQueue : getExecutionQueue,
        execute : execute,
        incrementReferences : incrementReferences,
        decrementReferences : decrementReferences,
        flushState : flushState
      }
    }).getApi();
  };

  /**
  * Dependency and module initialization boilerplate.
  */
  define([
    'jquery',
    'js_alm_common',
    'api_builder'
  ], function() {
    var jQuery = arguments[0];
    var AlmCommon = arguments[1];
    var ApiBuilder = arguments[2];

    var API = init(jQuery, AlmCommon, ApiBuilder);
    window.BW = window.BW || {};
    window.BW.requestManager = API;

    return API;
  });
})();