<cfcomponent displayname="S3 Upload" extends="farcry.core.packages.formtools.join" output="false">

	<cfproperty name="ftJoin" required="true" default="" options="comma seperated list of types" hint="A list of the user can select from. e.g 'dmImage,dmfile,dmflash'"/>
	<cfproperty name="ftAllowSelect" required="false" default="false" options="true,false" hint="Allows user to select existing records within the library picker"/>
	<cfproperty name="ftAllowCreate" required="false" default="true" options="true,false" hint="Allows user create new record within the library picker"/>
	<cfproperty name="ftAllowEdit" required="false" default="false" options="true,false" hint="Allows user edit new record within the library picker"/>
	<cfproperty name="ftRemoveType" required="false" default="remove" options="delete,remove" hint="remove will only remove from the join, delete will remove from the database. detach is a deprecated alias for remove."/>
	<cfproperty name="ftAllowRemoveAll" required="false" default="false" options="true,false" hint="Allows user to remove all items at once"/>
	
	<cfproperty name="ftAllowedFileExtensions" default="jpg,jpeg,png,gif,pdf,doc,ppt,xls,docx,pptx,xlsx,zip,rar,mp3,mp4,m4v,avi">
	<cfproperty name="ftDestination" default="" hint="Destination of file store relative of secure/public locations.">
	<cfproperty name="ftMaxSize" default="104857600" hint="Maximum filesize upload in bytes.">
	<cfproperty name="ftSecure" default="false" hint="Store files securely outside of public webspace.">

	<cfproperty name="ftTargetProperty" default="false" hint="Property of individual object in the joined content type.">

<!--- TODO: implement allowed file extensions --->
<!--- TODO: implement ftSecure flag --->

	<cffunction name="init" output="false">
		<cfreturn this>
	</cffunction>

	<cffunction name="edit" access="public" output="true" returntype="string">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">
		<cfargument name="inputClass" required="false" type="string" default="" hint="This is the class value that will be applied to the input field.">

		<cfset var html = "">
		<cfset var item = "">
		<cfset var stActions = structNew() />

		<!--- SETUP stActions --->
		<cfset stActions.ftAllowSelect = arguments.stMetadata.ftAllowSelect />
		<cfset stActions.ftAllowCreate = arguments.stMetadata.ftAllowCreate />
		<cfset stActions.ftAllowEdit = arguments.stMetadata.ftAllowEdit />
		<cfset stActions.ftRemoveType = arguments.stMetadata.ftRemoveType />
		
		<cfif structKeyExists(arguments.stMetadata, "ftAllowAttach")>
			<cfset stActions.ftAllowSelect = arguments.stMetadata.ftAllowAttach />
		</cfif>
		<cfif structKeyExists(arguments.stMetadata, "ftAllowAdd")>
			<cfset stActions.ftAllowCreate = arguments.stMetadata.ftAllowAdd />
		</cfif>
		<cfif arguments.stMetadata.ftRemoveType EQ "detach">
			<cfset stActions.ftRemoveType = "remove" />
		</cfif>

		<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

		<cfscript>

			var cdnConfig = application.fc.lib.cdn.getLocation("publicfiles");
			cdnConfig.urlExpiry = 1800

			var utils = new s3.utils();
			var awsSigning = new s3.awsSigning(cdnConfig.accessKeyID, cdnConfig.awsSecretKey, utils);

			var fileUploadPath = "#cdnConfig.pathPrefix##arguments.stMetadata.ftDestination#";
			if (left(fileUploadPath, 1) == "/") {
				fileUploadPath = mid(fileUploadPath, 2, len(fileUploadPath)-1);
			}

			var isoTime = utils.iso8601();
			var expiry = cdnConfig.urlExpiry;

			var params = awsSigning.getAuthorizationParams( "s3", "ap-southeast-2", isoTime );
			params[ 'X-Amz-SignedHeaders' ] = 'host';

			// create policy and add the encoded policy to the query params
			var expiration = dateConvert("local2utc", dateAdd("s", expiry, now()));
			var policy = {
				"expiration": dateFormat(expiration, "yyyy-mm-dd") & "T" & timeFormat(expiration, "HH:mm:ss") & "Z",
				"conditions": [
					{"x-amz-credential": "#params["X-Amz-Credential"]#"},
					{"x-amz-algorithm": "#params["X-Amz-Algorithm"]#"},
					{"x-amz-date": "#params["X-Amz-Date"]#" },
					{"x-amz-signedheaders": "#params["X-Amz-SignedHeaders"]#" },

					{ "acl": "public-read" },
					{ "bucket": "#cdnConfig.bucket#" },
					[ "starts-with", "$key", "#fileUploadPath#" ],

					{ "success_action_status": javaCast("string", "201") },
					[ "starts-with", "$Content-Type", "" ],
					[ "starts-with", "$filename", "#fileUploadPath#" ],
					[ "starts-with", "$name", "#fileUploadPath#" ]
				]
			};
			if (arguments.stMetadata.ftMaxSize > 0) {
				arrayAppend(policy.conditions, [ "content-length-range", 0, javaCast("integer", arguments.stMetadata.ftMaxSize) ])
			}

			var serializedPolicy = serializeJSON(policy);
			serializedPolicy = reReplace(serializedPolicy, "[\r\n]+", "", "all");
			params[ 'Policy' ] = binaryEncode(charsetDecode(serializedPolicy, "utf-8"), "base64");
			params[ 'X-Amz-Signature' ] = awsSigning.sign( isoTime.left( 8 ), "ap-southeast-2", "s3", params[ 'Policy' ] );

			var bucketEndpoint = "https://s3-ap-southeast-2.amazonaws.com/#cdnConfig.bucket#";

			var ftMin = 0;
			var ftMax = 0;
			var buttonAddLabel = "Add Files";

// TODO: for mobile / responsive there should be no mention of drag/drop 
			var placeholderAddLabel = """#buttonAddLabel#"" or drag and drop here";

		</cfscript>

 
		<skin:htmlhead id="s3upload">
			<cfoutput>
				<link rel="stylesheet" href="/farcry/plugins/s3upload/www/css/s3upload.css">
				<script type="text/javascript" src="/farcry/plugins/s3upload/www/js/plupload-2.1.8/js/plupload.full.min.js"></script>
				<script type="text/javascript" src="/farcry/plugins/s3upload/www/js/s3upload.js"></script>
			</cfoutput>
		</skin:htmlhead>

		<skin:loadJS id="fc-jquery" />
		<skin:loadJS id="fc-jquery-ui" />
		<skin:loadCSS id="jquery-ui" />
		<skin:loadCSS id="fc-fontawesome" />

		<cfset joinItems = getJoinList(arguments.stObject[arguments.stMetadata.name]) />

		<cfsavecontent variable="html">
			<cfoutput>

				<!--- UPLOADER UI --->
				<div class="multiField">
					<ul id="join-#stObject.objectid#-#arguments.stMetadata.name#" 
						class="arrayDetailView" 
						style="list-style-type:none;border-bottom:1px solid ##ebebeb;border-width:1px 1px 0px 1px;margin:0px;">

						<div id="#arguments.fieldname#-container" class="s3upload upload-empty" style="padding-top:10px;">
							<div id="upload-placeholder" class="upload-placeholder">
								<div class="upload-placeholder-message">
									#placeholderAddLabel#
								</div>
							</div>


							<div id="upload-dropzone" class="upload-dropzone" style="padding:0px;">
								<cfset counter = 0 />
									<cfloop list="#joinItems#" index="i">
										<cfset counter = counter + 1 />
										<cfset stItem = application.fapi.getContentObject(tyapename=arguments.stMetadata.ftJoin,objectid=i)>
										<cfset stItemMetadata = application.fapi.getPropertyMetadata(typename=stItem.typename, property='file') />

										<li id="join-item-#arguments.stMetadata.name#-#i#" class="sort #iif(counter mod 2,de('oddrow'),de('evenrow'))#" serialize="#i#" style="border:1px solid ##ebebeb;padding:5px;zoom:1;">
											<table style="width:100%;">
											<tr>
											<td class="" style="cursor:move;padding:3px;"><i class="fa fa-sort"></i></td>
											<td id="item-content" class="" style="cursor:move;width:100%;padding:3px;">

											<div class="upload-item upload-item-complete">
												<div class="upload-item-row">
													<div class="upload-item-container">
														<cfif listFindNoCase("jpg,jpeg,png,gif", listLast(stItem.file, "."))>
															<div class="upload-item-image">
																<img src="#getFileLocation(stObject=stItem,stMetadata=stItemMetadata).path#">
															</div>
														<cfelse>											
															<div class="upload-item-nonimage" style="display:block;">
																<i class='fa fa-file-text-o'></i>
															</div>
														</cfif>
														<div class="upload-item-progress-bar"></div>
													</div>
													<div class="upload-item-info">
														<div class="upload-item-file">#listLast(stItem.file, "/")#</div>
													</div>
													<div class="upload-item-state"></div>
													<div class="upload-item-buttons">
														<cfif stActions.ftRemoveType EQ "delete">
															<button type="button" title="Delete" class="upload-button-remove"
																	confirmText="Are you sure you want to delete this item? Doing so will immediately remove this item from the database."><i class="fa fa-trash-o"></i></button>
														<cfelseif stActions.ftRemoveType EQ "remove">
															<button type="button" title="Remove" class="upload-button-remove" removeOnly="true"
																	confirmText="Are you sure you want to remove this item? Doing so will only unlink this content item. The content will remain in the database."><i class="fa fa-times"></i></button>
														</cfif>

													</div>
												</div>
											</div>	

											</td>
											<td class="" style="padding:3px;white-space:nowrap;"></td>
											</tr>
											</table>

										</li>		 					
									</cfloop>
								
								</div>

							<div style="border:none; text-align:left;" class="buttonHolder form-actions">
								<button id="upload-add" class="fc-btn btn" role="button" aria-disabled="false"><i class="fa fa-cloud-upload"></i> #buttonAddLabel#</button>
							</div>

						</div>
					</ul>
				</div>

				<input type="hidden" name="#arguments.fieldname#" id="#arguments.fieldname#" value="#joinItems#" />
				<input id="#arguments.fieldname#_orientation" name="#arguments.fieldname#_orientation" type="hidden" value="">

				<!--- FARCRY FORMTOOL VALIDATION --->
				<input id="#arguments.fieldname#_filescount" name="#arguments.fieldname#_filescount" type="hidden" value="#listLen(joinItems)#">
				<input id="#arguments.fieldname#_errorcount" name="#arguments.fieldname#_errorcount" type="hidden" value="0">
				<script>
					$j(function(){
						$j("###arguments.fieldname#_errorcount").rules("add", {
							min: 0,
							max: 0,
							messages: {
								min: "There was an error with some uploads. Please remove them and try uploading again.",
								max: "There was an error with some uploads. Please remove them and try uploading again."
							}
						});
					});
				</script>

				<script>
					s3upload($j, plupload, {
						url : "#bucketEndpoint#",
						fieldname: "#arguments.fieldname#",
						uploadpath: "#fileUploadPath#",
						destinationpart: "#arguments.stMetadata.ftDestination#",
						maxfiles: #ftMax#,
						multipart_params: {
							"acl" : "public-read",
							"key": "#fileUploadPath#/${filename}",
							"name": "#fileUploadPath#/${filename}",
							"filename": "#fileUploadPath#/${filename}",

							"success_action_status": "201",
							"X-Amz-Algorithm": "#params["X-Amz-Algorithm"]#",
							"X-Amz-Credential": "#params["X-Amz-Credential"]#",
							"X-Amz-Date": "#params["X-Amz-Date"]#",

							"Policy": "#params["Policy"]#",
							"X-Amz-Signature": "#params["X-Amz-Signature"]#",
							"X-Amz-SignedHeaders": "#params["X-Amz-SignedHeaders"]#"
						},
						filters: {
							max_file_size : "#arguments.stMetadata.ftMaxSize#",
							mime_types: [
								{ title: "Images", extensions: "jpg,jpeg,png,gif" },
								{ title: "Files", extensions: "pdf,doc,ppt,xls,docx,pptx,xlsx,zip,rar,mp3,mp4,m4v,avi" }
							]
						},
						fc: {
							"arrayupload": true,
							"webroot": "#application.url.webroot#/index.cfm?ajaxmode=1",
							"typename": "#arguments.typename#",
							"objectid": "#arguments.stObject.objectid#",
							"property": "#arguments.stMetadata.name#",
							"onFileUploaded": function(file) {
								
								//create a new object for the file
								$j.ajax({
									dataType: "json",
									type: 'get',
									cache: false,
						 			url: '#application.url.webroot#/index.cfm?ajaxmode=1&type=#arguments.stMetadata.ftJoin#' 
								 		 + '&filename=' + file.name
								 		 + '&view=displayAjaxSaveFile' 
								 		 + '&targetproperty=#arguments.stMetadata.ftTargetProperty#'
								 		 + '&property=#arguments.stMetadata.name#',
								 	success: function (result) {
								 		if (result.success) {	

								 			//append new objectid to the existing ones
											var aObjectIds = $j("###arguments.fieldname#").val().split( "," );
											aObjectIds.push(result.objectid);
											$j("###arguments.fieldname#").val(aObjectIds.join(","));

											//update html with appropriate attributes to work with sorting
											$j("##join-item-#arguments.stMetadata.name#-" + file.id).attr("serialize",result.objectid);
											$j("##join-item-#arguments.stMetadata.name#-" + file.id).attr("id","##join-item-#arguments.stMetadata.name#-"+result.objectid);
								 		}
								}
								});	
							},
							"getItemTemplate": function(id, name, size) {

								id = id || "";
								name = name || "";
								size = size || "0";

								// update html to work with sort
								var item = $j(

									  '<li id="join-item-#arguments.stMetadata.name#-' + id + '" class="sort" serialize="' + id + '" style="border:1px solid ##ebebeb;padding:5px;zoom:1;">'
									+ '	<table style="width:100%;">'
									+ '	<tr>'
									+ '	<td class="" style="cursor:move;padding:3px;"><i class="fa fa-sort"></i></td>'
									+ '	<td id="item-content" class="" style="cursor:move;width:100%;padding:3px;">'
									+ '		<div id="' + id + '" class="upload-item">'
									+ '			<div class="upload-item-row">'
									+ '				<div class="upload-item-container">'
									+ '					<div class="upload-item-image"></div>'
									+ '					<div class="upload-item-nonimage"></div>'
									+ '					<div class="upload-item-progress-bar"></div>'
									+ '				</div>'
									+ '				<div class="upload-item-info">'
									+ '					<div class="upload-item-file"><span class="upload-item-filename">' + name + '</span> (' + size +')</div>'
									+ '				</div>'
									+ '    <div class="upload-item-state">'
									+ '      <div class="upload-item-status">Waiting</div>'
									+ '    </div>'
									+ '    <div class="upload-item-buttons">'
									+ '    <button type="button" title="Remove" class="upload-button-remove" removeOnly="true" confirmText="Are you sure you want to remove this item? Doing so will only unlink this content item. The content will remain in the database."><i class="fa fa-times"></i></button>'
									+ '    </div>'
									+ '			</div>'
									+ '		</div>'
									+ '	</td>'
									+ '	<td class="" style="padding:3px;white-space:nowrap;"></td>'
									+ '	</tr>'
									+ '	</table>'
									+ '</li>'

								);
								return item;
							},
							"onFileRemove": function(item,file,removeOnly) {

								var objectid = $j(item).attr("serialize");

					 			//remove this objectid from hidden field
								var aValues = $j("###arguments.fieldname#").val().split( "," );
								aValues.splice( $j.inArray(objectid, aValues), 1 );
								$j("###arguments.fieldname#").val(aValues.join(","));

								// delete object
								if (!removeOnly) {
									$j.ajax({
										dataType: "json",
										type: 'get',
										cache: false,
							 			url: '#application.url.webroot#/index.cfm?ajaxmode=1&type=#arguments.stMetadata.ftJoin#' 
									 		 + '&objectid=' + objectid
									 		 + '&view=displayAjaxDeleteFile'
									});	
								}

								if($j("###arguments.fieldname#").val()) {
									$j(".s3upload").removeClass("upload-empty");
								}

							},

						}
					
           		 });
				</script>


			</cfoutput>
			<cfoutput>
				<script type="text/javascript">
				$j(function() {
					fcForm.initSortable('#arguments.stobject.typename#','#arguments.stobject.objectid#','#arguments.stMetadata.name#','#arguments.fieldname#');
				});
				</script>
			</cfoutput>
		</cfsavecontent>

		<cfif structKeyExists(request, "hideLibraryWrapper") AND request.hideLibraryWrapper>
			<cfreturn "#html#" />
		<cfelse>
			<cfreturn "<div id='#arguments.fieldname#-library-wrapper'>#html#</div>" />	
		</cfif>

	</cffunction>

	<cffunction name="display" access="public" output="false" returntype="string" hint="This will return a string of formatted HTML text to display.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">

		<cfset var returnHTML = ""/>
		<cfset var i = "" />
		<cfset var o = "" />
		<cfset var q = "" />
		<cfset var ULID = "" />
		<cfset var stobj = "" />
		<cfset var html = "" />
		<cfset var oData = "" />

		<cfset arguments.stMetadata = prepMetadata(stObject = arguments.stObject, stMetadata = arguments.stMetadata) />

		<cfparam name="arguments.stMetadata.ftLibrarySelectedWebskin" default="librarySelected">
		<cfparam name="arguments.stMetadata.ftLibrarySelectedListClass" default="thumbNailsWrap">
		<cfparam name="arguments.stMetadata.ftLibrarySelectedListStyle" default="">
		<cfparam name="arguments.stMetadata.ftJoin" default="">
		
		<!--- We need to get the Array Field Items as a query --->
		<cfset o = createObject("component",application.stcoapi[arguments.typename].packagepath)>
		
		<cfif arguments.stMetadata.type EQ "array">
			<cfset q = o.getArrayFieldAsQuery(objectid="#arguments.stObject.ObjectID#", Typename="#arguments.typename#", Fieldname="#stMetadata.Name#", ftJoin="#stMetadata.ftJoin#")>
			
			<cfsavecontent variable="returnHTML">
			<cfoutput>
					
				<cfset ULID = "#arguments.fieldname#_list">
				
				<cfif q.RecordCount>
				 
					<div id="#ULID#" class="#arguments.stMetadata.ftLibrarySelectedListClass#" style="#arguments.stMetadata.ftLibrarySelectedListStyle#">
						<cfloop query="q">
							<!---<li id="#arguments.fieldname#_#q.objectid#"> --->
								
								<div>
									<cfif listContainsNoCase(arguments.stMetadata.ftJoin,q.typename)>
										<cfset oData = createObject("component",application.stcoapi[q.typename].packagepath) />
										<cfset stobj = oData.getData(objectid=q.data) />
										<cfif FileExists("#application.path.project#/webskin/#q.typename#/#arguments.stMetadata.ftLibrarySelectedWebskin#.cfm")>
											<cfset html = oData.getView(stObject=stobj,template="#arguments.stMetadata.ftLibrarySelectedWebskin#") />
											#html#								
											<!---<cfinclude template="/farcry/projects/#application.projectDirectoryName#/webskin/#q.typename#/#arguments.stMetadata.ftLibrarySelectedWebskin#.cfm"> --->
										<cfelse>
											#stobj.label#
										</cfif>
									<cfelse>
										INVALID ATTACHMENT (#q.typename#)
									</cfif>
								</div>
														
							<!---</li> --->
						</cfloop>
					</div>
				</cfif>
	
					
			</cfoutput>
			</cfsavecontent>			
		<cfelseif len(arguments.stObject[arguments.stMetaData.Name])>
			<cfset stobj = application.fapi.getContentObject(objectid=arguments.stObject[arguments.stMetaData.Name])>
			<cfset returnHTML = application.fapi.getContentType("#stobj.typename#").getView(stObject=stobj, template=arguments.stMetaData.ftLibrarySelectedWebskin, alternateHtml=stobj.label) />
		</cfif>
		
		<cfreturn returnHTML>
	</cffunction>	
<!--- 
	<cffunction name="display" access="public" output="true" returntype="string" hint="This will return a string of formatted HTML text to display.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">
	
		<cfset var html = "">
	
		<cfsavecontent variable="html">
			<cfoutput><a target="_blank" href="#application.url.webroot#/download.cfm?downloadfile=#arguments.stobject.objectid#&typename=#arguments.typename#&fieldname=#arguments.stmetadata.name#">#listLast(arguments.stMetadata.value,"/")#</a></cfoutput>
		</cfsavecontent>
		
		<cfreturn html>
	</cffunction> --->




<!--- file formtool methods... --->

	<cffunction name="getFileLocation" access="public" output="false" returntype="struct" hint="Returns information used to access the file: type (stream | redirect), path (file system path | absolute URL), filename, mime type">
		<cfargument name="objectid" type="string" required="false" default="" hint="Object to retrieve">
		<cfargument name="typename" type="string" required="false" default="" hint="Type of the object to retrieve">
		<!--- OR --->
		<cfargument name="stObject" type="struct" required="false" hint="Provides the object">
		
		<cfargument name="stMetadata" type="struct" required="false" hint="Property metadata">
		<cfargument name="firstLook" type="string" required="false" hint="Where should we look for the file first. The default is to look based on permissions and status">
		<cfargument name="bRetrieve" type="boolean" required="false" default="true">

		<cfset var stResult = structnew()>
		
		<!--- Throw an error if the field is empty --->
		<cfif NOT len(arguments.stObject[arguments.stMetadata.name])>
			<cfset stResult = structnew()>
			<cfset stResult.method = "none">
			<cfset stResult.path = "">
			<cfset stResult.error = "No file defined">
			<cfreturn stResult>
		</cfif>
		
		<cfif isSecured(stObject=arguments.stObject,stMetadata=arguments.stMetadata)>
			<cfset stResult = application.fc.lib.cdn.ioGetFileLocation(location="privatefiles",file=arguments.stObject[arguments.stMetadata.name], bRetrieve=arguments.bRetrieve)>
		<cfelse>
			<cfset stResult = application.fc.lib.cdn.ioGetFileLocation(location="publicfiles",file=arguments.stObject[arguments.stMetadata.name], bRetrieve=arguments.bRetrieve)>
		</cfif>
		
		<cfreturn stResult>
	</cffunction>
	
	<cffunction name="checkFileLocation" access="public" output="false" returntype="struct" hint="Checks that the location of the specified file is correct (i.e. privatefiles vs publicfiles)">
		<cfargument name="objectid" type="string" required="false" default="" hint="Object to retrieve">
		<cfargument name="typename" type="string" required="false" default="" hint="Type of the object to retrieve">
		<!--- OR --->
		<cfargument name="stObject" type="struct" required="false" hint="Provides the object">
		
		<cfargument name="stMetadata" type="struct" required="false" hint="Property metadata">
		
		
		<cfset var stResult = structnew()>
		
		<!--- Throw an error if the field is empty --->
		<cfif NOT len(arguments.stObject[arguments.stMetadata.name])>
			<cfset stResult = structnew()>
			<cfset stResult.error = "No file defined">
			<cfreturn stResult>
		</cfif>
		
		<cfif isSecured(stObject=arguments.stObject,stMetadata=arguments.stMetadata)>
			<cfset stResult.correctlocation = "privatefiles">
			<cfset stResult.currentlocation = application.fc.lib.cdn.ioFindFile(locations="privatefiles,publicfiles",file=arguments.stObject[arguments.stMetadata.name])>
		<cfelse>
			<cfset stResult.correctlocation = "publicfiles">
			<cfset stResult.currentlocation = application.fc.lib.cdn.ioFindFile(locations="publicfiles,privatefiles",file=arguments.stObject[arguments.stMetadata.name])>
		</cfif>
		
		<cfset stResult.correct = stResult.correctlocation eq stResult.currentlocation>
		
		<cfreturn stResult>
	</cffunction>
	
	<cffunction name="isSecured" access="private" output="false" returntype="boolean" hint="Encapsulates the security check on the file">
		<cfargument name="stObject" type="struct" required="false" hint="Provides the object">
		<cfargument name="stMetadata" type="struct" required="false" hint="Property metadata">
		
		<cfset var filepermission = false>
		
		
		<cfimport taglib="/farcry/core/tags/security" prefix="sec">
		
		<sec:CheckPermission objectid="#arguments.stObject.objectid#" type="#arguments.stObject.typename#" permission="View" roles="Anonymous" result="filepermission" />
		<cfparam name="arguments.stMetadata.ftSecure" default="false">
		<cfif arguments.stMetadata.ftSecure eq "false" and (not structkeyexists(arguments.stObject,"status") or arguments.stObject.status eq "approved") and filepermission>
			<cfreturn false>
		<cfelse>
			<cfreturn true>
		</cfif>
	</cffunction>
	
	<cffunction name="duplicateFile" access="public" output="false" returntype="string" hint="For use with duplicateObject, copies the associated file and returns the new unique filename">
		<cfargument name="stObject" type="struct" required="false" hint="Provides the object">
		<cfargument name="stMetadata" type="struct" required="false" hint="Property metadata">
		
		<cfset var currentfilename = arguments.stObject[arguments.stMetadata.name]>
		<cfset var currentlocation = "">
		
		<cfif not len(currentfilename)>
			<cfreturn "">
		</cfif>
		
		<cfset currentlocation = application.fc.lib.cdn.ioFindFile(locations="privatefiles,publicfiles",file=currentfilename)>
		
		<cfif not len(currentpath)>
			<cfreturn "">
		</cfif>
		
		<cfif isSecured(arguments.stObject,arguments.stMetadata)>
			<cfreturn application.fc.lib.cdn.ioCopyFile(source_location=currentlocation,source_file=currentfilename,dest_location="privatefiles",dest_file=newfilename,nameconflict="makeunique",uniqueamong="privatefiles,publicfiles")>
		<cfelse>
			<cfreturn application.fc.lib.cdn.ioCopyFile(source_location=currentlocation,source_file=currentfilename,dest_location="publicfiles",dest_file=newfilename,nameconflict="makeunique",uniqueamong="privatefiles,publicfiles")>
		</cfif>
	</cffunction>

</cfcomponent> 
