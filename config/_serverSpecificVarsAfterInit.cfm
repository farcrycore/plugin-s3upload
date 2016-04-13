<cfsetting enablecfoutputonly="yes">
<!--- @@Copyright: Daemon Pty Limited 2002-2008, http://www.daemon.com.au --->
<!--- @@License:
    This file is part of FarCry.

    FarCry is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    FarCry is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with FarCry.  If not, see <http://www.gnu.org/licenses/>.
--->

<!--- THIS WILL BE INCLUDED AFTER THE FARCRY INIT HAS BEEN RUN BUT ONLY ON APPLICATION INITIALISATION. --->


<cfimport taglib="/farcry/core/tags/farcry" prefix="farcry" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

<skin:registerJS id="s3uploadJS" lFiles="/farcry/plugins/s3upload/www/js/plupload-2.1.8/js/plupload.full.min.js,/farcry/plugins/s3upload/www/js/s3upload.js" />
<skin:registerCSS id="s3uploadCSS" lFiles="/farcry/plugins/s3upload/www/css/s3upload.css" />     

<cfsetting enablecfoutputonly="no">