function s3upload($, plupload, options) {

	options = options || {};
	options.url = options.url || "";
	options.fieldname = options.fieldname || "";
	options.uploadpath = options.uploadpath || "";
	options.destinationpart = options.destinationpart || "";
	options.nameconflict = options.nameconflict || "makeunique";
	options.maxfiles = options.maxfiles || 20;
	options.multipart_params = options.multipart_params || {};
	options.filters = options.filters || {};

	options.fc = options.fc || {};

	// options.fc = {
	// 	"webroot": "/index.cfm?ajaxmode=1",
	// 	"typename": typename,
	// 	"objectid": objectid,
	// 	"property": property
	// };


	var $uploader = $("#" + options.fieldname + "-container"),
		$dropzone = $("#" + options.fieldname + "-container .upload-dropzone");

	var uploader = new plupload.Uploader({
		runtimes: "html5",
		url: options.url,

		container: options.fieldname + "-container",
		browse_button: options.fieldname + "-upload-add",
		drop_element: options.fieldname + "-upload-dropzone",

		max_files: options.maxfiles,
		multi_selection: (options.maxfiles != 1),

		urlstream_upload: true,
		file_data_name: "file",
		multipart: true,

		multipart_params: options.multipart_params,
		filters: options.filters
	});

	uploader.init();

	uploader.bind("Init", onPluploadInit);
	uploader.bind("Error", onPluploadError);
	uploader.bind("FilesAdded", onPluploadFilesAdded);
	uploader.bind("FilesRemoved", onPluploadFilesRemoved);
	uploader.bind("QueueChanged", onPluploadQueueChanged);
	uploader.bind("BeforeUpload", onPluploadBeforeUpload);
	uploader.bind("UploadFile", onPluploadUploadFile);
	uploader.bind("UploadProgress", onPluploadUploadProgress);
	uploader.bind("FileUploaded", onPluploadFileUploaded);
	uploader.bind("StateChanged", onPluploadStateChanged);


	function onPluploadInit(uploader, params) {

		if (!uploader.features.dragdrop) {
			// drag drop is not supported, hide drag and drop hint message
			$uploader.find(".upload-placeholder-message").text("\"Add photos...\" to upload");
		}

		if (parseInt($("#" + options.fieldname + "_filescount").val()) > 0) {
			$uploader.removeClass("upload-empty");
		}

		// bind upload item remove button
		$dropzone.delegate(".upload-button-remove", "click", function(evt){

			var item;

			// use different selector for array upload
			if (options.fc.arrayupload) {
				item = $(evt.currentTarget).closest("li.sort");
				var confirmText = $(evt.currentTarget).attr("confirmText");
				var removeOnly = $(evt.currentTarget).attr("removeOnly");
			} else {
				item = $(evt.currentTarget).closest(".upload-item");
				$("#" + options.fieldname).val('');
				$("#" + options.fieldname + "-container").addClass("upload-empty");
			};

			var file = uploader.getFile(item.attr("id"));

			//confirm text
			if(confirmText) {
				if(!confirm(confirmText)) {
					return false;
				}
			};	

			// remove file uuid from hidden field or delete the object
			if(options.fc.onFileRemove) {
				options.fc.onFileRemove(item,file,removeOnly);
			};

			if(file) {
				uploader.removeFile(file);
			};
			
			item.remove();
		});

	}

	function onPluploadError(uploader, evt) {

		var file = evt.file;

		if (evt.code == -600) {
			alert("The file '" + file.name + "' is too large.\nPlease upload a file smaller than " + (Math.round(uploader.settings.filters.max_file_size/1024/1024*10) / 10).toFixed(1) + " MB.");
		}
		if (evt.code == -601) {
			// get allowed file extensions
			var fileExtensions = "";
			for (i = 0; i < uploader.settings.filters.mime_types.length; i++) { 
				if (uploader.settings.filters.mime_types[i].title == 'Files') {
					fileExtensions = uploader.settings.filters.mime_types[i].extensions;
				}
			}

			alert("The file '" + file.name + "' is not in the list of allowed file extensions["+fileExtensions+"].");
		}

		// update item status
		var item = $dropzone.find(".upload-item[id='" + file.id + "']");
		item.addClass("upload-item-error")
			.removeClass("upload-item-uploading")
			.find(".upload-item-status").text("Error");

	}

	function onPluploadFilesAdded(uploader, files) {

		var existingFiles = uploader.files.length - files.length;


		if (options.maxfiles != 1 && uploader.files.length > uploader.settings.max_files) {
			// handle the maximum number of files being reached
			alert("You can only add a maximum of " + uploader.settings.max_files + " files");

			// finally, truncate the array
			uploader.splice(existingFiles);
		}
		else {

			$uploader.removeClass("upload-empty");

			if (options.maxfiles == 1) {
				// remove the existing item and replace with the latest item uploaded
				$dropzone.find(".upload-item").remove();

				// keep the first file added
				var fileToKeep = files[0];
				var removeFiles = [];
				// build an array of files to remove
				for (var i=0; i<uploader.files.length; i++) {
					if (uploader.files[i].id != fileToKeep.id) {
						removeFiles.push(uploader.files[i]);
					}
				}
				// remove the files
				for (var i=0; i<removeFiles.length; i++) {
					uploader.removeFile(removeFiles[i]);
				}
				// only allow the first file to be added
				addItem(files[0]);
			}
			else {
				// add all files
				for (var i=0; i<files.length; i++) {
					addItem(files[i]);
				}
			}

		}

	}

	function onPluploadFilesRemoved(uploader, files) {

		if (!uploader.files.length) {
			$uploader.addClass("upload-empty");
		}

		// update completed images data
		updateData();

	}

	function onPluploadQueueChanged(uploader) {

		uploader.start();

	}

	function onPluploadBeforeUpload(uploader, file) {
		var ajaxurl = options.fc.webroot  +  "&view=displayAjaxCDNUniqueFilename";

		// get unique filename from the server
		$.ajax({
			url: ajaxurl,
			type: "POST",
			dataType: "json",
			data: {
				"filename": sanitiseFilename(file.name),
				"nameconflict": options.nameconflict,
				"uploadpath": options.uploadpath,
				"location": options.location
			},
			success: function(response) {

				// update filename in UI
				var item = $dropzone.find("#" + file.id);
				item.find(".upload-item-filename").text(response.uniquefilename);

				// set the unique filename in the file and uploaders
				var uniqueKey = response.uploadpath + "/" + response.uniquefilename;
				file.name = response.uniquefilename;
				uploader.settings.multipart_params.key = uniqueKey;
				uploader.settings.multipart_params.Filename = uniqueKey;
				uploader.settings.multipart_params["Content-Type"] = getMIMEType(file.name);

				// trigger the upload
				file.status = plupload.UPLOADING;
				uploader.trigger("UploadFile", file);

			},
			error: function(error) {
				console.log('onPluploadBeforeUpload', error);
				var item = $dropzone.find("#" + file.id);
				item.removeClass("upload-item-uploading").addClass("upload-item-error").find(".upload-item-status").text("Error");
			}
		});

		return false;
	}

	function onPluploadUploadFile(uploader, file) {

		var item = $dropzone.find("#" + file.id);
		item.addClass("upload-item-uploading").find(".upload-item-status").text("Uploading");

	}


	function onPluploadUploadProgress(uploader, file) {

		// update item progress
		var item = $dropzone.find(".upload-item[id='" + file.id + "']");
		item.find(".upload-item-progress-bar").css("width", file.percent + "%");

	}

	function onPluploadFileUploaded(uploader, file, response) {

		var resourceData = parseAmazonResponse(response.response);

		// update item status
		var item = $dropzone
			.find(".upload-item[id='" + file.id + "']")
			.data("src", resourceData.key)
			.addClass("upload-item-complete")
			.removeClass("upload-item-uploading")
			.find(".upload-item-status")
			.text("Uploaded");

		// update completed images data
		updateData();

		if (options.fc.onFileUploaded) {
			options.fc.targetobjectid = options.fc.onFileUploaded(file,item);
		}

	}

	function onPluploadStateChanged(uploader) {
		if (isUploading()) {
			$uploader.addClass("uploading");
		} else {
			$uploader.removeClass("uploading");
		}
	}


	function isNotUploading() {
		return(uploader.state === plupload.STOPPED);
	}
	function isUploading() {
		return(uploader.state === plupload.STARTED);
	}


	function getItemTemplate(id, name, size) {

		id = id || "";
		name = name || "";
		size = size || "0";

		var item = $(
			  '<div id="' + id + '" class="upload-item">'
			+ '  <div class="upload-item-row">'
			+ '    <div class="upload-item-container">'
			+ '      <div class="upload-item-image"></div>'
			+ '      <div class="upload-item-nonimage"></div>'
			+ '      <div class="upload-item-progress-bar"></div>'
			+ '    </div>'
			+ '    <div class="upload-item-info">'
			+ '      <div class="upload-item-file"><span class="upload-item-filename">' + name + '</span> (' + size +')</div>'
			+ '    </div>'
			+ '    <div class="upload-item-state">'
			+ '      <div class="upload-item-status">Waiting</div>'
			+ '    </div>'
			+ '    <div class="upload-item-buttons">'
			+ '      <button class="upload-button-remove" title="Remove">&times;</button>'
			+ '    </div>'
			+ '  </div>'
			+ '</div>'
		);

		return item;
	}


	function addItem(file) {

		var item;
		// get item template
		if (options.fc.getItemTemplate) {
			item = options.fc.getItemTemplate(file.id, file.name, plupload.formatSize(file.size), options.fc.targetobjectid,options.fc.allow_edit,options.fc.allow_remove);
		} else {
			item = getItemTemplate(file.id, file.name, plupload.formatSize(file.size));
		}

		if (isImageFile(file) && file.size < 10000000) {
			// render a preview for a "small" image (less than 10MB)
			// load image
			var image = $(new Image());
			var preview = new mOxie.Image();
			preview.onload = function() {
				file.width = preview.width;
				file.height = preview.height;
				preview.downsize(300, 300);
				image.prop("src", preview.getAsDataURL());
			};
			preview.load(file.getSource());

			// add image to item
			item.find(".upload-item-image").prepend(image);
		}
		else if (isImageFile(file)) {
			// render a placeholder for a "large" image (more than 10MB)
			item.find(".upload-item-nonimage").css("display", "block").html("<i class='fa fa-picture-o'></i>");
		}
		else {
			// render a placeholder for non-image files
			item.find(".upload-item-nonimage").css("display", "block").html("<i class='fa fa-file-text-o'></i>");
		}

		// add item to dropzone
		$dropzone.append(item)		

	}


	function updateData() {

		var fieldfiles = [];
		var orientation = [];
		var done = 0;
		var errors = 0;

		for (var i=0; i<uploader.files.length; i++) {
			if (uploader.files[i].status == plupload.DONE) {
				// check aspect of image
				var aspect = "horizontal";
				var $img = $("#"+uploader.files[i].id).find(".upload-item-image img");
				if ($img && ($img.height() > $img.width())) {
					aspect = "vertical";
				}

				fieldfiles[i] = options.destinationpart + "/" + sanitiseFilename(uploader.files[i].name);
				orientation[i] = aspect;
				done++;
			}
			if (uploader.files[i].status == plupload.FAILED) {
				errors++;
			}
		}

		if (!options.fc.arrayupload) {
			$("#" + options.fieldname).val(fieldfiles.join("|"));
			$("#" + options.fieldname + "_orientation").val(orientation.join("|"));
		}

		$("#" + options.fieldname + "_filescount").val(done);
		$("#" + options.fieldname + "_errorcount").val(errors);

	}

	function sanitiseFilename(name) {
		return name.replace(/[&\/\\#,+()$~%'":*?<>{}]/g,"").replace(/\s+/g, '-');
	}



	function getMIMEType(name) {
		if (/\.jpe?g$/i.test(name)) {
			return("image/jpeg");
		} else if (/\.png/i.test(name)) {
			return("image/png");
		} else if (/\.gif/i.test(name)) {
			return("image/gif");
		} else if (/\.pdf/i.test(name)) {
			return("application/pdf");
		} else if (/\.epub/i.test(name)) {
			return("application/epub+zip");
		}

		return("application/octet-stream");
	}
	function isImageFile(file) {
		var mimeType = getMIMEType(file.name);
		return(/^image\//i.test(mimeType));

	}


	function parseAmazonResponse(response) {

		var result = {};
		var pattern = /<(Bucket|Key)>([^<]+)<\/\1>/gi;
		var matches = null;

		while (matches = pattern.exec(response)) {
			var nodeName = matches[1].toLowerCase();
			var nodeValue = matches[2];
			result[nodeName] = nodeValue;
		}

		return(result);
	}


}