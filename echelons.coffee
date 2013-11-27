
Q = require 'q'
_ = require 'lodash'
sys = require 'sys'

class ResultsCache
  constructor: (queries) ->
    @deferreds = {}
    for key,value of queries
      @deferreds[key] = Q.defer()
  setValues: (queryKey, values) ->
    console.log 'RESOLVED', queryKey, 'WITH', values
    @deferreds[queryKey].resolve values
    values
  values: (queryKey) ->
    @deferreds[queryKey].promise

# Builds a tree structured like the JSON where each node only contains
# an unresolved promise representing the future data for the node.
buildTree = (queries, json, params) ->
  deferred = Q.defer()
  tree = {}
  resultsCache = new ResultsCache(queries)

  tree = buildTreeRecursively queries, json, params, tree, resultsCache

  Q.all(promisesOf(tree)).then (results) ->
    deferred.resolve unwrapResults(tree)
  , (err) ->
    deferred.reject new Error(err)

  deferred.promise

unwrapResults = (tree) ->
  for key of tree when not key.match /^\$/
    tree[key].$result = tree[key].$promise.inspect().value
    delete tree[key].$promise
    unwrapResults tree[key]
  tree

promisesOf = (tree) ->
  promises = []
  promises.push tree.$promise if tree.$promise?
  for key of tree when not key.match(/^\$/)?
    promises = promises.concat promisesOf tree[key]
  promises

buildTreeRecursively = (queriesByKey, json, params, tree, resultsCache) ->
  for key, value of json when not key.match(/^\$/)? and not _.isFunction(value)
    tree[key] = $promise: queriesByKey[key].$query(resultsCache, params)
    jsonObj = if _.isArray(value) then value[0] else value
    buildTreeRecursively queriesByKey, jsonObj, params, tree[key], resultsCache
  tree

Echelons =
  resultTree: (queries, json, params) ->
    buildTree queries, json, params
  topoSort: (queries) ->
    topoSort queries

module.exports = Echelons

