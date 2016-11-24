<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />


<!--- Handling buttons --->
<cfset exit = false />
<ft:processForm action="Save and Close">
	<ft:processFormObjects typename="#stobj.name#" />
	<cfset exit = true />
</ft:processForm>
<ft:processForm action="Close">
	<cfset exit = true />
	<cfset lSavedObjectIDs = "" />
</ft:processForm>
<cfif exit>
	<cfoutput>
		<script type="text/javascript">
			<cfif isdefined("url.parentType")>
				$j('###url.fieldname#', parent.document).val($j('###url.fieldname#', parent.document).val() + ',#lSavedObjectIDs#');
				$fc.closeBootstrapModal();
			<cfelse>
				parent.$fc.closeBootstrapModal();
			</cfif>
		</script>
	</cfoutput>
	<cfexit method="exittemplate">
</cfif>


<!--- Display bulk upload forms --->
<cfset stPropMetadata = {
	"aFiles" = {
		"ftJoin" = stObj.name,
		"ftFileUploadSuccessCallback" = "addEditHTML"
	}
} />

<ft:form>
	<ft:object typename="bulkUpload" stPropMetadata="#stPropMetadata#" />
	<cfoutput>
		<script>
			window.addEditHTML = function(result) {
				if (result.edit_html.length === 0) {
					return;
				}

				// make sure all the CSS / JS required for the forms have been loaded
				for (var i = 0, ii = result.htmlhead.length; i < ii; i++) {
					if (result.htmlhead[i].id !== "onready") {
						if ($j("##" + result.htmlhead[i].id).size() === 0) {
							$j("head").append(result.htmlhead[i].html);
						}
					}
				}

				$j("##edit-forms").append(result.edit_html);

				// run all "onready" JavaScript
				for (var i = 0, ii = result.htmlhead.length; i < ii; i++) {
					if (result.htmlhead[i].id === "onready") {
						eval(result.htmlhead[i].html);
					}
				}

				$j("##edit-forms-header,##edit-forms-footer").show();
			}
		</script>
		<div id="edit-forms-header" style="display:none;">
			<h2>Quick Edit</h2>
		</div>
		<div id="edit-forms"></div>
		<div>
			<ft:buttonPanel>
				<span id="edit-forms-footer" style="display:none;">
					<ft:button value="Save and Close" color="orange" />
				</span>
				<ft:button value="Close" validate="false" />
			</ft:buttonPanel>
		</div>
	</cfoutput>
</ft:form>

<cfsetting enablecfoutputonly="false">