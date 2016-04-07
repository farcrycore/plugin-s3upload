<!--- @@cacheStatus:-1 --->
<cfset bSuccess = true>
<cftry>
	<cfset stResult = delete(objectid=stobj.objectid)>
<cfcatch>
	<cfset bSuccess = false>
</cfcatch>	
</cftry>

<cfset result = {"success":"#bSuccess#","objectid":"#stobj.objectid#"}>

<cfcontent reset="true">
<cfheader name="Content-Type" value="application/json">
<cfoutput>#serializeJSON(result)#</cfoutput>
