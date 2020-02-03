component displayname="S3 Upload" hint="Bulk upload tasks" output="false" persistent="false" component="bulkupload" {


	public void function uploadfilecopied(required string taskID, required string jobID, required string action, required string ownedBy, required any details) {
		var stResult = structnew();
		var o = application.fapi.getContentType(typename=arguments.details.typename,singleton=true);
		var stObject = o.getData(objectid=arguments.details.objectid);
		var stUpdated = {};
        var thisfield = "";
        var stFP = {};
        var aFields = [];
        var stFixed = {};

        cfsetting(requesttimeout=100000);

        stFixed = application.formtools.image.oFactory.fixImage(
            stObject[arguments.details.targetfield],
            application.stCOAPI[arguments.details.typename].stProps[arguments.details.targetfield].metadata,
            application.stCOAPI[arguments.details.typename].stProps[arguments.details.targetfield].metadata.ftAutoGenerateType,
            application.stCOAPI[arguments.details.typename].stProps[arguments.details.targetfield].metadata.ftQuality
        );

        for (thisfield in application.stCOAPI[arguments.details.typename].stProps) {
            if (application.fapi.getPropertyMetadata(arguments.details.typename, thisfield, "ftType", "string") eq "image"
                and listfirst(application.fapi.getPropertyMetadata(arguments.details.typename, thisfield, "ftSourceField", ""), ":") eq arguments.details.targetfield) {

                stFP[thisfield] = structnew();
                arrayAppend(aFields, thisfield);
            }
        }

        stUpdated = application.formtools.image.oFactory.ImageAutoGenerateBeforeSave(
            typename=arguments.details.typename,
            stProperties=stObject,
            stFields=application.stCOAPI[arguments.details.typename].stProps,
            stFormPost=stFP
        );

        // image generation can take some time
        // refresh stObject to avoid overwriting user changes in the meantime
        stObject = o.getData(objectid=arguments.details.objectid);
        for (thisfield in aFields) {
            stObject[thisfield] = stUpdated[thisfield];
        }
        o.setData(stObject);

		stResult["message"] = "Images generated";
		stResult["objectID"] = stObject.objectid;

		application.fc.lib.tasks.addResult(result=stResult);
	}

}
