<!--- @@cacheStatus:-1 --->
<cfparam name="url.parentType" default="">
<cfparam name="url.property" default="">

<cfset bSuccess = true>
<cftry>
	<cfset stResult = delete(objectid=stobj.objectid)>

	<cfif stResult.bSuccess>
		<cfset stProps = application.stcoapi[url.parentType].stprops>
		<cfset stTargetProps = application.stcoapi[stobj.typename].stprops>

		<cfif stProps[url.property].metadata.type EQ "array" 
			  AND stProps[url.property].metadata.fttype EQ "s3arrayUpload"
			  AND structKeyExists(stProps[url.property].metadata,"ftJoin") AND len(stProps[url.property].metadata.ftJoin)>

			<cfquery name="deleteRelated" datasource="#application.dsn#">
				DELETE FROM #url.parentType#_#url.property#
				WHERE data =  <cfqueryparam cfsqltype="cf_sql_varchar" value="#stobj.objectid#">
			</cfquery>

		</cfif>
	</cfif>

<cfcatch>
	<cfset bSuccess = false>
</cfcatch>	
</cftry>

<cfset result = {"success":"#stResult.bSuccess#","objectid":"#stobj.objectid#"}>

<cfcontent reset="true">
<cfheader name="Content-Type" value="application/json">
<cfoutput>#serializeJSON(result)#</cfoutput>
