// look at head.js !!!
function  load_javascript(url, callback){

    var script = document.createElement("script")
    script.type = "text/javascript";

    if (script.readyState){  //IE
        script.onreadystatechange = function(){
            if (script.readyState == "loaded" ||
                    script.readyState == "complete"){
                script.onreadystatechange = null;
                callback();
            }
        };
    } else {  //Others
        script.onload = function(){
            callback();
        };
    }

    script.src = url;
    document.getElementsByTagName("head")[0].appendChild(script);

}

function load_css(url){
	
	var final_url;
	
	if( is_local_url(url) ){
		final_url = "/"+url+"?nolayout=y";
	}	
	else{	
		final_url = url;
	}
	
	$("head").append("<link>");
	css = $("head").children(":last");
	css.attr({
	  rel:  "stylesheet",
	  type: "text/css",
	  href: final_url
	});
}

function is_local_url(url){
	return url.toLowerCase().indexOf("http://") != 0 && url.toLowerCase().indexOf("https://") != 0;
}


function currentPageName(){
  return $(".pagebody").attr("pagename");
}

function str(obj){
	return JSON.stringify(obj);
}

function isString(obj){
	return (typeof(obj) == 'string' || typeof(obj) == 'String');
}

function htmlDecode(input){
  var e = document.createElement('div');
  e.innerHTML = input;
  return e.childNodes[0].nodeValue;
}

function imgurl(pagename){
	return Page(pagename).imageURL();
}

function rand(top){
  return Math.floor(Math.random() *top)+1;
}

function pick(ary){
  return ary[ rand(ary.length) ];
}

function deepclone(obj){
  return jQuery.extend(true, {}, obj);
}

function denyaccess(){
	$('.pagebody').remove();
	location.href = '/access-denied';
}

function contains(ary,e){
	for(var i=0; i<ary.length; i++){
		if (e==ary[i]){
			return true;
		}
	}
	return false;
}

function keys(obj){
	return props(obj);
}

function props(obj){
	var p = [];
	for (var e in obj ){
		p.push(e);
	}
	return p;
}

var windowIsActive = true;

window.onblur = function() {
   windowIsActive = false;
};
window.onfocus = function() {
   windowIsActive = true;
};

function isActiveTab(){
	return windowIsActive;
}


// *********** PAGE OBJECT *******************************

function Page(pagename){
	return {
		pagename: pagename,
		
		name: function(){ return this.pagename; },

		imageURL: 		   function(){ return '/pages/'+this.pagename }, 

		URL: 		 	   function(){ return '/'+this.pagename; },
		lookupURL: 	   	   function(){ return '/'+this.pagename+'?lookup=y'; },
		metadataURL: 	   function(){ return '/'+this.pagename+'?metadata=y'; },	
		noLayoutURL: 	   function(){ return '/'+this.pagename+'?nolayout=y'; },
		rawURL: 	   	   function(){ return '/'+this.pagename+'?raw=y'; },
		editURL: 	 	   function(){ return '/'+this.pagename+'/edit'; },
		appendsynchURL:    function(){ return '/'+this.pagename+'/append'; },
		synchronizeURL:    function(){ return '/'+this.pagename+'/synchronize'; },
		realtimesynchURL:  function(){ return '/'+this.pagename+'/realtime-synch'; },
		savetagsURL: 	   function(){ return '/'+this.pagename+'/savetags'; },	
		subpagesURL:       function(){ return '/'+this.pagename+'?listsubpages=y'; },
	    
		html_link: 	       function(){ return "<a href='"+this.URL()+"'>"+this.pagename+"</a>" }, 

		lookup: function(callbackFunc){
			var parameters = {};
			parameters['currentpagename'] = currentPageName();

		    $.ajax({
		      url: this.lookupURL(),
			  data: parameters,
		      success: callbackFunc
		    });
		},

		loadContent: function(){
			if ( arguments.length == 2) {
				var parameters = arguments[0];
				var successFunc = arguments[1];
			}else if (arguments.length == 1){
				var parameters = {};
				var successFunc = arguments[0];
			}else if (arguments.length == 0){
				var parameters = {};
				var successFunc = function(){};
			}

			parameters['currentpagename'] = currentPageName();

		    $.ajax({
		      url: this.noLayoutURL(),
			  data: parameters,
		      success: successFunc
		    });
		},

		loadRaw: function(){
			if ( arguments.length == 2) {
				var parameters = arguments[0];
				var successFunc = arguments[1];
			}else if (arguments.length == 1){
				var parameters = {};
				var successFunc = arguments[0];
			}else if (arguments.length == 0){
				var parameters = {};
				var successFunc = function(){};
			}

		    $.ajax({
		      url: this.rawURL(),
			  data: parameters,
		      success: successFunc
		    });
		},

		load: function(){
			if ( arguments.length == 2) {
				var parameters = arguments[0];
				var successFunc = arguments[1];
			}else if (arguments.length == 1){
				var parameters = {};
				var successFunc = arguments[0];
			}else if (arguments.length == 0){
				var parameters = {};
				var successFunc = function(){};
			}

			parameters['currentpagename'] = currentPageName();
			
		    $.ajax({
			  type: 'POST',
		      url: this.noLayoutURL(),
			  data: parameters,
		      success: successFunc
		    });
		
		},

		subpages: function(pagesLoadedCb){
			$.ajax({
		      url: this.subpagesURL(),
		      success: function(d){ 
				pagesLoadedCb( JSON.parse(d) ); 
			  }
		    });
		},
		
		getJSON: function(){
			if ( arguments.length == 2) {
				var parameters = arguments[0];
				var loadedCb = arguments[1];
			}else if (arguments.length == 1){
				var parameters = {'nolayout':'y'};
				var loadedCb = arguments[0];
			}else if (arguments.length == 0){
				var parameters = {'nolayout':'y'};
				var loadedCb = function(){};
			}

			$.ajax({
		      url: this.URL(),
			  data: parameters,
		      success: function(d){ loadedCb( JSON.parse(d) ); }
		    });
		},

		loadMetadata: function(loadedCb){
		    $.ajax({
		      url: this.metadataURL(),
		      success: function(metadata){ loadedCb( JSON.parse(metadata) )}
		    });
		},
		
		loadTags: function(loadedCb){
			this.loadMetadata(function(md){ 
				if ("tags" in md){
				    loadedCb( md.tags.split(',') );
				}else{
					loadedCb( [ ] );
				}
			});			
		},

		saveTags: function(tags,cbUpdatedPage){
			$.post(
				this.savetagsURL(),
			    [
			       {name:'tags',value:tags} 
			    ],
				cbUpdatedPage,
			    'text'
			);
		},
		
		update: function(formatpagename,body,cbUpdatedPage){
			$.post(
				this.editURL(),
			    [
			       {name:'title',value:this.pagename}, 
			       {name:'format',value:formatpagename}, 
			       {name:'body',value:body}
			    ],
				cbUpdatedPage,
			    'text'
			);
		},
			
		appendsynch: function(newdata,cbUpdatedPage){
			$.post(
				this.appendsynchURL(),
			    [ {name:'data',value:newdata} ],
				cbUpdatedPage,
			    'text'
			);
		},
		
		synchronize: function(version,cbUpdatedPage){
			$.post(
				this.synchronizeURL(),
			    [ {name:'timestamp',value:version} ],
				cbUpdatedPage,
			    'text'
			);
		},	
		
		realtimeSynch: function(version,cbUpdatedPage){
			$.post(
				this.realtimesynchURL(),
			    [ {name:'timestamp',value:version} ],
				cbUpdatedPage,
			    'text'
			);
		}	
			
	}
}


function isCodeFormat(format){
	return format=='javascript' || format=='template';
}

// *********** EXECUTE A MIKINUGGET *******************************

function executeNugget(username,version,pagename,formatpagename,formatpageFunc,id,paramstxt,codepagename){
	if ( isCodeFormat(formatpagename) ){
		var nugget = Nugget('',username,version,pagename,formatpagename,formatpageFunc,id,paramstxt,codepagename);
    	formatpageFunc( nugget );
		nugget.appendNuggetDisplay();
	}else{
		Page(pagename).loadContent(function(modeldata) {
			var nugget = Nugget(modeldata,username,version,pagename,formatpagename,formatpageFunc,id,paramstxt,codepagename)
	    	formatpageFunc( nugget );
			nugget.appendNuggetDisplay();
	    });
	}
}

function Nugget(modeldata,username,version,pagename,formatpagename,processPageFunc,id,paramstxt,codepagename){
	return {
		pagename: pagename,
		page: Page(pagename),
		formatpagename: formatpagename,
		codepagename: codepagename,
		topPage: function(){
			return Page( this.topenvelopePagename() ); 
		},
		id: id,
		uniquename: function(){ return this.id.substr(1,this.id.length-1) },
		generate_uniqid: function(){ return this.username + "-" + new Date().getTime() },
		raw: modeldata,
		extension_text: paramstxt,
		username: username,
		version: version,
		$: function(selector){ return $(this.id + ' ' + selector); },
		isDataPage: function(){
			return isCodeFormat(this.formatpagename);
		},
		CodePage: function(){ return this.isDataPage() ? Page(this.codepagename) : Page(this.formatpagename) },

		// _default_data: null,
		// 
		// setDefaultData: function(defaultdata){
		// 	this._default_data = defaultdata;
		// },
		// 
		
		data: function(defaultdata){
			if (this.raw == '' && this.extension_text == ''){
				return datadecode( (defaultdata || this._default_data || "[ ]"), "" )
			}else{
				return datadecode(this.raw,this.extension_text);
			}
		},
		
		xmldata: function(){
	           return $.xml2json( this.raw );
	       },
		
		singledata: function(defaultdata){
			return this.data(defaultdata)[0];
		},
		
		updateJSON: function(jsdata){ 
			this.update( isString(jsdata) ? jsdata : JSON.stringify(jsdata) );
		},
		updateTable: function(tdata){
			this.update( isString(tdata) ? tdata : tablify(tdata) );
		},
		
		appendsynchJSON: function(data){
			var self = this;
			
			var handleResponse = function(jsd){
				var d = JSON.parse(jsd);
				self.version = d.version;
				self.afterUpdating(d.data);
			}

			if ( this.isDataPage() ){
				Page( this.topenvelopePagename() ).appendsynch( JSON.stringify(data), handleResponse); 
			}else{
				this.page.appendsynch( JSON.stringify(data), handleResponse); 
			}
		},
	    
		synchronizeJSON: function(){
			var self = this;
			
			var handleResponse = function(jsd){
				if (jsd != ''){
					d = JSON.parse(jsd);
					self.version = d.version;
					self.afterUpdating(d.data);
				}
			}
			
			if ( this.isDataPage() ){
				Page( this.topenvelopePagename() ).synchronize(this.version, handleResponse); 
			}else{
				this.page.synchronize(this.version, handleResponse); 
			}
		},
		
		synchronizeJSONevery: function(usec){
			this.synchronizeJSON();
			var self = this;
			$.doTimeout( usec, function(){
				if ( isActiveTab() ){
				  self.synchronizeJSON();
				}
			  	return true;
			});
		},
		
		// ============================= REALTIME DISTRIBUTED OBJECTS SYNCHRONIZATION ============================
		_world_local: {},
		
		_realtimeSynch: function(callback){
			var self = this;
			
			var handleResponse = function(jsd){
				if (jsd != ''){
					d = JSON.parse(jsd);
					// alert("time to synch with server - nugget: "+self.version+" - server: "+d.version);
					self.version = d.version;
					self._localUpdateFromServer(d.data);
				}
			}
			
			if ( this.isDataPage() ){
				Page( this.topenvelopePagename() ).realtimeSynch(this.version, handleResponse); 
			}else{
				this.page.realtimeSynch(this.version, handleResponse); 
			}
		},
		
		realtimeSynchEvery: function(usec){
		  this._realtimeSynch();
		  var self = this;
		  $.doTimeout( usec, function(){
		    if ( isActiveTab() ){
		      self._realtimeSynch();
		    }
		    return true;
		  });
		},

		_localUpdateFromServer: function(world_remote){
		  for(rId in world_remote){
		    if (rId in this._world_local){
			  if ( !('update' in this._world_local[rId]) || this._world_local[rId].update.time == "" ) {
			    this._world_local[world_remote[rId].id] = world_remote[rId];
		
			  } else if ( (world_remote[rId].update.time - this._world_local[rId].update.time) > 1){
		        this._local_update_item(world_remote[rId]);
		      }
		    }else{
		      this._local_add_item(world_remote[rId]);
		    }
		  }

		  for(lId in this._world_local){
		    if ( !(lId in world_remote) ){
		      this._local_delete_item(lId);
		    }
		  }
		},
		
		_local_add_item: function( obj ){
		  this._world_local[obj.id] = obj;
		  this.canvas_add_item(obj);
		},

		_local_update_item: function( obj ){
		  this._world_local[obj.id] = obj;
		  this.canvas_update_item(obj);
		},

		_local_delete_item: function( id ){
		  delete this._world_local[id];
		  this.canvas_delete_item(id);
		},

		item: function(id){
			return this._world_local[id];
		},

		sharedspace_add_item: function( obj ){
		  obj['id'] = this.generate_uniqid();
		
		  this._local_add_item(obj);
		  this._world_remote_apply( {action:'create',item:obj} );
		},

		sharedspace_update_item: function( obj ){
		  if (!("update" in obj)){
			obj["update"] = {"time":"","username":this.username};
		  }
		  this._local_update_item(obj);
		  this._world_remote_apply( {action:'update',item:obj} );
		},

		sharedspace_delete_item: function( id ){
		  this._local_delete_item(id);
		  this._world_remote_apply( {action:'delete',item:{id: id}} );
		},

		_world_remote_apply: function(action){
			var nugget = this;

		    $.post(
		      '/'+this.pagename+'/realtime-action',
		      [ {name:'data',value:JSON.stringify(action)} ],
		      function(new_world_version){ 
				
				if (new_world_version != '') {
					nugget.version = new_world_version;
				}
			  },
		      'text'
		    );
		  },
		
		// ---- must be overridden by user -----
		canvas_add_item: function(obj){},
		canvas_update_item: function(obj){},
		canvas_delete_item: function(id){},
		
		// ============================= ============================== ============================
		
		update: function(data){
			if ( this.isDataPage() ){

				if ( this.envelope().attr('data_page_as_content_page')=='true' ){
					// this is a data page rendered as a normal page. saving should be done normally at the page path
					Page( this.topenvelopePagename() ).update(this.CodePage().name(), data, this.afterUpdating); 
				}else{
					// this is an anonymous meta bo embedded in a page. it should not save because it doesnt have a data page
					//  future work: make it generate a datapage on the spot.
					alert("SAVING DISABLED - embedded anonymous meta-bo has no data page - future work: make it generate a datapage on the spot");
				}
				
			}else{
				// Normal Page
				this.page.update(this.CodePage().name(), data, this.afterUpdating); 
			}
		},
		afterUpdating: function(){ },

		_out: '',
		out: function(txt){ this._out = this._out + txt; },
		outReset: function(){ this._out = ''},

		appendNuggetDisplay: function(){
			
			var outputFormatPagename = $('<a/>').attr('href','/'+this.CodePage().name()+'/edit').html('/'+this.CodePage().name());

			var parentname = this.envelopes().attr('pagename');

			var outputDataPagename = (this.pagename && this.pagename != '') ? 
										$('<a/>').attr('href','/'+pagename+'/edit').html('/'+pagename) : 
										"<a href='/"+parentname+"/edit'>Embedded in page</a>";

			$(this.id).parent().append( 
				$("<span>FORMAT: </span>").addClass('nugget-annotation').append( outputFormatPagename ) 
			).append(
				$("<span>DATA: </span>").addClass('nugget-annotation').append( outputDataPagename ) 
			); 
			
		},

		_fullyExploded: function(txt){
			var nuggetExp = /<<.+?>>/;
			var sugarExp  = /\[\[.+?\]\]/;
			var hExp 	  = /\n\*/;
			var bExp 	  = /\*\*(([a-z\xC0-\xFF]|.)*)\*\*/;
			//	var iExp 	  = /__(([a-z\xC0-\xFF]|.)*)__/ ;

			return ( !nuggetExp.test(txt) ) && 
				   ( !sugarExp.test(txt) ) 	&&
				   ( !hExp.test(txt) ) 		&&
				   ( !bExp.test(txt) );

			// removed because it clashes with doubleunderscore of history files!
			// && ( !iExp.test(txt) );
		},
		
		setHTML: function(txt){ 
			if (txt == undefined){
				var output = this._out; 
			}else{
				var output = txt; 
			}

			var self = this;
			
			if ( this._fullyExploded(output) ){
				$(this.id).html( output );
			}else{
				Page('explode').load({body:output,context:this.topenvelopePagename()},function(content){
					self.setHTML( content );
				});
			}
		},
		
		templateExpansion: function(css_id){
		    var map = this.data();
		    var txt_raw = $(css_id).html();
			var txt = htmlDecode(txt_raw);
			
		    for (var k in map) {
		      txt = txt.replace(new RegExp("@"+k+"@", "gm"),map[k]);
		    }

			// this substitutes the full data
			var all_data = removeAccidentalDoubleSquareBrackets(JSON.stringify(map));
		    txt = txt.replace( new RegExp("@@", "gm"), all_data );

		    this.setHTML(txt);
		},
		
		envelope: function(){
			return $(this.id).closest('.envelope');
		}, 
		
		// try to substitute the use of this with topenvelopePagename()
		envelopes: function(){
			return $(this.id).parents('.envelope');
		}, 
		
		topenvelopePagename: function(){
			return $(this.id).closest('.pagebody').attr('pagename');
		},
		
		isRunningInSidebar: function(){
			return $(this.id).closest('.env_embed').html() != null;
		}
		
	};
}


// *********** MODIFY INTERFACE *******************************

function appendControlButton(html){
	$('.controls').append('<li>'+html+'</li>');
}


// *********** SUPPORT TABULAR FORMAT *******************************

function tabular_parse(text){
	var out = [];
	
	var lines = text.split("\n");
	for (var l=0;l<lines.length;l++){
		var fields = lines[l].split(",");
		var cleanfields = [];
		for (var f=0;f<fields.length;f++){
			cleanfields.push( $.trim(fields[f]) );
		}
		out.push( cleanfields );
	}

	// if [[xxx]] case, then remove external brackets and make simple array [xxx]
	if (out.length == 1 ){
		out = out[0];
	}
	
	return out;
}

function tablify(ary){
	var out = '';
	
	if ( jQuery.isArray(ary[0]) ) {
		// it's a table
		for (var row in ary){
			out = out + row.join(", ") + "\n"
		}
	}else{
		// it's an array
		out = ary.join("\n");
	}
	
	return out;
};


function datadecode(base,extension){
	// try to interpret base data as json
	// if json decode fails..
	// try to interpret base data as table and make a json out of it
	var basedata = (base == '') ? null : singledatadecode(base);

	// do the same for extension data
	var extensiondata = (extension == '') ? null : singledatadecode(extension);
	
	if (basedata == null && extensiondata == null) {
		return [];
	} else if (basedata == null && extensiondata != null){
		return extensiondata;
	} else if (basedata != null && extensiondata == null){
		return basedata;
	} else {
		// merge base and extension data (now both json) using either a merge or extend
		if ( $.isArray(basedata) && $.isArray(extensiondata) ){
			// if both are array.. sum them
			return $.merge( basedata, extensiondata );
		}else if ( $.isPlainObject(basedata) && $.isPlainObject(extensiondata) ){
			// if both are hashes.. merge them
			return $.extend( basedata, extensiondata );
		}else if ( $.isPlainObject(basedata) && $.isArray(extensiondata) ){
			// if one is array and one is hash.. merge them, using array numbers as keys
			return $.extend( basedata, extensiondata );
		}else if ( $.isArrayObject(basedata) && $.isPlainObject(extensiondata) ){
			// if one is array and one is hash.. merge them, using array numbers as keys
			return $.extend( extensiondata, basedata );
		}
	}
}

function singledatadecode(data){
	var jsondata;
	
	try{
		jsondata = JSON.parse(data)
	}catch(e){
		jsondata = tabular_parse(data)
	}
	
	return jsondata;
}

// if you output a json containing a [[ ]] then it will be interpreted as miki syntax. make sure this doesn't happen.
function removeAccidentalDoubleSquareBrackets(txt){
	return txt.replace(/\[/g,' [ ').replace(/\]/,' ] ');
}


