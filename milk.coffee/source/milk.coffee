# The MIT License
# Copyright © 2012, CogniTom Academic Design & Tsutomu Kawamura.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of 
# this software and associated documentation files (the “Software”), to deal in 
# the Software without restriction, including without limitation the rights to use, 
# copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the 
# Software, and to permit persons to whom the Software is furnished to do so, 
# subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

milk = 
	guid: ->
		'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
			r = Math.random() * 16 | 0
			v = if c is 'x' then r else r & 3 | 8
			v.toString 16
		.toUpperCase()

class Template
	@values:
		meta: {} # META tag properties of the original document
		ajax: {} # Data requested via Ajax 
		hsql: {} # Data requested via hSQL
		
	@placeholders: {}
		
	@setup: ->
		$('meta').each (index) ->
			Template.values.meta[$(@).attr('name').replace /[^a-zA-Z0-9_]/g, '_'] = $(@).attr('content') if $(@).attr('name')?
			console?.log Template.values
	
	@ajax: (name, uri) ->
		console?.log "ajax request : #{uri}"
		$.getJSON(uri)
		.success (data) =>
			@setValue name, data
			@processPlaceholder name
		.error ->
			console?.log "ajax error"
	
	@hsql: (name, hsql) ->
		console?.log "hsql request : #{hsql}"
		$.getJSON("/hsql.php?q=#{hsql}")
		.success (data) =>
			console?.log data
			@setValue name, data
			@processPlaceholder name
		.error ->
			console?.log "hsql error"
	
	@fetch: (html) ->
		for meta in html.match /<meta.*? name="milk:[a-z][a-zA-Z0-9\.]+".*?>/gim
			name = ($(meta).attr 'name').split(':')[1]
			content = $(meta).attr 'content'
			if name.match /^ajax/
				@ajax name, content
			else if name.match /^hsql/
				@hsql name, content
	
		t = template = new Template
		t = t.add flagment for flagment in html.split /(<!--\{.+?\}-->|\#\{.+?\})/gim when flagment?
		#console?.log template
		template.display()
		
	@valueExists: (combinedKey) ->
		attrs = combinedKey.split '.'
		tv = Template.values
		tv = tv[attr] ? null while tv? and attr = attrs.shift()
		tv?
		
	@setValue: (combinedKey, val) ->
		attrs = combinedKey.split '.'
		lastattr = attrs.pop()
		tv = Template.values
		tv = tv[attr] ? '' while attr = attrs.shift()
		tv[lastattr] = val

	@setValues: (vals) -> Template.values[key] = val for own key, val of vals
		
	@getValue: (combinedKey) ->
		attrs = combinedKey.split '.'
		tv = Template.values
		tv = tv[attr] ? '' while attr = attrs.shift()
		tv
		
	@addPlaceholder: (name, callback) ->
		@placeholders[name] = callback
		
	@processPlaceholder: (name) ->
		if @placeholders[name]?
			@placeholders[name]()
			delete @placeholders[name]

	constructor: (@parent = null, @value = '', @ignore = false) ->
		@children = []
		
	add: (value) ->
		re = 
			pend: /<!--\{end\}-->/
			more: /<!--\{more\}-->/
			pvar: /<!--\{(@[a-zA-Z0-9_\.\#>=\[\]]+|[a-zA-Z][a-zA-Z0-9_\.]*)\}-->/
			ivar: /\#\{(@[a-zA-Z0-9_\.\#>=\[\]]+|[a-zA-Z][a-zA-Z0-9_\.]*)\}/
			loop: /<!--\{[a-zA-Z][a-zA-Z0-9_\.]* in (@[a-zA-Z0-9_\.\#>=\[\]]+|[a-zA-Z][a-zA-Z0-9_\.]*)\}-->/
		if value.match re.pend then @ignore = false; @parent
		else if value.match re.more then @ignore = true; @
		else unless @ignore
			if value.match re.pvar then @_add 'child', new TemplateVar @, value.replace(/<!--{|}-->/g, ''), true
			else if value.match re.ivar then @_add 'self', new TemplateVar @, value.replace /\#\{|\}/g, ''
			else if value.match re.loop then @_add 'child', new TemplateLoop @, value.replace /<!--{|}-->/g, ''
			else @_add 'self', new TemplateText @, value
		else  @
	_add: (ret, t) ->
		@children.push t
		switch ret
			when 'child' then t
			when 'self' then @
	display: (localValues = {}) -> (child.display localValues for child in @children).join ''
	
class TemplateLoop extends Template
	display: (localValues) ->
		@placeholder_id = milk.guid()
		[elName, arrName] = @value.split /\s+in\s+/
		if Template.valueExists arrName
			@displayLoop localValues, elName, arrName
		else if arrName.match /^(ajax|hsql)\./
			@diaplayPlaceholder localValues, elName, arrName
		else
			console?.log 'Template value not found.'
			''
	displayLoop: (localValues, elName, arrName) ->
		(for el in Template.getValue arrName
			(for child in @children
				lv = {}
				lv[key] = val for key, val of localValues
				lv[elName] = el
				child.display lv
			).join ''
		).join ''
	diaplayPlaceholder: (localValues,　elName, arrName) ->
		Template.addPlaceholder arrName, =>
			html = @displayLoop localValues, elName, arrName
			$("##{@placeholder_id}").before(html).remove()
		"""<span class="loading" id="#{@placeholder_id}"></span>"""
	
class TemplateVar extends Template
	display: (localValues) ->
		@localValues = localValues
		if @value[0] == '@' then @displayDom() else @displayVar()
	displayDom: -> $(@value.substring 1).html()
	displayVar: -> (@getLocalValue @value) or Template.getValue @value
	getLocalValue: (combinedKey) ->
		attrs = combinedKey.split '.'
		tv = @localValues
		tv = tv[attr] ? '' while attr = attrs.shift()
		tv
	
class TemplateText extends Template
	display: -> @value
		

Template.setup()
href = $('link[rel=template]').attr('href')
$.ajax
	url: href,
	success: (html)->
		html = Template.fetch html
		$('html').html (html.split /(<html.*?>|<\/html>)/ig)[2]