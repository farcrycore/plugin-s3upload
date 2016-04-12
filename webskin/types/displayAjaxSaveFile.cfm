<!--- @@cacheStatus:-1 --->
<cfparam name="form.filename" default="">
<cfparam name="form.property" default="">
<cfparam name="url.type" default="">

<cfset stobj = application.fapi.getNewContentObject(typename=url.type,objectid=createUUID())>	
<cfset stProps = application.stcoapi[stobj.typename].stprops>

<!--- find out the target property --->	
<cfloop collection="#stProps#" item="targetProperty">
	<cfif structkeyexists(stProps[targetProperty].metadata,"ftS3UploadTarget") AND stProps[targetProperty].metadata.ftS3UploadTarget>
		<cfset stMetadata = application.fapi.getPropertyMetadata(typename=stobj.typename, property=targetProperty) />
		<cfset stobj[targetProperty] = stMetadata.ftDestination&'/'&form.filename>
	</cfif>
</cfloop>

<cfset stobj['label'] = form.filename>
<cfset stobj['title'] = form.filename>
<cfset setData(stProperties=stobj)>

<cfset result = {"objectid":"#stobj.objectid#"}>

<cfcontent reset="true">
<cfheader name="Content-Type" value="application/json">
<cfoutput>#serializeJSON(result)#</cfoutput>
