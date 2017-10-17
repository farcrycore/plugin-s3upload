<!--- @@cacheStatus:-1 --->
<cfparam name="form.filename" default="">
<cfparam name="form.property" default="">
<cfparam name="url.type" default="">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/core" prefix="core" />

<cfset stProps = application.stcoapi[url.type].stprops>
<cfset targetProperty = application.formtools.s3arrayUpload.oFactory.getTargetProperty(stMetadata={ "ftJoin" = url.type }) />

<!--- find out the target property --->
<cfset stNewObject = application.fapi.getNewContentObject(typename=url.type,objectid=createUUID()) />
<cfset stNewObject["label"] = form.filename />
<cfset stNewObject["title"] = form.filename />
<cfset stNewObject[targetProperty] = stProps[targetProperty].metadata.ftDestination & '/' & form.filename />
<cfif rEFindNoCase("\.(jpg|jpeg|png|gif)$", stNewObject[targetProperty]) and structKeyExists(application.formtools.image.oFactory, "uploadToCloudinary")>
	<cfset stNewObject[targetProperty] = application.formtools.image.oFactory.uploadToCloudinary(stNewObject[targetProperty]) />
</cfif>

<cfif application.fapi.isLoggedIn()>
	<cfset username = application.fapi.getCurrentUser().username>
<cfelse>
	<cfset username = "anonymous">
</cfif>
<cfset stResult = createFromUpload(stProperties=stNewObject, user=username, uploadfield=targetProperty) />

<cfset lEditFields = application.fapi.getContentTypeMetadata(typename=stNewObject.typename, md="bulkUploadEditFields", default="") />
<cfif len(lEditFields)>
	<cfsavecontent variable="editHTML"><cfoutput><h3>Edit #stNewObject.title#</h3></cfoutput><ft:object stObject="#stNewObject#" lFields="#lEditFields#" bIncludeFieldset="false" /></cfsavecontent>
	<core:inHead variable="aHead" />
<cfelse>
	<cfset editHTML = "" />
	<cfset aHead = [] />
</cfif>

<cfset application.fapi.stream(content={ "objectid"=stResult.objectid, "edit_html"=editHTML, "htmlhead"=aHead }, type="json") />