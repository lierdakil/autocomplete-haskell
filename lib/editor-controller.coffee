_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'

module.exports=
class EditorController
  constructor: (@editor) ->
    @modules=[]
    @symbols=[]
    @subscriptions = new CompositeDisposable
    @subscriptions.add @editor.onDidStopChanging @checkImportedModules
    @subscriptions.add @editor.onDidDestroy @destroy
    @checkImportedModules

  destroy: =>
    @editor = null
    @subscriptions.dispose()

  checkImportedModules: =>
    modules=[]
    regex=/^import\s+(?:qualified\s+)?([\w.]+)/gm
    r = @editor.getBuffer().getRange()
    @editor.backwardsScanInBufferRange regex, r, ({match}) ->
      modules.push(match[1])
    unless _.isEqual(modules,@modules)
      @modules=modules
      @updateModuleSymbols()

  updateModuleSymbols: ->
    atom.services.consume "haskell-ghc-mod", "0.1.0", (gm) =>
      gm.browse @modules,(data)=>
        @symbols=data

  getSuggestions: (options,info)->
    sb=new SuggestionBuilder(options,info,this)
    sb.getSuggestions()
