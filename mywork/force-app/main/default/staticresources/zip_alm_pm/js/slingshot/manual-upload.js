(function() {

  var init = function($, AlmCommon, LoadDeployment, ApiBuilder, Analytics) {

    function setupFileHandlers() {

      var $fileDragArea = $('.upload-drag-helper');

      $fileDragArea.on('dragover', fileDragHover);
      $fileDragArea.on('dragleave', fileDragHover);
      $fileDragArea.on('drop', fileDropHandler);
      $('.upload-btn').on('drop', fileDropHandler);

      $('#alm-container')
       .on('drop', '#manual-upload-form .file-input', fileDropHandler)
       .on('change', '#manual-upload-form .file-input', function(){
         var fileField = $('.file-input').get(0);
         startFileUpload(fileField.files[0]);
       });
    }

    /**
    * Resets the file input after an unsuccessful upload
    * This is to preserve "onchange" listeners if user tries
    * to upload the same file multiple times
    */
    function resetManualPackageInput() {
      var $input = $('#manual-upload-form .file-input');
      $input.replaceWith($input.clone());
    }

    function showUploadError(msg) {
      AlmCommon.showError(msg, {messagePanel: '#manual-upload-errors'});
      resetManualPackageInput();
    }

    function fileDragHover(evt) {
      evt.preventDefault();
      evt.stopPropagation();
      if (evt.type == "dragover") {
        $('.upload-drag-helper').addClass("drag-hover");
      } else {
        $('.upload-drag-helper').removeClass("drag-hover");
      }
    }

    function fileDropHandler(evt) {
      //TODO: investigate drop on input button
      var files = evt.originalEvent.target.files || evt.originalEvent.dataTransfer.files;
      fileDragHover(evt);
      startFileUpload(files[0]);
    }

    function toggleManualPackageDetails(fileName) {
      var $manualPackageDetails = $('.manual-upload-details');
      $('.manual-file-name').text(fileName);

      if(!fileName) {
        // Hide the details and show the drag helper
        $('.upload-drag-helper').show();
        $manualPackageDetails.find('.barber-loader').hide();
        $manualPackageDetails.hide();
      } else {
        $('.upload-drag-helper').hide();
        $manualPackageDetails.find('.barber-loader').show();
        $manualPackageDetails.show();
      }
    }

    function uploadCallback(err, deployment, file, reader) {
        if(err) {
          showUploadError(err);
          toggleManualUploadForm();
          return;
        }

        var fileName = file.name;

        var att = new sforce.SObject("Attachment");
        var buildId = AlmCommon.getSObjValue(deployment, 'Build__c');
        att.Name = fileName;
        att.ContentType = file.type;
        att.ParentId = buildId;
        if (reader.readAsBinaryString) {
          att.Body = (new sforce.Base64Binary(reader.result)).toString();
        } else {
          att.Body = arrayBufferToBase64(reader.result);
        }

        sforce.connection.create([att], {
            onSuccess : function(result, source) {
                if (result[0].getBoolean("success")) {

                  // Set package URL
                  var attachmentId = result[0].id;
                  var releaseId = AlmCommon.getSObjValue(deployment, 'Release__c');
                  remoteUpdatePackageURL(buildId, attachmentId, function(err) {
                    if(err) {
                      AlmCommon.showError(err);
                      toggleManualUploadForm('show');
                      return;
                    }

                    toggleManualUploadForm();
                    AlmCommon.blockUI('#load-deployment-pane');
                    resetManualPackageInput();
                    LoadDeployment.loadDeploymentsForRelease(releaseId);
                    parseManualPackage(buildId);
                  });
                }
                else {
                  handleUpdatePackageUrlFailure(buildId, result[0]);
                }
            },
            onFailure : function(error, source) {
              handleUpdatePackageUrlFailure(buildId, error);
            }
        });

    }

    function startFileUpload(file) {
      var fileName = file.name,
        releaseId = $('input[id$=release-id]').val(),
        MAX_FILE_SIZE = 1024 * 1024 * 25; //25Mb

      AlmCommon.clearMsgs();
      if (fileName.substr(fileName.lastIndexOf('.')).toLowerCase() !== '.zip') {
        showUploadError('Package files must end in .zip');
        return;
      } else if (file.size && file.size > MAX_FILE_SIZE) {
        showUploadError('Maximum file size is 25Mb');
        return;
      }

      toggleManualPackageDetails(fileName);

      var reader = new FileReader();

      reader.onloadend = function () {
        var params = {
          deployName: fileName,
          sourceId: null,
          targetId: null,
          isManual: true
        };

        attachFileToBuild(params, file, reader);
      }

      reader.onerror = function(event) {
        AlmCommon.clearMsgs();
        showUploadError("Error reading file! Code " + event.target.error.code);
      };

      Analytics.trackEvent('Slingshot', 'Upload Build Package');
      if (reader.readAsBinaryString) {
        reader.readAsBinaryString(file);
      } else {
        reader.readAsArrayBuffer(file);
      }

    }

    function attachFileToBuild(params, file, reader) {
      var savedDeploymentId = $('#manual-upload-form').attr('savedDeploymentId');
      if(savedDeploymentId) {
        remoteCreateNewBuild(savedDeploymentId, function(err, deployment) {
          uploadCallback(err, deployment, file, reader);
        });
      } else {
        remoteCreateDeployment(params, function(err, deployment) {
          uploadCallback(err, deployment, file, reader);
        });
      }
    }

    function parseManualPackage(buildId) {
      remoteParseManualBuildPackage(buildId, function(err, res) {
      });
    }

    function handleUpdatePackageUrlFailure(buildId, errorReason) {
      remoteHandleUpdatePackageUrlFailure(buildId, function(){
        toggleManualUploadForm('show');
        showUploadError('The zip file could not be uploaded. ' + errorReason);
        return;
      });
    }
    /**
     * convert an array buffer to a base64 encoded string
     */
    function arrayBufferToBase64( buffer ) {

      var bufferConvertedToString = String.fromCharCode.apply(null, new Uint8Array(buffer));

      return window.btoa( bufferConvertedToString );
    }

    /**
    * Toggles the manual upload form based on whether it's
    * currently visible or not. Can be overridden by passing
    * an override of 'show' or 'hide'
    * @param {string} stateOverride
    */
    function toggleManualUploadForm(stateOverride, savedDeploymentId) {
      var $deployList = $('#saved-deployment-list');
      if(stateOverride !== 'show' &&
        ($deployList.hasClass('visibility-hidden') || stateOverride === 'hide'))
      {
        $deployList.removeClass('visibility-hidden');
        $('#manual-upload-form').hide();
        // Hide details
        toggleManualPackageDetails();
      } else {
        $deployList.addClass('visibility-hidden');

        $('#manual-upload-errors').hide();
        var $manualUploadForm = $('#manual-upload-form');
        $manualUploadForm.show();

        AlmCommon.animateScrollToElement($manualUploadForm);
        toggleManualPackageDetails();
      }
      if (savedDeploymentId) {
        $('#manual-upload-form').attr("savedDeploymentId", savedDeploymentId);
      } else {
        $('#manual-upload-form').removeAttr("savedDeploymentId");
      }
      
    }

    return new ApiBuilder({
        pure: {
          toggleManualUploadForm: toggleManualUploadForm,
          setupFileHandlers: setupFileHandlers,
          handleUpdatePackageUrlFailure: handleUpdatePackageUrlFailure
        },
        testOnly: {
          arrayBufferToBase64: arrayBufferToBase64,
          attachFileToBuild: attachFileToBuild
        }
      }).getApi();

  };

  define(['jquery', 'js_alm_common', 'slingshot/load-deployment', 'api_builder', 'try!analytics'], function() {
    var jQuery = arguments[0];
    var AlmCommon = arguments[1];
    var LoadDeployment = arguments[2];
    var ApiBuilder = arguments[3];
    var Analytics = arguments[4];
    return init(jQuery, AlmCommon, LoadDeployment, ApiBuilder, Analytics);
  });

})();