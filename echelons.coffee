
Q = require 'q'
_ = require 'lodash'

class Context
  constructor: ->
    @results = {}
  setValues: (queryKey, values) ->
    @results[queryKey] = values
  values: (queryKey, column) ->
    _(@results[queryKey]).pluck column

chainLeads = (queries, {from, to}) ->
  return false if from.length is 0
  return true if _.any from, (dep) -> dep is to
  for dep in from
    leads = chainLeads queries, from: queries[dep].$deps or [], to: to
    return true if leads
  false

topoSortComparator = (queries) ->
  (queryA, queryB) ->
    if chainLeads(queries, from: queries[queryA.key].$deps or [], to: queryB.key)
      1
    else if chainLeads(queries, from: queries[queryB.key].$deps or [], to: queryA.key)
      -1
    else
      0
    
topoSort = (queries) ->
  (key: key for key of queries).sort topoSortComparator(queries)

buildTree = (queries, json, params) ->
  deferred = Q.defer()
  tree = {}
  context = new Context()

  tree = buildTreeRecursively queries, json, params, tree, context

  console.log 'finished buildTreeRecursively '

  Q.allSettled(promisesOf(tree)).then (results) ->
    console.log 'resolved all promises', results
    deferred.resolve unwrapResults(tree)
    console.log 'got here'
  , (err) ->
    console.log 'failed to resolv all promises'
    deferred.reject new Error(err)

  deferred.promise

unwrapResults = (tree) ->
  for key of tree when not key.match /^\$/
    tree[key].$result = tree[key].$promise.value  # TODO get the value from here
    delete tree[key].$promise
    unwrapResults tree[key]
  tree

promisesOf = (tree) ->
  promises = []
  for key of tree when not key.match /^\$/
    promises.push tree[key].$promise
    promises.concat promisesOf tree[key]
  promises

promisesFor = (deps, queries, context, params) ->
  promises = []
  for dep in deps
    do (dep) ->
      promises.concat promisesFor(queries[dep].$deps or [], queries, context, params)
      queryResultPromise = queries[dep].$query(context, params).then (result) ->
        console.log 'resolved queryResultPromise'
        context.setValues dep, result
      , (err) ->
        console.log 'WTF!!', err
      promises.push queryResultPromise
  promises

buildTreeRecursively = (queries, json, params, tree, context) ->
  for key, value of json when not key.match(/^\$/)? and not _.isFunction(value)
    queryObj = queries[key]
    promise = Q.all promisesFor(queryObj.$deps or [], queries, context, {})
    promise.then ->
      console.log 'resolved promise for all deps'
    , (err) ->
      console.log 'failed to resolve promise for all deps'
    tree[key] = { $promise: promise }
    jsonObj = if _.isArray(value) then value[0] else value
    buildTreeRecursively queries, jsonObj, params, tree[key], context
  tree

Echelons =
  resultTree: (queries, json, params) ->
    buildTree queries, json, params
  topoSort: (queries) ->
    topoSort queries


module.exports = Echelons

