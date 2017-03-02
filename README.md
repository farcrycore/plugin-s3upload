# S3 Upload Plugin for FarCry Core 7.2.x

This is a temporary plugin which adds two new formtools which support uploading direct to S3.

It includes an `s3upload` formtool for single file properties and an `s3arrayupload` formtool
for array properties (multiple file uploads using related objects).

These features will eventually be integrated into the image and file formtools in Core, so this
plugin is intended as a stop gap alternative until then.

It makes use of the signing and utils portion of the `aws-cfml` library from:
https://github.com/jcberquist/aws-cfml

## Setup

The project must be using S3 for all file storage.

The S3 bucket CORS policy must allow GET and POST for the website domain.