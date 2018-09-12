/**
* The sfQuery plugin is free to use and distribute. See https://github.com/sfQuery for more details.
* Commit hash: c80ce7e2d5ea6a80beaf253bfb19ff0af36d1688
**/
"use strict";function sfQuery(e){return jQuery.SFQuery.getVfElem(e)}function ApexScriptUtils(){this.autoCompleteState=null;this.acCursorStartPos=-1;this.acCharCode=null;this.acQueryString=null;this.acInCombination=false;this.acInQueryString=false;this.keyComboStartWindow=null}(function(e,t){e.fn.getCursorPosition=function(){var t=e(this).get(0);var n=0;if("selectionStart"in t){n=t.selectionStart}else if("selection"in document){t.focus();var r=document.selection.createRange();var i=document.selection.createRange().text.length;r.moveStart("character",-t.value.length);n=r.text.length-i}return n}})(jQuery);sfQuery.setSessionId=function(e){ApexScriptUtils.sessionId=e;if(typeof sforce!=="undefined"){sforce.connection.sessionId=e}};ApexScriptUtils.instance=null;ApexScriptUtils.vfRemoteCallbacks=null;ApexScriptUtils.defaultRemoteTimeout=30;ApexScriptUtils.timeoutVar=null;ApexScriptUtils.sessionId=null;ApexScriptUtils.REST_URLS={Versions:"/services/data/",MetaData:"/services/data/v20.0/sobjects/",Describe:"/services/data/v20.0/sobjects/{o}/describe/",ObjectDetail:"/services/data/v20.0/sobjects/{o}/{ID}"};if(jQuery.SFQuery){throw"SFQuery already defined!"}jQuery.SFQuery={};ApexScriptUtils.getInstance=function(){if(ApexScriptUtils.instance===null){ApexScriptUtils.instance=new ApexScriptUtils}return ApexScriptUtils.instance};ApexScriptUtils.alertDevFn=function(){alert("This remoting call is taking longer than expected.\n\n"+"If you are a developer seeing this, please check the browser Javascript console for errors.\n"+"If you are a user seeing this, please contact your Salesforce administrator.")};ApexScriptUtils.getObjectInfo=function(e){var t=ApexScriptUtils.getSimpleType(e);var n={type:t};if(t=="array"){n.length=e.length}else if(t=="object"){var r=[];for(var i in e){r.push(i)}n.fields=r}return n};ApexScriptUtils.typeOf=Function.prototype.call.bind(Object.prototype.toString);ApexScriptUtils.getSimpleType=function(e){return ApexScriptUtils.typeOf(e).replace("[object ","").replace("]","").toLowerCase()};var AUPT=ApexScriptUtils.prototype;AUPT.doVfRemoteCall=function(e,t,n,r){var i=e+"."+t;ApexScriptUtils.vfRemoteCallbacks=r;ApexScriptUtils.timeoutVar=setTimeout(ApexScriptUtils.alertDevFn,ApexScriptUtils.defaultRemoteTimeout/2*1e3);var s=[];s.push(i);if(ApexScriptUtils.getSimpleType(n)==="array"){s=s.concat(n)}else{s.push(n)}s.push(AUPT.handleRemoteCallback.bind(this));Visualforce.remoting.Manager.invokeAction.apply(Visualforce.remoting.Manager,s)};AUPT.handleRemoteCallback=function(e,t){clearTimeout(ApexScriptUtils.timeoutVar);if(t.status===true){var n=ApexScriptUtils.getObjectInfo(e);ApexScriptUtils.vfRemoteCallbacks.success(e,n)}else{ApexScriptUtils.vfRemoteCallbacks.error(t)}};ApexScriptUtils.getRemotingExtend=function(){return jQuery.extend({controller:null,methodName:null,params:null,timeout:ApexScriptUtils.defaultRemoteTimeout,success:function(e,t){alert("Default success handler invoked. Check console for more info.");console.log(e);console.log(t)},error:function(e){alert("Default error handler invoked. Check console for more info.");console.log(e)}},arguments[0]||{})};jQuery.fn.vfRemote=function(){var e=ApexScriptUtils.getRemotingExtend(arguments[0]);return this.each(function(){jQuery(this).click(function(){ApexScriptUtils.getInstance().doVfRemoteCall(e.controller,e.methodName,e.params,{success:e.success,error:e.error})})})};jQuery.SFQuery.vfRemote=function(){var e=ApexScriptUtils.getRemotingExtend(arguments[0]);ApexScriptUtils.getInstance().doVfRemoteCall(e.controller,e.methodName,e.params,{success:e.success,error:e.error})};ApexScriptUtils.getQueryExtend=function(){return jQuery.extend({query:null,before:function(){return false},finished:function(){return false},success:function(e,t){alert("Default success handler invoked. Check console for more info.");console.log(e)},error:function(e,t){alert("Default error handler invoked. Check console for more info.");console.log("Query Error: "+e)}},arguments[0]||{})};AUPT.query=function(){var e=ApexScriptUtils.getQueryExtend(arguments[0]);var t={success:e.success,error:e.error,finished:e.finished};e.before();sforce.connection.query(e.query,{onSuccess:AUPT.handleQueryResult.bind(this),onFailure:AUPT.handleQueryResult.bind(this),source:t})};AUPT.handleQueryResult=function(e,t){if(ApexScriptUtils.getSimpleType(e)=="object"&&typeof e.faultstring==="undefined"){if(e.done=="true"){t.success(this.cleanQueryResult(e.getArray("records")))}else{var n=e.getArray("records");var r=false;while(!r){var i=sforce.connection.queryMore(e.queryLocator);r=i.done;var s=i.getArray("records");for(var o=0;o<s.length;o++){n.push(s[o])}}t.success(this.cleanQueryResult(n))}}else if(typeof e.faultstring!=="undefined"){t.error(e.faultstring)}else{t.error(e)}t.finished()};AUPT.cleanQueryResult=function(e){var t=[];var n=[];for(var r=0;r<e.length;r++){var i=e[r];var s={};for(var o in i){var u=ApexScriptUtils.getSimpleType(i[o]);if(u!="function"&&o!=="type"){if(u!="object"){s[o]=i[o]}else{var a={};a[o]=this.parseRelatedObject(i[o]);n.push(a);var f={};this.parseObjectsForTable(a,null,f);for(var l in f){s[l]=f[l]}}}}t.push(s)}return t};AUPT.parseRelatedObject=function(e){var t={};for(var n in e){var r=ApexScriptUtils.getSimpleType(e[n]);if(n!="Id"&&n!="type"&&r!="function"){if(r!="object"){t[n]=e[n]}else{t[n]=this.parseRelatedObject(e[n])}}}return t};AUPT.parseObjectsForTable=function(e,t,n){t=typeof t!=="undefined"?t:null;for(var r in e){var i=ApexScriptUtils.getSimpleType(e[r]);var s=t!=null?t+"."+r:r;if(i!="object"){n[s]=e[r]}else{this.parseObjectsForTable(e[r],s,n)}}};jQuery.SFQuery.soqlQuery=function(){ApexScriptUtils.getInstance().query(arguments[0])};jQuery.fn.soqlQuery=function(){var e=arguments[0];return this.each(function(){jQuery(this).click(function(){ApexScriptUtils.getInstance().query(e)})})};ApexScriptUtils.jqEsc=function(e){if(!e){return""}if(e.substr(0,4)==="j_id"){return'[id="'+e+'"]'}return e};AUPT.jQuery=function(e){var t=ApexScriptUtils.getSimpleType(e);switch(t){case"string":return jQuery(ApexScriptUtils.jqEsc(e));default:return jQuery(e)}};jQuery.SFQuery.getVfElem=function(e){return ApexScriptUtils.getInstance().jQuery(e)};AUPT.doSearchForAutoComplete=function(e){if(e.obj.val()==""){this.hideAutoCompleteWindow();return}var t=ApexScriptUtils.getAutoCompleteExtend(e.args);var n={elem:e.obj,onRowClick:t.onRowClick,focusField:t.focusField,inputFieldVal:t.inputFieldVal,replace:t.replace,exclude:t.exclude};this.autoCompleteState=n;this.showAutoCompleteLoad();if(t.controller!=null&&t.methodName!=null){jQuery.SFQuery.vfRemote({controller:t.controller,methodName:t.methodName,params:[e.obj.val().trim()],success:t.success})}else{jQuery.SFQuery.soqlQuery({query:t.actualQuery,success:t.success})}};AUPT.showAutoCompleteResults=function(e){if(e===null||e.length===0){this.autoCompleteState.elem.focus();this.showNoResultsWindow();return}var t=this.getAutoCompleteTable(this.cleanQueryResult(e),this.autoCompleteState);jQuery("#sf-ac-res-wind").empty().append(t);this.showAutoCompleteWindow(this.autoCompleteState.elem);t.focus();t.parent().scrollTop(0)};AUPT.hideAutoCompleteWindow=function(){jQuery("#sf-ac-res-wind").empty().hide()};AUPT.showAutoCompleteLoad=function(){jQuery("#sf-ac-res-wind").empty().append("<span>Loading...</span>");this.showAutoCompleteWindow(this.autoCompleteState.elem)};AUPT.showNoResultsWindow=function(){jQuery("#sf-ac-res-wind").empty().append('<span style="font-weight: bold; margin: 2px;">No results found.</span>');this.showAutoCompleteWindow(this.autoCompleteState.elem)};AUPT.showAutoCompleteWindow=function(e){var t=jQuery("#sf-ac-res-wind");t.css({top:e.offset().top+e.outerHeight()+5,left:e.offset().left+1});t.fadeIn()};AUPT.setElemVal=function(e,t){if(e.val().length>0&&this.acInQueryString){var n=this.acCharCode+this.acQueryString;var r=new RegExp("("+n+")","gi");e.val(e.val().replace(r,t))}else{e.val(t)}};AUPT.scrollAcWindForNav=function(e){var t=jQuery("#sf-ac-res-wind");var n=e.position().top;jQuery(t).animate({scrollTop:n},100)};AUPT.handleAutoCompleteTableNav=function(e,t){var n=t.find(".sfquery-ac-table-row-hover");var r=t.data("focusedRowIndex");var i=t.find("tr").length;if(e.keyCode==38){if(r===1){return false}t.data("focusedRowIndex",--r);n.removeClass("sfquery-ac-table-row-hover");var s=t.find("tbody tr:nth-child("+r+")");s.addClass("sfquery-ac-table-row-hover");if(r===1){t.parent().scrollTop(0)}else{this.scrollAcWindForNav(s)}return false}if(e.keyCode==40){if(r===i-1){return false}t.data("focusedRowIndex",++r);n.removeClass("sfquery-ac-table-row-hover");var o=t.find("tbody tr:nth-child("+r+")");o.addClass("sfquery-ac-table-row-hover");this.scrollAcWindForNav(o);return false}if(e.keyCode==13||e.keyCode==32||e.keyCode==9){n.click();return false}};AUPT.scrollInputToBottom=function(e){e.scrollTop(e[0].scrollHeight);e.focus()};AUPT.getAutoCompleteTable=function(e,t){var n=this;var r=jQuery("<table></table>");r.attr("tabindex",0);r.data("focusedRowIndex",2);r.keydown(function(e){e.preventDefault();e.stopPropagation();n.handleAutoCompleteTableNav(e,jQuery(this))});r.addClass("sfquery-ac-table");var i=jQuery("<tbody></tbody>");var s=[];var o=jQuery("<tr></tr>");var u={};for(var a in e[0]){s.push(a);u[a]=true;if(jQuery.inArray(a,t.exclude)>-1){u[a]=false;continue}else if(a in t.replace){o.append("<th>"+t.replace[a]+"</th>")}else{o.append("<th>"+a+"</th>")}}var f=jQuery("<thead/>");f.append(o);r.append(f);var l=s[0];var c=null;for(var h=0;h<e.length;h++){var p=jQuery("<tr></tr>");var d=e[h][l];if(t.inputFieldVal!=null&&typeof e[h][t.inputFieldVal]!=="undefined"){c=e[h][t.inputFieldVal]}else{c=d}for(var v=0;v<s.length;v++){var m=e[h][s[v]];if(s[v]==t.focusField){p.click(function(e,r){return function(){n.hideAutoCompleteWindow();n.setElemVal(t.elem,r);n.resetAutoCompleteVars();n.scrollInputToBottom(t.elem);t.onRowClick(e)}}(m,c))}if(u[s[v]]===false){continue}p.append("<td>"+m+"</td>").focus(function(){jQuery(this).addClass("sfquery-ac-table-row-hover")}).blur(function(){jQuery(this).removeClass("sfquery-ac-table-row-hover")}).mouseover(function(){jQuery(this).addClass("sfquery-ac-table-row-hover")}).mouseout(function(){jQuery(this).removeClass("sfquery-ac-table-row-hover")})}if(h===0){p.addClass("sfquery-ac-table-row-hover")}i.append(p)}r.append(i);return r};ApexScriptUtils.getAutoCompleteExtend=function(){return jQuery.extend({query:null,actualQuery:null,controller:null,methodName:null,type:"inputText",state:null,onRowClick:null,focusField:null,inputFieldVal:null,combination:null,replace:{},exclude:[],success:AUPT.showAutoCompleteResults.bind(ApexScriptUtils.getInstance()),error:function(e,t){alert("Default error handler invoked. Check console for more info.");console.log(e)}},arguments[0]||{})};AUPT.resetAutoCompleteVars=function(){this.hideKeyComboStart();this.hideAutoCompleteWindow();this.acInQueryString=false;this.acInCombination=false;this.acQueryString=null;this.acCharCode=null};AUPT.createAutoCompleteWindow=function(){var e=jQuery('<div id="sf-ac-res-wind"/>');e.css({position:"absolute",display:"none",top:0,left:0,zIndex:1e3,backgroundColor:"white",border:"1px solid #AAA"});jQuery(document.body).append(e);return e};AUPT.showKeyComboStart=function(e){var t=this.getKeyComboStartElem(e);t.css({position:"absolute",top:e.offset().top+e.height()+1,left:e.offset().left+5});t.show()};AUPT.hideKeyComboStart=function(e){var t=this.getKeyComboStartElem(e);t.hide()};AUPT.getKeyComboStartElem=function(){if(this.keyComboStartWindow==null){var e=jQuery('<div class="key-combo-start-window"/>');e.append(jQuery("<span>Begin typing to search</span>"));this.keyComboStartWindow=e;jQuery(document.body).append(e)}return this.keyComboStartWindow};AUPT.acOnKeyDown=function(e,t,n){if(t.data("timeout")!=null){clearTimeout(t.data("timeout"))}if(t.val().length===0){this.resetAutoCompleteVars();return}var r=n.which||n.keyCode;var i=this.mapKeyCode(n.shiftKey,r);if(!this.isPrintableChar(r)||typeof i==="undefined"){return}var s=true;if(e.args.combination!=null&&!this.acInQueryString){var o=e.args.combination;var u=t.val();if(r===8){if(this.acCharCode.length==1){this.resetAutoCompleteVars()}else{this.acCharCode=this.acCharCode.substr(0,this.acCharCode.length-1)}this.hideKeyComboStart();return}if(this.acCharCode==null){this.acCursorStartPos=t.getCursorPosition();var a=this.acCursorStartPos-1;if(i==o.substr(0,1)){this.acCharCode=i;if(this.acCharCode===o){this.acInQueryString=true;this.showKeyComboStart(t)}}}else{this.acCharCode+=i;if(this.acCharCode===o){this.acInQueryString=true;this.showKeyComboStart(t)}}s=false}else if(this.acInQueryString){if(r==8){if(this.acQueryString==null){if(this.acCharCode.length===1){this.resetAutoCompleteVars()}else{this.acInQueryString=false;this.acCharCode=this.acCharCode.substr(0,this.acCharCode.length-1)}this.hideKeyComboStart();s=false}else{if(this.acQueryString.length>1){this.acQueryString=this.acQueryString.substr(0,this.acQueryString.length-1)}else{this.acQueryString=null;this.showKeyComboStart(t);this.hideAutoCompleteWindow();s=false}}}else if(this.acQueryString==null){this.acQueryString=i}else{this.acQueryString+=i}}var f=this;if(s){var l=setTimeout(function(){e.obj=t;f.hideKeyComboStart();var n=null;if(typeof e.args.query!=="undefined"){if(!f.acInQueryString){n=e.args.query.replace(/\{v\}/g,t.val())}else{n=e.args.query.replace(/\{v\}/g,f.acQueryString)}}e.args.actualQuery=n;ApexScriptUtils.getInstance().doSearchForAutoComplete(e)},700);t.data("timeout",l)}};AUPT.isPrintableChar=function(e){return e!=16&&e!=17&&e!=18&&e!=91};AUPT.mapKeyCode=function(e,t){var n=[];n[192]="~";n[49]="!";n[50]="@";n[51]="#";n[52]="$";n[53]="%";n[54]="^";n[55]="&";n[56]="*";n[57]="(";n[48]=")";n[109]="_";n[107]="+";n[219]="{";n[221]="}";n[220]="|";n[59]=":";n[222]='"';n[188]="<";n[190]=">";n[191]="?";n[32]=" ";var r="";if(e){if(t>=65&&t<=90){r=String.fromCharCode(t)}else{r=n[t]}}else{if(t==186||t==59){r=";"}else if(t>=65&&t<=90){r=String.fromCharCode(t).toLowerCase()}else{r=String.fromCharCode(t)}}return r};jQuery.fn.sfAutoComplete=function(){var e=jQuery("#sf-ac-res-wind");if(e.length==0){ApexScriptUtils.getInstance().createAutoCompleteWindow()}var t=arguments[0];var n={args:t};return this.each(function(){jQuery(this).keyup(function(e){ApexScriptUtils.getInstance().acOnKeyDown(n,jQuery(this),e)})})};ApexScriptUtils.getTableScrollExtend=function(e){return jQuery.extend({fixedHeader:true,height:400},arguments[0]||{})};AUPT.tableScroll=function(e,t){e.wrap('<div class="sfquery-float-table-wrapper"/>');var n=e.parent();n.css({overflow:"auto",height:t.height+"px"});if(t.fixedHeader){var r=jQuery('<div class="sfquery-float-table-header-cont"/>');this.addTableHeaderToFixedCont(r,e);n.append(r);n.scroll(function(){var e=jQuery(this).scrollTop();r.css({top:e});if(e===0){r.hide()}else if(!r.is(":visible")){r.show()}})}};AUPT.addTableHeaderToFixedCont=function(e,t){var n=t.clone();n.children("tbody").remove();var r=n.find("thead > tr > th");t.find("thead > tr > th").each(function(e,t){var n=jQuery(t);var i=jQuery(r[e]);i.width(n.width())});e.append(n);e.width(t.children("thead").width())};jQuery.fn.tableScroll=function(e){var t=ApexScriptUtils.getTableScrollExtend(e);return this.each(function(){ApexScriptUtils.getInstance().tableScroll(jQuery(this),t)})};ApexScriptUtils.getRestClientExtend=function(){return jQuery.extend({type:"GET",url:null,headers:null,success:function(e){console.log(e)},error:function(e){alert("Default error handler invoked. Check console for more info.");console.log(e)}},arguments[0]||{})};AUPT.makeRestRequest=function(){var e=ApexScriptUtils.getRestClientExtend(arguments[0]);e.headers=e.headers==null?{}:e.headers;e.headers["Authorization"]="Bearer "+ApexScriptUtils.sessionId;jQuery.ajax(e)};jQuery.SFQuery.getMetaData=function(e){e=typeof e!=="undefined"?e:{};e.url=ApexScriptUtils.REST_URLS.MetaData+e.objectType;ApexScriptUtils.getInstance().makeRestRequest(e)};jQuery.SFQuery.getObjectDescribe=function(e){e=typeof e!=="undefined"?e:{};e.url=ApexScriptUtils.REST_URLS.Describe.replace("{o}",e.objectType);ApexScriptUtils.getInstance().makeRestRequest(e)};jQuery.SFQuery.getObjectDetail=function(e){e=typeof e!=="undefined"?e:{};e.url=ApexScriptUtils.REST_URLS.ObjectDetail.replace("{o}",e.objectType).replace("{ID}",e.recordId);ApexScriptUtils.getInstance().makeRestRequest(e)}