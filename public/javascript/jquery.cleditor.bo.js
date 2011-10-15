(function($) {

  // Define the table button
  $.cleditor.buttons.xxx = {
    name: "xxx",
    image: "gift.png",
    title: "Insert XXX",
    command: "inserthtml",
    popupName: "xxx",
    popupClass: "cleditorPrompt",
    popupContent:         
      "BO: <input id='bo_name' type=text value='doodle' size=8>" +
      "<input type=button value=Submit>",
    buttonClick: xxxButtonClick
  };

  // Add the button to the default controls
  $.cleditor.defaultOptions.controls = $.cleditor.defaultOptions.controls
    .replace("| print ", "xxx | print ");
        
  // Table button click event handler
  function xxxButtonClick(e, data) {

    // Wire up the submit button click event handler
    $(data.popup).children(":button")
      .unbind("click")
      .bind("click", function(e) {

        // Get the editor
        var editor = data.editor;

        // Get the column and row count
        // var $text = $(data.popup).find(":text"),
        //   boname = parseInt($text.value);

		boname = $('#bo_name').val();
        // Build the html
        var html = "&lt;&lt;"+ boname+"&gt;&gt;";

        // Insert the html
        if (html)
          editor.execCommand(data.command, html, null, data.button);

        // Reset the text, hide the popup and set focus
        $text.val("doodle");
        editor.hidePopups();
        editor.focus();

      });
    }
})(jQuery);
