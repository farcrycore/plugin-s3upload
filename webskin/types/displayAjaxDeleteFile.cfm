<!--- @@cacheStatus:-1 --->
<cfparam name="form.parentType" default="">
<cfparam name="form.property" default="">
<cfparam name="form.removeOnly" default="false">

<cfif NOT form.removeOnly>
	<cfset stResult = delete(objectid=stobj.objectid)>
	<cfif stResult.bSuccess>
		<cfset stProps = application.stcoapi[form.parentType].stprops>
		<cfset stTargetProps = application.stcoapi[stobj.typename].stprops>

		<cfif stProps[form.property].metadata.type EQ "array" 
			  AND stProps[form.property].metadata.fttype EQ "s3arrayUpload"
			  AND structKeyExists(stProps[form.property].metadata,"ftJoin") AND len(stProps[form.property].metadata.ftJoin)>

			<cfquery name="deleteRelated" datasource="#application.dsn#">
				DELETE FROM #form.parentType#_#form.property#
				WHERE data =  <cfqueryparam cfsqltype="cf_sql_varchar" value="#url.objectid#">
			</cfquery>
		</cfif>
	</cfif>
</cfif>

<cfset result = {"objectid":"#stobj.objectid#"}>

<cfcontent reset="true">
<cfheader name="Content-Type" value="application/json">
<cfoutput>#serializeJSON(result)#</cfoutput>




