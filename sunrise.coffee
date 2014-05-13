# #Sunrise plugin

module.exports = (env) ->

  # Require [convict](https://github.com/mozilla/node-convict) for config validation.
  convict = env.require "convict"
  # Require the [Q](https://github.com/kriskowal/q) promise library
  Q = env.require 'q'
  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'
  M = env.matcher
  _ = env.require 'lodash'
  suncalc = require 'suncalc'

  events = {
    sunrise: 
      name: 'sunrise'
      desc: 'top edge of the sun appears on the horizon'
    sunriseEnd: 
      name: 'sunrise ends'
      desc: 'bottom edge of the sun touches the horizon'
    goldenHourEnd: 
      name: 'morning golden hour'
      desc: 'soft light, best time for photography ends'
    solarNoon: 
      name: 'solar noon'
      desc: 'sun is in the highest position'
    goldenHour: 
      name: 'golden hours' 
      desc: 'evening golden hour starts'
    sunsetStart: 
      name: 'sunset starts'
      desc: 'bottom edge of the sun touches the horizon'
    sunset: 
      name: 'sunset'
      desc: 'sun disappears below the horizon, evening civil twilight starts'
    dusk: 
      name: 'dusk'
      desc: 'evening nautical twilight starts'
    nauticalDusk: 
      name: 'nautical dusk'
      desc: 'evening astronomical twilight starts'
    night: 
      name: 'night starts'
      desc: 'dark enough for astronomical observations'
    nightEnd: 
      name: 'night ends'
      desc: 'morning astronomical twilight starts'
    nauticalDawn: 
      name: 'nautical dawn'
      desc: 'morning nautical twilight starts'
    dawn: 
      name: 'dawn'
      desc: 'morning nautical twilight ends, morning civil twilight starts'
    nadir: 
      name: 'nadir'
      desc: 'darkest moment of the night, sun is in the lowest position'
  }


  class SunrisePlugin extends env.plugins.Plugin

    init: (app, @framework, config) =>
      # Require your config schema
      @conf = convict require("./sunrise-config-schema")
      # and validate the given config.
      @conf.load(config)
      @conf.validate()
      framework.ruleManager.addPredicateProvider(new SunrisePredicateProvider @conf.get(""))

  class SunrisePredicateProvider extends env.predicates.PredicateProvider

    constructor: (@config) ->
      env.logger.info """
        Your location is set to lat: #{@config.latitude}, long: #{@config.longitude}
      """
      return 

    parsePredicate: (input, context) ->
      justNames = (o.name for id, o of events)
      allIdsAndNames = _([id, o.name] for id, o of events).flatten().unique().valueOf()

      matchToken = null
      fullMatch = null
      eventId = null
      timeOffset = 0
      modifier = null      

      M(input, context)
        .match(['its ', 'it is '], optional: yes)
        .match(['before ', 'after '], optional: yes, (m, match) => modifier = match.trim())
        .optional( (m) => 
          next = m
          m.matchTimeDuration((m, tp) => 
            m.match([' before ', ' after '], (m, match) => 
              next = m
              timeOffset = tp.timeMs
              if match.trim() is "before"
                timeOffset = -timeOffset
            )
          )
          return next
        )
        .match(allIdsAndNames, {acFilter: (s) => s in justNames}, (m, match) =>
          if matchToken? and match.length < matchToken.length then return
          matchToken = match
          fullMatch = m.getFullMatch()
        )


      if matchToken?
        for id, o of events
          if id is matchToken or o.name is matchToken
            eventId = id
        assert eventId?
        unless modifier? then modifier = 'exact'
        return {
          token: fullMatch
          nextInput: input.substring(fullMatch.length)
          predicateHandler: new SunrisePredicateHandler(@config, eventId, modifier, timeOffset)
        }
      else
        return null

  class SunrisePredicateHandler extends env.predicates.PredicateHandler

    constructor: (@config, @eventId, @modifier, @timeOffset) ->

    # gets overwritten by tests
    _getNow: -> new Date()

    _getEventTime: (refDate, eventId = @eventId, timeOffset = @timeOffset)->
      # https://github.com/mourner/suncalc/issues/11
      eventTimes = suncalc.getTimes(
        new Date(refDate.getFullYear(), refDate.getMonth(), refDate.getDate(), 12, 0, 0, 0, 0), 
        @config.latitude, 
        @config.longitude
      )
      # add offset
      eventTimeWithOffset = new Date(eventTimes[eventId].getTime() + timeOffset)
      return eventTimeWithOffset


    _getTimeTillEvent: ->
      now = @_getNow()
      refDate = new Date(now)
      if @timeOffset > 0
        refDate = new Date(refDate.getTime() + @timeOffset)
      eventTimeWithOffset = @_getEventTime(refDate)
      if eventTimeWithOffset > now
        timediff = eventTimeWithOffset.getTime() - now.getTime()
        assert timediff > 0
        return timediff
      else
        # get the event for next day:
        refDate.setDate(refDate.getDate()+1)
        eventTimeWithOffset = @_getEventTime(refDate)
        timediff = eventTimeWithOffset.getTime() - now.getTime()
        assert timediff > 0
        return timediff

    _getTimeTillTomorrow: ->
      now = @_getNow()
      tomorrow = new Date(now)
      tomorrow.setDate(now.getDate() + 1)
      tomorrow.setHours(0)
      tomorrow.setMinutes(0)
      tomorrow.setSeconds(0)
      tomorrow.setMilliseconds(0)
      return tomorrow.getTime() - now.getTime()


    setup: -> 
      setNextTimeOut = =>
        switch @modifier
          when 'exact'
            timeTillEvent = @_getTimeTillEvent()
            @timeoutHandle = setTimeout( (=>
              setNextTimeOut()
              @emit('change', 'event')
            ), timeTillEvent)
          when 'before'
            val = @getValueSync()
            if val is true
              # If its before the evnet then next change is the event date:
              timeTillEvent = @_getTimeTillEvent()
              @timeoutHandle = setTimeout( (=>
                setNextTimeOut()
                @emit('change', false)
              ), timeTillEvent)
            else
              # else its after the event, so next event date is 0:00 next day
              timeTillTomorrow = @_getTimeTillTomorrow()
              @timeoutHandle = setTimeout( (=>
                setNextTimeOut()
                @emit('change', true)
              ), timeTillTomorrow)
          when 'after'
            val = @getValueSync()
            if val is false
              # If its before the evnet then next change is the event date:
              timeTillEvent = @_getTimeTillEvent()
              @timeoutHandle = setTimeout( (=>
                setNextTimeOut()
                @emit('change', true)
              ), timeTillEvent)
            else
              # else its after the event, so next event date is 0:00 next day
              timeTillTomorrow = @_getTimeTillTomorrow()
              @timeoutHandle = setTimeout( (=>
                setNextTimeOut()
                @emit('change', false)
              ), timeTillTomorrow)
                 
      setNextTimeOut()

    getType: -> if @modifier is 'exact' then 'event' else 'state'

    getValueSync: ->
      if @modifier is 'exact' then return false
      now = @_getNow()
      eventTime = @_getEventTime(now)
      switch @modifier
        when 'before' then return now < eventTime
        when 'after' then return now > eventTime
    getValue: -> Q(@getValueSync())
    destroy: ->
      clearTimeout(@timeoutHandle)

  # ###Finally
  # Create a instance of sunrise
  sunrisePlugin = new SunrisePlugin()
  # and return it to the framework.
  return sunrisePlugin