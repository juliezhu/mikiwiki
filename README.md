MIKIWIKI is a programmable wiki. 
At its simplest, MIKIWIKI supports simple wiki pages organized in a tree structure.

Wiki pages can also embed other pages as components called Nuggets. 
These nuggets can be programmed in javascript from within the MIKIWIKI itself.

All MIKIWIKI pages have a FORMAT. The standard format is MIKI, but you can invent new formats.
A page with a new format will contain JSON data and its format page will have format 'javascript' or 'template' and will know how to render the JSON data.

Look at the 'sample' folder for examples.

Your admin username is 'admin' and the password is 'admin'. 
I advise you to change the password by editing the users/private/admin page.

You run mikiwiki by doing:

> ruby mikiwiki.rb


Installation and usage
======================

1) install ruby 
http://www.ruby-lang.org/en/downloads/

2) install sinatra
http://www.sinatrarb.com/

3) some gems to install:
In order to notify other users via email, you also need to install pony gem 
https://github.com/adamwiggins/pony


Database
========
No database is needed. We use plain files for storage.


Editing Pages
=============
When you edit a 'miki' page you have access to a Rich Editor. 
If you don't like it, click the rightmost icon in the rich editor to switch to simple text editing. 

Some Syntax
===========

[[a_page_name]] - links to a page

[[include:a_page_name]] - imports a page

[[expand:a_page_name]] - creates an expandable link to a page

*some text* - makes the text bold

\<\<a_nugget_name\>\> - imports a nugget

\<\<a_nugget_name: some_nugget_data\>\> - passes some configuration information to a nugget

\<\<a_nugget_name: {"this is":"some JSON"}\>\> - passes some configuration information to a nugget as JSON data

\<\<a_nugget_name as a_format\>\> - imports a nugget and ovverides its format


New Users
=========

1) to create a new user account
Just clone the /users/admin page and change its content appropriately.
Also clone the /users/private/admin page and change the password within it.

Warnings
========

//Warning: You need your own API key in order to use the Google Loader. In the example below, replace "INSERT-YOUR-KEY" with your own key. Without your own key, these examples won't work.

load_javascript("https://www.google.com/jsapi?key=INSERT-YOUR-KEY",function(){});

Bugs
====

1) when you create syn-image note, <<datapage_name as syn-imagenote>>, the data page is automated created yet without any content. You need to manually open it and add curly brackets {} in the data page. Otherwise, you won’t be able to save any data. 

2) the 'allow' nugget is not fully functional 

3) you can preview the data page normally, but when the content has an apostrophe, which breaks the view of the data page.


