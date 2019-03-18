module.exports = (env) ->

  sinon = env.require 'sinon'
  assert = env.require "assert"

  env.variables = (env.require "./lib/variables") env

  describe "sunrise", ->

    frameworkDummy = null
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
            deviceManager:
              registerDeviceClass: spy
            on: sinon.spy()

          frameworkDummy.variableManager = new env.variables.VariableManager(frameworkDummy, [])
          frameworkDummy.variableManager.addVariable('offset', 'value', 5, 'seconds')
          frameworkDummy.variableManager.on('variableValueChanged', (changedVar, value) ->
            #console.log("variableValueChanged #{changedVar.name} = #{value}")
          )

          plugin.init(null, frameworkDummy, {latitude:52.5234051, longitude: 13.4113999}) # Berlin
          assert spy.called
          sunrisePredProv = spy.getCall(0).args[0]
          assert frameworkDummy?
          assert frameworkDummy.variableManager?
          assert sunrisePredProv?

    describe "SunrisePredicateProvider", =>

      tests = [
        {
          predicates: ["time is sunrise", "sunrise"]
          modifier: 'exact'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 07:49:42 GMT+0100 (CET)')
          value: false
          timeTillEventH: 23.8 #h
        }
        {
          predicates: ["time is sunset", "sunset"]
          modifier: 'exact'
          eventId: 'sunset' 
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 16:52:37 GMT+0100 (CET)')
          value: false
          timeTillEventH: 8.87 #h
        }
        {
          predicates: ["time is before sunrise", "before sunrise"]
          modifier: 'before'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 07:49:42 GMT+0100 (CET)')
          value: false
          timeTillEventH: 23.8 #h
        }
        {
          predicates: ["time is after sunrise", "after sunrise"]
          modifier: 'after'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 07:49:42 GMT+0100 (CET)')
          value: true
          timeTillEventH: 23.8 #h
        }
        {
          predicates: [
            "time is 2 hours before sunrise",
            "2h before sunrise"
          ]
          modifier: 'exact'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 05:49:42 GMT+0100 (CET)')
          value: false
        }
        {
          predicates: [
            "time is 2 hours after sunrise", 
            "2h after sunrise"
          ]
          modifier: 'exact'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 9:49:42 GMT+0100 (CET)')
          value: false
        }
        {
          predicates: [
            "time is $offset seconds before sunrise",
            "$offset seconds before sunrise"
          ]
          modifier: 'exact'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 07:49:37 GMT+0100 (CET)')
          value: false
        }
        {
          predicates: [
            "time is $offset seconds after sunrise",
            "$offset seconds after sunrise"
          ]
          modifier: 'exact'
          eventId: 'sunrise'
          now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
          eventDate: new Date('Sat Feb 01 2014 07:49:47 GMT+0100 (CET)')
          value: false
        }
        #Disabled for now, not implemented yet
        #{
        #  predicates: [
        #    "time is at least 2 hours after sunrise",
        #    "time is after 2h after sunrise"
        #  ]
        #  modifier: 'after'
        #  eventId: 'sunrise'
        #  now: new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
        #  eventDate: new Date('Sat Feb 01 2014 9:49:42 GMT+0100 (CET)')
        #  value: false
        #}
      ]

      describe '#parsePredicate()', =>
        createParsePredicateTest = (test, pred) =>
          it "should parse #{pred}", () =>
            assert frameworkDummy?
            assert frameworkDummy.variableManager?
            {variables, functions} = frameworkDummy.variableManager.getVariablesAndFunctions()
            spy = sinon.spy()
            context = {
              variables: variables
              functions: functions
              addHint: =>
              addElements: spy
            }

            result = sunrisePredProv.parsePredicate(pred, context)
            assert result?
            predHandler = result.predicateHandler
            assert predHandler
            assert.equal predHandler.modifier, test.modifier
            assert.equal predHandler.eventId, test.eventId
            predHandler._getNow = => new Date(test.now)
            eventDatePromise = predHandler._getEventTime(test.now)
            return eventDatePromise.then( (eventDate) =>
              assert.equal(
                Math.floor(eventDate.getTime()/1000), 
                Math.floor(test.eventDate.getTime()/1000)
              )

              timeTillEventPromise = predHandler._getTimeTillEvent()
              timeTillEventPromise.then( (timeTillEvent) =>
                predHandler.getValue().then( (val) =>
                  assert.equal test.value, val
                )
              )
            )
   
        for test in tests
          for pred in test.predicates
            createParsePredicateTest test, pred

    describe "SunrisePredicateHandler", =>

      tests = [
        {
          predicate: "time is sunrise"
          getNow: (eventDate) -> new Date(eventDate.getTime()-100)
          changeVal: 'event'
        }
        {
          predicate: "time is sunset"
          getNow: (eventDate) -> new Date(eventDate.getTime()-100)
          changeVal: 'event'
        }
        {
          predicate: "time is before sunrise"
          getNow: (eventDate) -> new Date(eventDate.getTime()-100)
          changeVal: false
        }
        {
          predicate: "time is before sunrise"
          getNow: (eventDate) -> 
            dayBefore = new Date(eventDate)
            dayBefore.setDate(eventDate.getDate() - 1)
            dayBefore.setHours(23)
            dayBefore.setMinutes(59)
            dayBefore.setSeconds(59)
            dayBefore.setMilliseconds(899)
            return dayBefore
          changeVal: true
        }
        {
          predicate: "time is after sunrise"
          getNow: (eventDate) -> new Date(eventDate.getTime()-100)
          changeVal: true
        }
        {
          predicate: "time is after sunrise"
          getNow: (eventDate) -> 
            dayEnd = new Date(eventDate)
            dayEnd.setHours(23)
            dayEnd.setMinutes(59)
            dayEnd.setSeconds(59)
            dayEnd.setMilliseconds(899)
            return dayEnd
          changeVal: false
        }
        {
          predicate: "time is $offset seconds before sunrise"
          getNow: (eventDate) -> new Date(eventDate.getTime()-100)
          changeVal: 'event'
        }
      ]

      describe '#on "change"', =>
        createOnChangeTest = (test) =>
          it "should notify on change #{test.predicate}", (finish) =>
            assert frameworkDummy?
            assert frameworkDummy.variableManager?
            {variables, functions} = frameworkDummy.variableManager.getVariablesAndFunctions()
            spy = sinon.spy()
            context = {
              variables: variables
              functions: functions
              addHint: =>
              addElements: spy
            }

            result = sunrisePredProv.parsePredicate(test.predicate, context)
            assert result?
            predHandler = result.predicateHandler
            assert predHandler
            refDate = new Date('Sat Feb 01 2014 08:00:00 GMT+0100 (CET)')
            eventDatePromise = predHandler._getEventTime(refDate)
            eventDatePromise.then( (eventDate) =>
              predHandler._getNow = => test.getNow(eventDate)
              predHandler.setup()
              predHandler.on('change', (val) =>
                predHandler._getNow = => new Date(eventDate.getTime() + 5000)
                assert.equal val, test.changeVal
                predHandler.destroy()
                finish()
              )
            ).catch(finish)
            0

        for test in tests
          createOnChangeTest test

    describe "SunrisePredicateHandler with variables", =>
      tests = [
        {
          id: 1
          predicate: "time is $offset seconds before sunrise"
          offset1: 300
          offset2: 5
          eventDate: new Date('Sat Feb 01 2014 07:49:38 GMT+0100 (CET)')
        }
        {
          id: 2
          predicate: "time is $offset seconds after sunrise"
          offset1: 300
          offset2: 5
          eventDate: new Date('Sat Feb 01 2014 07:49:48 GMT+0100 (CET)')
        }
      ]

      describe '#Variable changed', =>
        createOnChangeTest = (test) =>
          it "should update eventDate", (finish) ->
            @timeout(5000)
            assert frameworkDummy?
            assert frameworkDummy.variableManager?
            {variables, functions} = frameworkDummy.variableManager.getVariablesAndFunctions()
            spy = sinon.spy()
            context = {
              variables: variables
              functions: functions
              addHint: =>
              addElements: spy
            }

            frameworkDummy.variableManager.updateVariable('offset', 'value', test.offset1, 'seconds')

            result = sunrisePredProv.parsePredicate(test.predicate, context)
            assert result?
            predHandler = result.predicateHandler
            assert predHandler


            predHandler._getNow = -> new Date(test.eventDate - 100)
            changes = 0

            predHandler.on('change', (val) ->
              predHandler._getNow = => new Date(test.eventDate + 10000)
              predHandler.removeAllListeners()
              predHandler.destroy()
              finish()
            )

            predHandler.setup()

            setTimeout( (->
              frameworkDummy.variableManager.updateVariable('offset', 'value', test.offset2, 'seconds')
              ), 20)

            0

        for test in tests
          createOnChangeTest test
