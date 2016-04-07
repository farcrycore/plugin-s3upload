<!--- @@cacheStatus:-1 --->
<cfset stobj = application.fapi.getNewContentObject(typename=url.type,objectid=createUUID())>	
<cfset bSuccess = true>
<cfset error = "">

<cftry>
	<cfset stProps = application.stcoapi[stobj.typename].stprops>

	<!--- find out the target property --->	
	<cfif structkeyexists(stProps[url.targetproperty].metadata,"ftS3UploadTarget") AND stProps[url.targetproperty].metadata.ftS3UploadTarget>
		<cfset stMetadata = application.fapi.getPropertyMetadata(typename=stobj.typename, property=url.targetproperty) />
		<cfset stobj[url.targetproperty] = stMetadata.ftDestination&'/'&url.filename>
	</cfif>

	<cfset stobj['label'] = url.filename>
	<cfset setData(stProperties=stobj)>

<cfcatch>
	<cfset bSuccess = false>
	<cfset error = cfcatch.message>
</cfcatch>	
</cftry>

<cfset result = {"success":"#bSuccess#","objectid":"#stobj.objectid#","error":"#error#"}>

<cfcontent reset="true">
<cfheader name="Content-Type" value="application/json">
<cfoutput>#serializeJSON(result)#</cfoutput>
