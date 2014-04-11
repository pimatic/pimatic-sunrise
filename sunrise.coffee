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

      M(input, context)
        .match(['its ', 'it is '], optional: yes)
        .match(allIdsAndNames, {acFilter: (s) => s in justNames}, (m, match) =>
          if matchToken? and match.length < matchToken.length then return
          matchToken = match
          fullMatch = m.getLongestFullMatch()
        )


      if matchToken?
        for id, o of events
          if id is matchToken or o.name is matchToken
            eventId = id
        assert eventId?
        return {
          token: fullMatch
          nextInput: input.substring(fullMatch.length)
          predicateHandler: new SunrisePredicateHandler(@config, eventId)
        }
      else
        return null

  class SunrisePredicateHandler extends env.predicates.PredicateHandler

    constructor: (@config, @eventId) ->

    _getTimeTillEvent: ->
      now = new Date()
      # https://github.com/mourner/suncalc/issues/11
      timesToday = suncalc.getTimes(
        new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12, 0, 0, 0, 0), 
        @config.latitude, 
        @config.longitude
      )
      if timesToday[@eventId] > now
        timediff = timesToday[@eventId].getTime() - now.getTime()
        assert timediff > 0
        return timediff
      else
        timesTomorrow = suncalc.getTimes(
          new Date(now.getFullYear(), now.getMonth(), now.getDate()+1, 12, 0, 0, 0, 0), 
          @config.latitude, 
          @config.longitude
        )
        timediff = timesTomorrow[@eventId].getTime() - now.getTime()
        assert timediff > 0
        return timediff

    setup: -> 
      setNextTimeOut = =>
        timeTillEvent = @_getTimeTillEvent()
        @timeoutHandle = setTimeout( (=>
          @emit('change', 'event')
          setNextTimeOut()
        ), timeTillEvent)
      setNextTimeOut()

    getType: -> 'event'
    getValue: -> Q(false)

    destroy: ->
      clearTimeout(@timeoutHandle)


  # ###Finally
  # Create a instance of sunrise
  sunrisePlugin = new SunrisePlugin
  # and return it to the framework.
  return sunrisePlugin