<cfcomponent displayname="S3 Upload" extends="farcry.core.packages.formtools.field" output="false">

	<cfproperty name="ftAllowedFileExtensions" default="jpg,jpeg,png,gif,pdf,doc,ppt,xls,docx,pptx,xlsx,zip,rar,mp3,mp4,m4v,avi">
	<cfproperty name="ftDestination" default="" hint="Destination of file store relative of secure/public locations.">
	<cfproperty name="ftMaxSize" default="104857600" hint="Maximum filesize upload in bytes.">
	<cfproperty name="ftSecure" default="false" hint="Store files securely outside of public webspace.">


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
			var ftMax = 1;


			var buttonAddLabel = "Add File";
			if (ftMax > 1) {
				buttonAddLabel = "Add Files";
			}
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

		<cfsavecontent variable="html">
			<cfoutput>

				<!--- UPLOADER UI --->
				<div class="multiField">
				<div id="#arguments.fieldname#-container" class="s3upload upload-empty">
					<div id="upload-placeholder" class="upload-placeholder">
						<div class="upload-placeholder-message">
							#placeholderAddLabel#
						</div>
					</div>

					<div id="upload-dropzone" class="upload-dropzone">
						<cfloop list="#arguments.stMetadata.value#" index="item">
							<div class="upload-item upload-item-complete">
								<div class="upload-item-row">
									<div class="upload-item-container">
										<cfif listFindNoCase("jpg,jpeg,png,gif", listLast(arguments.stMetadata.value, "."))>
											<div class="upload-item-image">
												<img src="#getFileLocation(stObject=arguments.stObject, stMetadata=arguments.stMetadata).path#">
											</div>
										<cfelse>											
											<div class="upload-item-nonimage" style="display:block;">
												<i class='fa fa-file-text-o'></i>
											</div>
										</cfif>
										<div class="upload-item-progress-bar"></div>
									</div>
									<div class="upload-item-info">
										<div class="upload-item-file">#listLast(stObject.file, "/")#</div>
									</div>
									<div class="upload-item-state"></div>
									<div class="upload-item-buttons">
										<!--- <button type="button" title="Remove" class="upload-button-remove">&times;</button> --->
									</div>
								</div>
							</div>
						</cfloop>
					</div>

					<div style="border:none; text-align:left;" class="buttonHolder form-actions">
						<button id="upload-add" class="fc-btn btn" role="button" aria-disabled="false"><i class="fa fa-cloud-upload"></i> #buttonAddLabel#</button>
					</div>

				</div>
				</div>

				<input type="hidden" name="#arguments.fieldname#" id="#arguments.fieldname#" value="#application.fc.lib.esapi.encodeForHTMLAttribute(arguments.stMetadata.value)#" />
				<input id="#arguments.fieldname#_orientation" name="#arguments.fieldname#_orientation" type="hidden" value="">

				<!--- FARCRY FORMTOOL VALIDATION --->
				<input id="#arguments.fieldname#_filescount" name="#arguments.fieldname#_filescount" type="hidden" value="#listLen(arguments.stMetadata.value)#">
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
							"webroot": "#application.url.webroot#/index.cfm?ajaxmode=1",
							"typename": "#arguments.typename#",
							"objectid": "#arguments.stObject.objectid#",
							"property": "#arguments.stMetadata.name#"
						}
					});
				</script>

			</cfoutput>
		</cfsavecontent>

		<cfreturn html>
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
