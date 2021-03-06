<cfparam name="form.filename" type="string">
<cfparam name="form.nameconflict" type="string">
<cfparam name="form.uploadpath" type="string">
<cfparam name="form.location" type="string" default="publicfiles">

<cfset pathWithoutCDNPrefix = form.uploadpath>
<cfset cdnConfig = application.fc.lib.cdn.getLocation("#form.location#")>
<cfif len(cdnConfig.pathPrefix)>
	<cfset pathWithoutCDNPrefix = replace("/#form.uploadpath#", cdnConfig.pathPrefix, "")>
</cfif>

<cfset uniquefilename = "#pathWithoutCDNPrefix#/#form.filename#">
<cfif form.nameconflict eq "makeunique">
	<cfset uniquefilename = application.fc.lib.cdn.ioGetUniqueFilename("#form.location#", uniquefilename)>
</cfif>

<cfset result = {
	"filename": "#form.filename#",
	"uploadpath": "#form.uploadpath#",
	"uniquefilename": "#listLast(uniquefilename, "/")#"
}>

<cfcontent reset="true">
<cfheader name="Content-Type" value="application/json">
<cfoutput>#serializeJSON(result)#</cfoutput>
