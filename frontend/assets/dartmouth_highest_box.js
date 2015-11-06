// Script to interact with the hightest box number plugin
// This is an *addition* to the container management plugin and must be migrated/checked when that plugin is updated
// See also the template file /container_management/frontend/views/top_containers/_new.html.erb for the code that includes this script

$(document).ready(function() {
	// make the input smaller in width
	$('#top_container_indicator_').parent('div').switchClass('col-sm-9','col-sm-4');
	// add our button and a container for the box number
    $('#top_container_indicator_').parent('div').after('<span id="nextBoxValue" style="display:none"></span><span id="get-highest-box" class="btn btn-primary col-md-3">Get Next Archives Box</span>');
    
    // on click of the newly added button, grab the fragment that contains the box number, make it pretty and insert into the input field
    $('#get-highest-box').click( function() {
    	$.post("/plugins/dartmouth_highest_box/highestBox", 
				{},
				function (data) {
    	    	$('#top_container_indicator_').val(data.boxNumber);
				}
			);
    });
});
