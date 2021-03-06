chai      = require('chai')
expect    = chai.expect
should    = chai.should()
sinon     = require('sinon')
sinonChai = require('sinon-chai')
_         = require("underscore")

chai.use(sinonChai)

Y = require "../lib/y.coffee"
Y.Test = require "../../y-test/lib/y-test.coffee"
Y.Text = require "../../y-text/lib/y-text"
Y.List = require "../../y-list/lib/y-list"

TestSuite = require "./TestSuite"
class ObjectTest extends TestSuite

  constructor: (suffix)->
    super suffix, Y

  makeNewUser: (userId)->
    conn = new Y.Test userId
    super new Y conn

  type: "ObjectTest"

  getRandomRoot: (user_num, root, depth = @max_depth)->
    root ?= @users[user_num]
    if depth is 0 or _.random(0,1) is 1 # take root
      root
    else # take child
      depth--
      elems = null
      if root._name is "Object"
        elems =
          for oname,val of root.val()
            val
      else if root._name is "Array"
        elems = root.val()
      else
        return root

      elems = elems.filter (elem)->
        elem? and ((elem._name is "Array") or (elem._name is "Object"))
      if elems.length is 0
        root
      else
        p = elems[_.random(0, elems.length-1)]
        @getRandomRoot user_num, p, depth

  getGeneratingFunctions: (user_num)->
    super(user_num).concat [
        f : (y)=> # Delete Object Property
          list = for name, o of y.val()
            name
          if list.length > 0
            key = list[_.random(0,list.length-1)]
            y.delete(key)
        types: [Y.Object]
      ,
        f : (y)=> # SET Object Property
          y.val(@getRandomKey(), new Y.Object(@getRandomObject()))
        types: [Y.Object]
      ,
        f : (y)=> # SET PROPERTY TEXT
          y.val(@getRandomKey(), new Y.Text(@getRandomText()))
        types: [Y.Object]
      ,
        f : (y)=> # SET PROPERTY List
          y.val(@getRandomKey(), new Y.List(@getRandomText().split("")))
        types: [Y.Object]
      ,
        f : (y)=> # Delete Array Element
          list = y.val()
          if list.length > 0
            i = _.random(0,list.length-1)
            y.delete(i)
        types: [Y.List]
      ,
        f : (y)=> # insert Object mutable
          l = y.val().length
          y.insert(_.random(0, l-1), new Y.Object(@getRandomObject()))
        types: [Y.List]
      ,
        f : (y)=> # insert Text mutable
          l = y.val().length
          y.insert(_.random(0, l-1), new Y.Text(@getRandomText()))
        types : [Y.List]
      ,
        f : (y)=> # insert List mutable
          l = y.val().length
          y.insert(_.random(0, l-1), new Y.List(@getRandomText().split("")))
        types : [Y.List]
      ,
        f : (y)=> # insert Number (primitive object)
          l = y.val().length
          y.insert(_.random(0,l-1), _.random(0,42))
        types : [Y.List]
      ,
        f : (y)=> # SET Object Property (circular)
          y.val(@getRandomKey(), @getRandomRoot user_num)
        types: [Y.Object]
      ,
        f : (y)=> # insert Object mutable (circular)
          l = y.val().length
          y.insert(_.random(0, l-1), @getRandomRoot user_num)
        types: [Y.List]
      ,
        f : (y)=> # INSERT TEXT
          y
          pos = _.random 0, (y.val().length-1)
          y.insert pos, @getRandomText()
          null
        types: [Y.Text]
      ,
        f : (y)-> # DELETE TEXT
          if y.val().length > 0
            pos = _.random 0, (y.val().length-1) # TODO: put here also arbitrary number (test behaviour in error cases)
            length = _.random 0, (y.val().length - pos)
            ops1 = y.delete pos, length
          undefined
        types : [Y.Text]
      ]

module.exports = ObjectTest

describe "Object Test", ->
  @timeout 500000

  beforeEach (done)->
    @yTest = new ObjectTest()
    @users = @yTest.users

    @test_user = @yTest.makeNewUser "test_user"
    done()

  it "can handle many engines, many operations, concurrently (random)", ->
    console.log "" # TODO
    @yTest.run()

  it "has a working test suite", ->
    @yTest.compareAll()

  it "handles double-late-join", ->
    test = new ObjectTest("double")
    test.run()
    @yTest.run()
    u1 = test.users[0]
    u2 = @yTest.users[1]
    ops1 = u1._model.HB._encode()
    ops2 = u2._model.HB._encode()
    u1._model.engine.applyOp ops2, true
    u2._model.engine.applyOp ops1, true

    expect(@yTest.compare(u1, u2)).to.not.be.undefined

  it "can handle creaton of complex json (1)", ->
    @yTest.users[0].val('a', new Y.Text('q'))
    @yTest.users[1].val('a', new Y.Text('t'))
    @yTest.compareAll()
    q = @yTest.users[2].val('a')
    q.insert(0,'A')
    @yTest.compareAll()
    expect(@yTest.getSomeUser().val("a").val()).to.equal("At")

  it "can handle creaton of complex json (2)", ->
    @yTest.getSomeUser().val('x', new Y.Object({'a':'b'}))
    @yTest.getSomeUser().val('a', new Y.Object({'a':{q: new Y.Text("dtrndtrtdrntdrnrtdnrtdnrtdnrtdnrdnrdt")}}))
    @yTest.getSomeUser().val('b', new Y.Object({'a':{}}))
    @yTest.getSomeUser().val('c', new Y.Object({'a':'c'}))
    @yTest.getSomeUser().val('c', new Y.Object({'a':'b'}))
    @yTest.compareAll()
    q = @yTest.getSomeUser().val("a").val("a").val("q")
    q.insert(0,'A')
    @yTest.compareAll()
    expect(@yTest.getSomeUser().val("a").val("a").val("q").val()).to.equal("Adtrndtrtdrntdrnrtdnrtdnrtdnrtdnrdnrdt")

  it "can handle creaton of complex json (3)", ->
    @yTest.users[0].val('l', new Y.List([1,2,3]))
    @yTest.users[1].val('l', new Y.List([4,5,6]))
    @yTest.compareAll()
    @yTest.users[2].val('l').insert(0,'A')
    w = @yTest.users[1].val('l').insert(0,new Y.Text('B')).val(0)
    w.insert 1, "C"
    expect(w.val()).to.equal("BC")
    @yTest.compareAll()

  it "handles immutables and primitive data types", ->
    @yTest.getSomeUser().val('string', "text")
    @yTest.getSomeUser().val('number', 4)
    @yTest.getSomeUser().val('object', new Y.Object({q:"rr"}))
    @yTest.getSomeUser().val('null', null)
    @yTest.compareAll()
    expect(@yTest.getSomeUser().val('string')).to.equal "text"
    expect(@yTest.getSomeUser().val('number')).to.equal 4
    expect(@yTest.getSomeUser().val('object').val('q')).to.equal "rr"
    expect(@yTest.getSomeUser().val('null') is null).to.be.ok

  it "handles immutables and primitive data types (2)", ->
    @yTest.users[0].val('string', "text")
    @yTest.users[1].val('number', 4)
    @yTest.users[2].val('object', new Y.Object({q:"rr"}))
    @yTest.users[0].val('null', null)
    @yTest.compareAll()
    expect(@yTest.getSomeUser().val('string')).to.equal "text"
    expect(@yTest.getSomeUser().val('number')).to.equal 4
    expect(@yTest.getSomeUser().val('object').val('q')).to.equal "rr"
    expect(@yTest.getSomeUser().val('null') is null).to.be.ok

  it "Observers work on JSON Types (add type observers, local and foreign)", ->
    u = @yTest.users[0]
    @yTest.flushAll()
    last_task = null
    observer1 = (changes)->
      expect(changes.length).to.equal(1)
      change = changes[0]
      expect(change.type).to.equal("add")
      expect(change.object).to.equal(u)
      expect(change.changedBy).to.equal('0')
      expect(change.name).to.equal("newStuff")
      last_task = "observer1"
    u.observe observer1
    u.val("newStuff",new Y.Text("someStuff"))
    expect(last_task).to.equal("observer1")
    u.unobserve observer1

    observer2 = (changes)->
      expect(changes.length).to.equal(1)
      change = changes[0]
      expect(change.type).to.equal("add")
      expect(change.object).to.equal(u)
      expect(change.changedBy).to.equal('1')
      expect(change.name).to.equal("moreStuff")
      last_task = "observer2"
    u.observe observer2
    v = @yTest.users[1]
    v.val("moreStuff","someMoreStuff")
    @yTest.flushAll()
    expect(last_task).to.equal("observer2")
    u.unobserve observer2

  it "Observers work on JSON Types (update type observers, local and foreign)", ->
    u = @yTest.users[0].val("newStuff", new Y.Text("oldStuff")).val("moreStuff",new Y.Text("moreOldStuff"))
    @yTest.flushAll()
    last_task = null
    observer1 = (changes)->
      expect(changes.length).to.equal(1)
      change = changes[0]
      expect(change.type).to.equal("update")
      expect(change.object).to.equal(u)
      expect(change.changedBy).to.equal('0')
      expect(change.name).to.equal("newStuff")
      expect(change.oldValue.val()).to.equal("oldStuff")
      last_task = "observer1"
    u.observe observer1
    u.val("newStuff","someStuff")
    expect(last_task).to.equal("observer1")
    u.unobserve observer1

    observer2 = (changes)->
      expect(changes.length).to.equal(1)
      change = changes[0]
      expect(change.type).to.equal("update")
      expect(change.object).to.equal(u)
      expect(change.changedBy).to.equal('1')
      expect(change.name).to.equal("moreStuff")
      expect(change.oldValue.val()).to.equal("moreOldStuff")
      last_task = "observer2"
    u.observe observer2
    v = @yTest.users[1]
    v.val("moreStuff","someMoreStuff")
    @yTest.flushAll()
    expect(last_task).to.equal("observer2")
    u.unobserve observer2


  it "Observers work on JSON Types (delete type observers, local and foreign)", ->
    u = @yTest.users[0].val("newStuff",new Y.Text("oldStuff")).val("moreStuff",new Y.Text("moreOldStuff"))
    @yTest.flushAll()
    last_task = null
    observer1 = (changes)->
      expect(changes.length).to.equal(1)
      change = changes[0]
      expect(change.type).to.equal("delete")
      expect(change.object).to.equal(u)
      expect(change.changedBy).to.equal('0')
      expect(change.name).to.equal("newStuff")
      expect(change.oldValue.val()).to.equal("oldStuff")
      last_task = "observer1"
    u.observe observer1
    u.delete("newStuff")
    expect(last_task).to.equal("observer1")
    u.unobserve observer1

    observer2 = (changes)->
      expect(changes.length).to.equal(1)
      change = changes[0]
      expect(change.type).to.equal("delete")
      expect(change.object).to.equal(u)
      expect(change.changedBy).to.equal('1')
      expect(change.name).to.equal("moreStuff")
      expect(change.oldValue.val()).to.equal("moreOldStuff")
      last_task = "observer2"
    u.observe observer2
    v = @yTest.users[1]
    v.delete("moreStuff")
    @yTest.flushAll()
    expect(last_task).to.equal("observer2")
    u.unobserve observer2

  it "can handle circular JSON", ->
    u = @yTest.users[0]
    u.val("me", u)
    @yTest.compareAll()
    u.val("stuff", new Y.Object({x: true}))
    u.val("same_stuff", u.val("stuff"))
    u.val("same_stuff").val("x", 5)
    expect(u.val("same_stuff").val("x")).to.equal(5)
    @yTest.compareAll()
    u.val("stuff").val("y", u.val("stuff"))
    @yTest.compareAll()



