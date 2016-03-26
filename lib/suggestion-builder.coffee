{Range} = require 'atom'
{filter} = require 'fuzzaldrin'

module.exports=
class SuggestionBuilder
  typeScope: ['meta.type-signature.haskell']
  sourceScope: ['source.haskell']
  moduleScope: ['meta.import.haskell', 'support.other.module.haskell']
  preprocessorScope: ['meta.preprocessor.haskell']
  exportsScope: ['meta.import.haskell', 'meta.declaration.exports.haskell']

  pragmaWords: [
    'LANGUAGE', 'OPTIONS_GHC', 'INCLUDE', 'WARNING', 'DEPRECATED', 'INLINE',
    'NOINLINE', 'ANN', 'LINE', 'RULES', 'SPECIALIZE', 'UNPACK', 'SOURCE'
  ]

  constructor: (@options, @backend) ->
    @buffer = @options.editor.getBuffer()
    @lineRange = new Range [@options.bufferPosition.row, 0],
      @options.bufferPosition
    @line = @buffer.getTextInRange @lineRange
    @mwl =
      if @options.activatedManually
        0
      else
        atom.config.get('autocomplete-plus.minimumWordLength')

  lineSearch: (rx, idx = 0) =>
    @line.match(rx)?[0] or ''

  isIn: (scope) ->
    scope.every (s1) =>
      s1 in @options.scopeDescriptor.scopes

  getPrefix: (rx = /[\w.']+$/) =>
    prefix = @lineSearch rx
    return prefix

  buildSymbolSuggestion: (s, prefix) ->
    text: s.qname ? s.name
    rightLabel: s.module?.name
    type: s.symbolType
    replacementPrefix: prefix
    description: s.name + " :: " + s.typeSignature

  buildSimpleSuggestion: (type, text, prefix, label) ->
    text: text
    type: type
    replacementPrefix: prefix
    rightLabel: label

  processSuggestions: (f, rx, p) =>
    if typeof(rx) is 'function'
      p = rx
      rx = undefined
    prefix = @getPrefix(rx)
    if prefix.length < @mwl
      return []
    f @buffer, prefix, @options.bufferPosition
      .then (symbols) -> symbols.map (s) -> p s, prefix

  symbolSuggestions: (f) =>
    @processSuggestions f, @buildSymbolSuggestion

  moduleSuggestions: =>
    @processSuggestions @backend.getCompletionsForModule, (s, prefix) =>
      @buildSimpleSuggestion 'import', s, prefix

  preprocessorSuggestions: =>
    kw = @lineSearch /\b(LANGUAGE|OPTIONS_GHC)\b/
    return [] unless kw?
    label = ''
    rx = undefined
    if kw == 'OPTIONS_GHC'
      rx = /[\w-]+$/
      label = 'GHC Flag'
      f = @backend.getCompletionsForCompilerOptions
    else if kw == 'LANGUAGE'
      label = 'Language'
      f = @backend.getCompletionsForLanguagePragmas
    else
      label = 'Pragma'
      f = (b, p) => Promise.resolve(filter @pragmaWords, p)

    @processSuggestions f, rx, (s, prefix) =>
      @buildSimpleSuggestion 'keyword', s, prefix, label

  getSuggestions: =>
    if @isIn(@typeScope)
      @symbolSuggestions @backend.getCompletionsForType
    else if @isIn(@moduleScope)
      @moduleSuggestions()
    else if @isIn(@exportsScope)
      @symbolSuggestions @backend.getCompletionsForSymbolInModule
    else if @isIn(@preprocessorScope)
      @preprocessorSuggestions()
    #should be last as least sepcialized
    else if @isIn(@sourceScope)
      if @getPrefix().startsWith '_'
        if atom.config.get('autocomplete-haskell.ingoreMinimumWordLengthForHoleCompletions')
          @mwl = 1
        @symbolSuggestions @backend.getCompletionsForHole
      else
        @symbolSuggestions @backend.getCompletionsForSymbol
    else
      []
