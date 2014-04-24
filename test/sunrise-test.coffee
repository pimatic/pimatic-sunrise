module.exports = (env) ->

  sinon = env.require 'sinon'
  assert = env.require "assert"

  describe "sunrise", ->

    sunrisePredProv = null

    plugin = null

    before =>
      plugin = (env.require 'pimatic-sunrise') env

    after =>

    describe 'SunrisePlugin', =>
      describe "#init()", =>

        it "should register the SunrisePredicateProvier", =>
          spy = sinon.spy()
          frameworkDummy =
            ruleManager:
              addPredicateProvider: spy
          plugin.init(null, frameworkDummy, {latitude:52.5234051, longitude: 13.4113999}) # Berlin
          assert spy.called
          sunrisePredProv = spy.getCall(0).args[0]
          assert sunrisePredProv?

    describe "SunrisePredicateProvider", =>

      tests = [
        {
          predicates: ["its sunrise", "sunrise", "it is sunrise"]
          modifier: 'exact'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 07:49:42 GMT+0100 (CET)')
          value: false
          timeTillEventH: 23.8 #h
        }
        {
          predicates: ["its sunset", "sunset", "it is sunset"]
          modifier: 'exact'
          eventId: 'sunset' 
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 16:52:37 GMT+0100 (CET)')
          value: false
          timeTillEventH: 8.87 #h
        }
        {
          predicates: ["its before sunrise", "before sunrise", "it is before sunrise"]
          modifier: 'before'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 07:49:42 GMT+0100 (CET)')
          value: false
          timeTillEventH: 23.8 #h
        }
        {
          predicates: ["its after sunrise", "after sunrise", "it is after sunrise"]
          modifier: 'after'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 07:49:42 GMT+0100 (CET)')
          value: true
          timeTillEventH: 23.8 #h
        }
        {
          predicates: [
            "its 2 hours before sunrise", 
            "2h before sunrise", 
            "it is 120 minutes before sunrise"
          ]
          modifier: 'exact'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 05:49:42 GMT+0100 (CET)')
          value: false
        }
        {
          predicates: [
            "its 2 hours after sunrise", 
            "2h after sunrise", 
            "it is 120 minutes after sunrise"
          ]
          modifier: 'exact'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 9:49:42 GMT+0100 (CET)')
          value: false
        }
      ]

      describe '#parsePredicate()', =>
        createParsePredicateTest = (test, pred) =>
          it "should parse #{pred}", (finish) =>
            result = sunrisePredProv.parsePredicate(pred)
            assert result?
            predHandler = result.predicateHandler
            assert predHandler
            assert.equal predHandler.modifier, test.modifier
            assert.equal predHandler.eventId, test.eventId
            predHandler._getNow = => new Date(test.now)
            eventDate = predHandler._getEventTime(test.now)
            assert.equal(
              Math.floor(eventDate.getTime()/1000), 
              Math.floor(test.eventDate.getTime()/1000)
            )

            timeTillEvent = predHandler._getTimeTillEvent()
            #console.log "timetillEvent:", (timeTillEvent / 60 / 60 / 1000)
            predHandler.getValue().then( (val) =>
              assert.equal test.value, val
              finish()
            ).catch(finish)
   
        for test in tests
          for pred in test.predicates
            createParsePredicateTest test, pred

    describe "SunrisePredicateHandler", =>

      tests = [
        {
          predicate: "its sunrise"
          getNow: (eventDate) -> new Date(eventDate.getTime()-500)
          changeVal: 'event'
        }
        {
          predicate: "its sunset"
          getNow: (eventDate) -> new Date(eventDate.getTime()-500)
          changeVal: 'event'
        }
        {
          predicate: "its before sunrise"
          getNow: (eventDate) -> new Date(eventDate.getTime()-500)
          changeVal: false
        }
        {
          predicate: "its before sunrise"
          getNow: (eventDate) -> 
            dayBefore = new Date(eventDate)
            dayBefore.setDate(eventDate.getDate() - 1)
            dayBefore.setHours(23)
            dayBefore.setMinutes(59)
            dayBefore.setSeconds(59)
            dayBefore.setMilliseconds(599)
            return dayBefore
          changeVal: true
        }
        {
          predicate: "its after sunrise"
          getNow: (eventDate) -> new Date(eventDate.getTime()-500)
          changeVal: true
        }
        {
          predicate: "its after sunrise"
          getNow: (eventDate) -> 
            dayEnd = new Date(eventDate)
            dayEnd.setHours(23)
            dayEnd.setMinutes(59)
            dayEnd.setSeconds(59)
            dayEnd.setMilliseconds(599)
            return dayEnd
          changeVal: false
        }
      ]

      describe '#on change', =>
        createOnChangeTest = (test) =>
          it "should notify on change #{test.predicate}", (finish) =>
            result = sunrisePredProv.parsePredicate(test.predicate)
            assert result?
            predHandler = result.predicateHandler
            assert predHandler
            refDate = new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
            eventDate = predHandler._getEventTime(refDate)
            predHandler._getNow = => test.getNow(eventDate)
            predHandler.setup()
            predHandler.on('change', (val) =>
              assert.equal val, test.changeVal
              predHandler.destroy()
              finish() 
            )
   
        for test in tests
          createOnChangeTest test
