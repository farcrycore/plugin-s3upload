<cfcomponent displayname="S3 Array Upload" extends="farcry.core.packages.formtools.join" output="false">

	<cfproperty name="ftAllowedFileExtensions" default="auto">
	<cfproperty name="ftDestination" default="auto" hint="Destination of file store relative of secure/public locations. If set to 'auto', this value will be derived from the target property.">
	<cfproperty name="ftMaxSize" default="auto" hint="Maximum filesize upload in bytes. If set to 'auto', this value will be derived from the target property.">
	<cfproperty name="ftSecure" default="auto" hint="Store files securely outside of public webspace. If set to 'auto', this value will be derived from the target property.">
	<cfproperty name="ftLocation" default="auto" hint="Store files in a specific CDN location. If set to 'auto', this value will be derived from the target property." />
	<cfproperty name="ftFileUploadSuccessCallback" default="" hint="JavaScript function that should be called when a file is successfully uploaded and saved as a record." />


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
		<cfset var targetType = arguments.stMetadata.ftJoin />
		<cfset var targetProperty = getTargetProperty(stMetadata=arguments.stMetadata) />
		<cfset var targetPropertyType = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftType") />
		<cfset var ftAllowedFileExtensions = arguments.stMetadata.ftAllowedFileExtensions />
		<cfset var ftDestination = arguments.stMetadata.ftDestination />
		<cfset var ftMaxSize = arguments.stMetadata.ftMaxSize />
		<cfset var ftSecure = arguments.stMetadata.ftSecure />

		<cfif ftAllowedFileExtensions eq "auto">
			<cfif targetPropertyType eq "file">
				<cfset ftAllowedFileExtensions = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftAllowedFileExtensions") />
			<cfelse>
				<cfset ftAllowedFileExtensions = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftAllowedExtensions") />
			</cfif>
		</cfif>
		<cfif ftDestination eq "auto">
			<cfset ftDestination = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftDestination") />
		</cfif>
		<cfif ftSecure eq "auto">
			<cfif targetPropertyType eq "file">
				<cfset ftSecure = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftSecure", default="false") />
			<cfelse>
				<cfset ftSecure = false />
			</cfif>
		</cfif>
		<cfif ftMaxSize eq "auto">
			<cfif targetPropertyType eq "file">
				<cfset ftMaxSize = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftMaxSize") />
			<cfelse>
				<cfset ftMaxSize = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftSizeLimit", default=104857600) />
			</cfif>
		</cfif>

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

			var cdnLocation = "publicfiles";
			var aclPermission = "public-read";

			if (arguments.stMetadata.ftLocation neq "auto") {
				cdnLocation = arguments.stMetadata.ftLocation;
			}
			else if (ftSecure) {
				cdnLocation = "privatefiles";
			}
			else if (targetPropertyType eq "image") {
				cdnLocation = "images";
			}
			if (ftSecure) {
				aclPermission = "private";
			}

			var cdnConfig = application.fc.lib.cdn.getLocation(cdnLocation);
			cdnConfig.urlExpiry = 1800;

			var utils = new s3.utils();
			var awsSigning = new s3.awsSigning(cdnConfig.accessKeyID, cdnConfig.awsSecretKey, utils);

			var fileUploadPath = "#cdnConfig.pathPrefix##ftDestination#";
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

					{ "acl": "#aclPermission#" },
					{ "bucket": "#cdnConfig.bucket#" },
					[ "starts-with", "$key", "#fileUploadPath#" ],

					{ "success_action_status": javaCast("string", "201") },
					[ "starts-with", "$Content-Type", "" ],
					[ "starts-with", "$filename", "#fileUploadPath#" ],
					[ "starts-with", "$name", "#fileUploadPath#" ]
				]
			};
			if (ftMaxSize > 0) {
				arrayAppend(policy.conditions, [ "content-length-range", 0, javaCast("integer", ftMaxSize) ])
			}

			var serializedPolicy = serializeJSON(policy);
			serializedPolicy = reReplace(serializedPolicy, "[\r\n]+", "", "all");
			params[ 'Policy' ] = binaryEncode(charsetDecode(serializedPolicy, "utf-8"), "base64");
			params[ 'X-Amz-Signature' ] = awsSigning.sign( isoTime.left( 8 ), "ap-southeast-2", "s3", params[ 'Policy' ] );

			var bucketEndpoint = "https://s3-ap-southeast-2.amazonaws.com/#cdnConfig.bucket#";

			var ftMin = 0;
			var ftMax = 50;
			var thumbWidth = 80;
			var thumbheight = 80;
			var cropMethod = 'fitinside';
			var format = '';

			var buttonAddLabel = "Add Files";

// TODO: for mobile / responsive there should be no mention of drag/drop 
			var placeholderAddLabel = """#buttonAddLabel#"" or drag and drop here";

		</cfscript>
		
		<skin:loadJS id="fc-jquery-ui" />
		<skin:loadJS id="s3uploadJS" />
		<skin:loadCSS id="s3uploadCSS" />

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

							<div id="#arguments.fieldname#-upload-dropzone" class="upload-dropzone" style="padding:0px;">
								<cfset var counter = 0 />
									<cfloop list="#joinItems#" index="i">
										<cfset counter = counter + 1 />
										<cfset var stItem = application.fapi.getContentObject(objectid=i)>
										<cfset var stProps = application.stcoapi[stItem.typename].stprops>

										<!--- find out the target property --->	
										<li id="join-item-#arguments.stMetadata.name#-#i#" class="sort #iif(counter mod 2,de('oddrow'),de('evenrow'))#" serialize="#i#" style="border:1px solid ##ebebeb;padding:5px;zoom:1;">
											<table style="width:100%;">
											<tr>
											<td class="" style="cursor:move;padding:3px;"><i class="fa fa-sort"></i></td>
											<td id="item-content" class="" style="cursor:move;width:100%;padding:3px;">

											<div class="upload-item upload-item-complete">
												<div class="upload-item-row">
													<div class="upload-item-container">
														
														<cfif listFindNoCase("jpg,jpeg,png,gif", listLast(stItem[targetProperty], ".")) AND NOT ftSecure AND structKeyExists(application.fc.lib, "cloudinary")>
															<cfset var cdnLocation = application.fapi.getContentType(typename=stItem.typename).getFileLocation(stObject=stItem,stMetadata=application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty)).path>
															<cfset var croppedThumbnail = application.fc.lib.cloudinary.fetch(
																file=cdnLocation,
																cropParams={
																	width:  "#thumbWidth#", 
																	height: "#thumbheight#", 
																	crop:   "#cropMethod#",
																	format: "#format#"
																})>
																<div class="upload-item-image">
																	<img src="#croppedThumbnail#" />
																</div>
														<cfelse>
															<div class="upload-item-nonimage" style="display:block;">
																<i class='fa fa-file-image-o'></i>
															</div>
														</cfif>
														
														<div class="upload-item-progress-bar"></div>
													</div>
													<div class="upload-item-info">
														<div class="upload-item-file">
															<cfif len(stItem.title)>
																#stItem.title#
															<cfelse>
																#listLast(stItem[targetProperty], "/")#
															</cfif> 
														</div>
													</div>
													<div class="upload-item-state"></div>

													<div class="upload-item-buttons">
														<cfif stActions.ftAllowEdit>
															<button Type="button" value="Edit" text="Edit" onClick="fcForm.openLibraryEdit('#stObject.typename#','#stObject.objectid#','#arguments.stMetadata.name#','#arguments.fieldname#','#i#');"><i class="fa fa-pencil-square-o"></i></button>
														</cfif>
													</div>
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

								<button id="#arguments.fieldname#-upload-add" class="fc-btn btn" role="button" aria-disabled="false"><i class="fa fa-cloud-upload"></i> #buttonAddLabel#</button>

								<cfif arguments.stMetadata.ftAllowCreate>

									<cfif listLen(arguments.stMetadata.ftJoin) GT 1>
										<div class="btn-group">
											<a class="btn dropdown-toggle" data-toggle="dropdown"><i class="fa fa-plus"></i> Create &nbsp;&nbsp;<i class="fa fa-caret-down" style="margin-right:-4px;"></i></a>
											<ul class="dropdown-menu">
												<cfloop list="#arguments.stMetadata.ftJoin#" index="i">
													<li value="#trim(i)#"><a onclick="$j('###arguments.fieldname#-add-type').val('#trim(i)#'); fcForm.openLibraryAdd('#stObject.typename#','#stObject.objectid#','#arguments.stMetadata.name#','#arguments.fieldname#');">#application.fapi.getContentTypeMetadata(i, 'displayname', i)#</a></li>
												</cfloop>
											</ul>
										</div>
									<cfelse>
										<a class="btn" onclick="fcForm.openLibraryAdd('#stObject.typename#','#stObject.objectid#','#arguments.stMetadata.name#','#arguments.fieldname#');"><i class="fa fa-plus"></i> Create</a>
									</cfif>
									<input type="hidden" id="#arguments.fieldname#-add-type" value="#arguments.stMetadata.ftJoin#" />

								</cfif>

								<cfif stActions.ftAllowSelect>
									<a class="btn" onclick="fcForm.openLibrarySelect('#stObject.typename#','#stObject.objectid#','#arguments.stMetadata.name#','#arguments.fieldname#');"><i class="fa fa-search"></i> Select</a>
								</cfif>

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
						$j("###arguments.fieldname#_filescount").rules("add", {
							min: #ftMin#,
							max: #ftMax#,
							messages: {
								min: "Please attach at least #ftMin# files.",
								max: "Please attach no more than #ftMax# files."
							}
						});
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
						destinationpart: "#ftDestination#",
						maxfiles: #ftMax#,
						multipart_params: {
							"acl" : "#aclPermission#",
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
							max_file_size : "#ftMaxSize#",
							mime_types: [
								{ title: "Files", extensions: "#ftAllowedFileExtensions#" }
							]
						},
						fc: {
							"arrayupload": true,
							"webroot": "#application.url.webroot#/index.cfm?ajaxmode=1",
							"typename": "#arguments.typename#",
							"objectid": "#arguments.stObject.objectid#",
							"targetobjectid": "",
							"property": "#arguments.stMetadata.name#",
							"allow_edit": "#arguments.stMetadata.ftAllowEdit#",
							"allow_remove": "#arguments.stMetadata.ftAllowRemove#",
							"onFileUploaded": function(file,item) {
								
								//create a new object for the file
								$j.ajax({
									dataType: "json",
									type: 'POST',
									cache: false,
						 			url: '#application.url.webroot#/index.cfm?ajaxmode=1&type=#listFirst(arguments.stMetadata.ftJoin)#&view=displayAjaxSaveFile',
									data: {
										"filename": file.name,
										"property": "#arguments.stMetadata.name#"
									},
								 	success: function (result) {

							 			//append new objectid to the existing ones
										var aObjectIds = $j("###arguments.fieldname#").val().split( "," );
										aObjectIds.push(result.objectid);
										$j("###arguments.fieldname#").val(aObjectIds.join(","));

										//update html with appropriate attributes to work with sorting
										$j("##join-item-#arguments.stMetadata.name#-" + file.id).attr("serialize",result.objectid);
										$j("##join-item-#arguments.stMetadata.name#-" + file.id).attr("id","##join-item-#arguments.stMetadata.name#-"+result.objectid);

										//enable edit button for just added images
										$j("##editAdded-"+file.id).attr("onClick","fcForm.openLibraryEdit('#stObject.typename#','#stObject.objectid#','#arguments.stMetadata.name#','#arguments.fieldname#','"+result.objectid+"');");

										//update list node w<!---  --->ith the new objectid
										var $listnode = $j("##"+file.id).closest("li.sort");
										$listnode.attr("id", "join-item-#arguments.stMetadata.name#-"+result.objectid);
										$listnode.attr("serialize", result.objectid);

										<cfif len(arguments.stMetadata.ftFileUploadSuccessCallback)>#arguments.stMetadata.ftFileUploadSuccessCallback#(result);</cfif>
									},
									error: function() {
										
							 			$j('##' + file.id).removeClass("upload-item-complete").addClass("upload-item-error").find(".upload-item-status").text("Error");
									}
								});	
							},
							"getItemTemplate": function(id, name, size, objectid, bEdit, bRemove) {

								id = id || "";
								name = name || "";
								size = size || "0";

								// update html to work with sort
								var item = $j(

									  '<li id="join-item-#arguments.stMetadata.name#-' + objectid + '" class="sort" serialize="' + objectid + '" style="border:1px solid ##ebebeb;padding:5px;zoom:1;">'
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
									+ ' 	<div class="upload-item-buttons btn-edit">'
									+ ' 		<button Type="button" value="Edit" text="Edit" id="editAdded-' + id + '"><i class="fa fa-pencil-square-o"></i></button>'
									+ ' 	</div>'
									+ '    <div class="upload-item-buttons">'
									+ '    <button type="button" title="Remove" class="upload-button-remove" removeOnly="true"><i class="fa fa-times"></i></button>'
									+ '    </div>'
									+ '			</div>'
									+ '		</div>'
									+ '	</td>'
									+ '	<td class="" style="padding:3px;white-space:nowrap;"></td>'
									+ '	</tr>'
									+ '	</table>'
									+ '</li>'

								);

								if (bEdit !== true && bEdit !== "true") {
									item.find(".btn-edit").remove();
								};
								if (bRemove !== true && bRemove !== "true") {
									item.find(".upload-button-remove").remove();
								};

								return item;
							},
							"onFileRemove": function(item,file,removeOnly) {

								var objectid = $j(item).attr("serialize");

								// remove or delete object

								$j.ajax({
									dataType: "json",
									type: 'POST',
									cache: false,
						 			url: '#application.url.webroot#/index.cfm?ajaxmode=1' 
								 		 + '&objectid=' + objectid
								 		 + '&view=displayAjaxDeleteFile',
								 	data: {
										"parenttype": "#arguments.typename#",
										"property": "#arguments.stMetadata.name#",
										"removeOnly": removeOnly

									},
								 	success: function (result) {

							 			//remove this objectid from hidden field
										var aValues = $j("###arguments.fieldname#").val().split( "," );
										aValues.splice( $j.inArray(objectid, aValues), 1 );
										$j("###arguments.fieldname#").val(aValues.join(","));

										if($j("###arguments.fieldname#").val()) {
											$j("##arguments.fieldname" + "-container").removeClass("upload-empty");
										} else {
											$j("##arguments.fieldname" + "-container").addClass("upload-empty");
										}
									}
								});	

							}

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
	</cffunction>




<!--- file formtool methods... --->
	<cffunction name="getTargetProperty" access="public" output="false" returntype="string" hint="Returns the target property given the provided metadata">
		<cfargument name="stMetadata" type="struct" required="true" />

		<cfset var stProps = {} />
		<cfset var thisprop = "" />

		<cfif not len(arguments.stMetadata.ftJoin)>
			<cfthrow message="No ftJoin attribute." />
		</cfif>

		<cfset stProps = application.stCOAPI[listFirst(arguments.stMetadata.ftJoin)].stProps />

		<cfloop collection="#application.stCOAPI[arguments.stMetadata.ftJoin].stProps#" item="thisprop">
			<cfif application.fapi.getPropertyMetadata(typename=arguments.stMetadata.ftJoin, property=thisprop, md="ftS3UploadTarget", default=false)>
				<cfreturn thisprop />
			</cfif>
		</cfloop>

		<cfloop collection="#application.stCOAPI[arguments.stMetadata.ftJoin].stProps#" item="thisprop">
			<cfif application.fapi.getPropertyMetadata(typename=arguments.stMetadata.ftJoin, property=thisprop, md="ftBulkUploadTarget", default=false)>
				<cfreturn thisprop />
			</cfif>
		</cfloop>

		<cfthrow message="No target property was specified with a ftS3UploadTarget or ftBulkUploadTarget attribute." />
	</cffunction>

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
		<cfset var targetType = arguments.stMetadata.ftJoin />
		<cfset var targetProperty = getTargetProperty(stMetadata=arguments.stMetadata) />
		<cfset var targetPropertyType = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftType") />
		<cfset var ftSecure = arguments.stMetadata.ftSecure />

		<cfif ftSecure eq "auto">
			<cfif targetPropertyType eq "file">
				<cfset ftSecure = application.fapi.getPropertyMetadata(typename=targetType, property=targetProperty, md="ftSecure", default="false") />
			<cfelse>
				<cfset ftSecure = false />
			</cfif>
		</cfif>
		
		<cfimport taglib="/farcry/core/tags/security" prefix="sec">
		
		<sec:CheckPermission objectid="#arguments.stObject.objectid#" type="#arguments.stObject.typename#" permission="View" roles="Anonymous" result="filepermission" />
		<cfif ftSecure eq "false" and (not structkeyexists(arguments.stObject,"status") or arguments.stObject.status eq "approved") and filepermission>
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
