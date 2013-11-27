
Q     = require 'q'
PG    = require 'pg'
Knex  = require 'knex'
_     = require 'lodash'

knex = Knex.initialize
  client: 'pg'
  connection:
    host: 'localhost'
    database: 'wift_sports'

# The model

queries =
  book:
    $query: ->
      Knex('book')
        .where(betting_status: 'Open')
        .orWhere(betting_status: 'Suspended')
        .column([
          'id'
          'name'
          'short_name'
          'close_time'
          'betting_status'
          'information_message'
        ])
        .order('close_time')
        .select()
  source:
    $deps: ['book']
    $query: (context, params) ->
      Knex('source')
        .whereIn('id', context.values('book', 'source_id'))
        .where('name', params.jurisdiction)
        .select()
  sport:
    $deps: ['book']
    $query: ->
      Knex('sport')
        .column('id', 'display_priority')
        .order('display_priority')
        .select()
  sportCode:
    $deps: ['sport']
    $query: (context, params) ->
      Knex('sport_code').column('id', 'displayName', 'name')
        .whereIn('id', context.values('sport', 'id'))
        .where(name: params.sportName)
        .select()
  competition:
    $deps: ['sport', 'book', 'source']
    $query: (context, params) ->
      Knex('competition').column('id', 'name')
        .whereIn(source_id: context.values('source', 'id'))
        .whereIn(sport_id: context.values('sport', 'id'))
        .whereIn(id: context.values('book', 'competition_id'))
        .where(name: params.competitionName)
        .order('priority')
        .select()
  tournament:
    $deps: ['sport', 'book', 'source']
    $query: (context, params) ->
      Knex('competition').column('id', 'name', 'priority')
        .whereIn(source_id: context.values('source', 'id'))
        .whereIn(sport_id: context.values('sport', 'id'))
        .whereIn(id: context.values('book', 'tournament_id'))
        .where(name: params.tournamentName)
        .order('priority')
        .select()
  betOptions:
    $deps: ['book']
    $query: (context) ->
      Knex('bet_option')
        .whereIn('id', context.values('book', 'bet_option_id'))
        .column('name')
        .order('priority')
        .select()
  propositions:
    $deps: ['book']
    $query: (context) ->
      Knex('proposition')
        .whereIn('book_id', context.values('book', 'id'))
        .where(betting_status: 'Open')
        .orWhere(betting_status: 'Suspended')
        .order('sort_order')
        .select()
  matches:
    $deps: ['book']
    $query: (context, params) ->
      Knex('match')
        .whereIn('id', context.values('book', 'match_id'))
        .where(name: params.matchName)
        .column('name')
        .order('match_name')
        .select()

# The view

json =
  sport:
    $where: -> _.size(@competitions) > 0
    $after: -> @_links = [{ rel: 'self', href: "http://foo.com/sport.json" }]
    name:   -> @name
    competition:
      $where: -> _.size(@betOptions) > 0
      $after: ->
        for betOption in @betOptions
          # calc
        match.openMarketCount = calc
      name:   -> @name
      betOptions: [
        $where: -> _.size(@matches) > 0
        name:   -> @name
        matches: [
          $where: -> _.size(@markets) > 0
          name:             -> @name
          #openMarketCount:  -> _.size(@markets)
          markets: [
            $where: -> _.size(@propositions) > 0
            shortName: -> @short_name
            propositions: [
              bettingStatus: -> @betting_status
              isOpen:        -> @is_open
              name:          -> @name
              number:        -> @number
              returnPlace:   -> @return_place
              returnWin:     -> @return_win
            ]
          ]
        ]
      ]
              
# Recurse through JSON
# For each key
#   If the value is an object and the key does not start with $
#     Then it has an associated query
#     Recurse the deps of the query depth-first
#       Execute the query passing in the params and context
#       Remember the query result
#
# After this step, we will have a tree of query results that superficially
# resembles our JSON structure.
#
#  sport:
#    $where: ->
#    $after: ->
#    $isArray: false
#    $result: []
#    competition:
#      $isArray: false
#      $result: []
#      betOptions:
#        $isArray: true
#        $result: []
#        matches:
#          $isArray: true
#          $result: []
#          markets:
#            $isArray: true
#            $result: []
#            propositions:
#              $isArray: true
#              $result: []
#
# Create a new tree by recursing the intermediate tree
# Start with an empty object adding keys on the way down but only filling in
# values and running $where filters on the way back up.
# For each node
#   Unwrap result either into an array or object
#   Run the $where filter
#     If the node is an array, keep the elements matching the array
#     If the node is an object, the object becomes undefined
#
# Now we have a JS object representing our result. JSON.stringify() it!



# TODO figure out what should be in the where clause for this: (#{matchNameQuery})

# TODO filter out tournaments with no open markets
# TODO filter out competitions with no open markets and no tournaments with open markets
# TODO filter out sports with no competitions

# Queries are excecuted from the root
# JSON is created depth first

# NOTE does not have to depend on Knex. Queries can be any function that 
# when executed, returns a promise that eventually yields an array of objects.

