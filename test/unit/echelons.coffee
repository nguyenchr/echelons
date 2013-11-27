
Echelons = require '../../echelons'

# Create a table of rows and return it as the resolved value of a promise.
table = (rows) ->
  deferred = Q.defer()
  deferred.resolve rows
  deferred.promise

describe 'Echelons', ->

  queries = null
  json = null

  before (done) ->
    queries =
      person:
        $query: (context, params) ->
          table [
            id: 1
            name: 'Person 1'
          ,
            id: 2
            name: 'Person 2'
          ,
            id: 3
            name: 'Person 3'
          ]
      pets:
        $deps: ['children']
        $query: (context) ->
          table _.find [
            id: 1
            name: 'Pet 1 of Child 1 of Person 1'
            child_id: 1
          ], (pet) ->
            context.values('child', 'id').indexOf(pet.child_id) >= 0
      children:
        $deps: ['person']
        $query: (context) ->
          table _.find [
            id: 1
            name: 'Child 1 of Person 1'
            person_id: 1
          ,
            id: 2
            name: 'Child 2 of Person 1'
            person_id: 1
          ,
            id:3 
            name: 'Child 1 of Person 2'
            person_id: 2 
          ], (child) ->
            context.values('person', 'id').indexOf(child.person_id) >= 0

    json =
      person:
        $where: -> @children.length > 0
        name:   -> @name
        children: [
          $join: { person_id: 'person.id' }
          name: -> @name
          pets: [
            $join: { child_id: 'children.id' }
            name: -> @name
          ]
        ]

    done()

  describe 'topological sorting of queries list by $deps', ->

    it 'should sort such that dependencies are before dependees', (done) ->

      sorted = Echelons.topoSort queries
      sorted.length.should.equal 3
      sorted[0].should.have.property 'key', 'person'
      sorted[1].should.have.property 'key', 'children'
      sorted[2].should.have.property 'key', 'pets'

      done()

  it 'should build the intermediate query result tree', (done) ->

    promise = Echelons.resultTree queries, json, 'person.name': 'Person 1'
    promise.then (resultTree) ->
      try
        resultTree.should.have.property 'person'
        resultTree.person.should.have.property '$result'
        resultTree.person.$result.length.should.equal 1
        person = resultTree.person.$result[0]
        person.should.have.property 'id', 1
        person.should.have.property 'name', 'Person 1'
        done()
      catch err
        done err
    , (err) ->
      console.log 'asdfadsfasdfads'
      done err

  xit 'should generate the JSON', (done) ->
    done()





