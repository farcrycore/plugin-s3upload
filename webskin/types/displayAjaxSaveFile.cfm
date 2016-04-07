<!--- @@cacheStatus:-1 --->
<!--- @@viewStack: data --->
<!--- @@mimeType: json --->

<cfif structKeyExists(url, "filename") AND len(url.filename)>

	<cfset stResult = structNew()>
	<cfset stProps = application.stcoapi[stobj.typename].stprops>

	<!--- find out the target property --->	
	<cfloop collection="#stProps#" item="targetProperty">
		<cfif structkeyexists(stProps[targetProperty].metadata,"ftS3UploadTarget") AND stProps[targetProperty].metadata.ftS3UploadTarget>
			<cfset stMetadata = application.fapi.getPropertyMetadata(typename=stobj.typename, property=targetProperty) />
			<cfset stobj[targetProperty] = stMetadata.ftDestination&'/'&url.filename>
		</cfif>
	</cfloop>

	<cfset stobj['label'] = url.filename>
 	<cfset stResult = setData(stProperties=stobj)>

</cfif>	

<cfset result = {"success":"true","objectid":"#stobj.objectid#"}>

<cfcontent reset="true">
<cfheader name="Content-Type" value="application/json">
<cfoutput>#serializeJSON(result)#</cfoutput>
