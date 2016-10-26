# #Sunrise plugin
milliseconds = require '../pimatic/lib/milliseconds'

module.exports = (env) ->

  Promise = env.require 'bluebird'
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

    init: (app, @framework, @config) =>
      @framework.ruleManager.addPredicateProvider(new SunrisePredicateProvider @framework, @config)

      deviceConfigDef = require("./device-config-schema")
      @framework.deviceManager.registerDeviceClass("SunriseDevice", {
        configDef: deviceConfigDef.SunriseDevice,
        createCallback: (config, lastState) =>
          new SunriseDevice(config, @, lastState)
      })


  class SunriseDevice extends env.devices.Device
    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      @latitude = @config.latitude ? @plugin.config.latitude
      @longitude = @config.longitude ? @plugin.config.longitude
      @attributes = _.cloneDeep(@attributes)
      @_initTimes()

      for attribute in @config.attributes
        do (attribute) =>
          label = attribute.name.replace /(^[a-z])|([A-Z])/g, ((match, p1, p2, offset) =>
            (if offset>0 then " " else "") + match.toUpperCase())
          @attributes[attribute.name] =
            description: label
            type: "string"
            acronym: attribute.label ? label

          @_createGetter attribute.name, () =>
            return Promise.resolve @eventTimes[attribute.name].toLocaleTimeString()

      super(@config)

      scheduleUpdate = () =>
        @_updateTimeout = setTimeout =>
          if @_destroyed then return
          @_initTimes()
          for attribute in @config.attributes
            do (attribute) =>
              @emit attribute.name, @eventTimes[attribute.name].toLocaleTimeString()

          scheduleUpdate()
        , @_getTimeTillTomorrow()

      scheduleUpdate()

    _getTimeTillTomorrow: () ->
      now = new Date()
      tomorrow = new Date(now)
      tomorrow.setDate(now.getDate() + 1)
      tomorrow.setHours(0)
      tomorrow.setMinutes(0)
      tomorrow.setSeconds(0)
      tomorrow.setMilliseconds(0)
      return tomorrow.getTime() - now.getTime()

    _initTimes: () ->
      refDate = new Date()
      @eventTimes = suncalc.getTimes(
        new Date(refDate.getFullYear(), refDate.getMonth(), refDate.getDate(), 12, 0, 0, 0, 0),
        @latitude,
        @longitude
      )

    destroy: () ->
      clearTimeout(@_updateTimeout)
      super()

  class SunrisePredicateProvider extends env.predicates.PredicateProvider

    constructor: (@framework, @config) ->
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
        .match(['its ', 'it is ', 'at '], optional: yes)
        .match(['before ', 'after '], optional: yes, (m, match) => modifier = match.trim())
        .optional( (m) => 
          next = m

          m.matchTimeDurationExpression((m, tp) => 
          #20151025 m.matchTimeDuration((m, tp) => 
            m.match([' before ', ' after '], (m, match) => 
              next = m
              #timeOffset = tp.timeMs
              ba = match.trim()
              tp.mul = if match.trim() is "before" then -1 else 1
              timeOffset = tp

              env.logger.info """
                ba = #{ba}
                tp.tokens: #{tp.tokens}
                tp.unit: #{tp.unit}
                tp.mul: #{tp.mul}
                tp.timeNs: #{tp.timeNs}
                tp: #{tp}
              """
              #if match.trim() is "before"
              #timeOffset = -timeOffset
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
          predicateHandler: new SunrisePredicateHandler(@framework, @config, eventId, modifier, timeOffset)
        }
      else
        return null

  class SunrisePredicateHandler extends env.predicates.PredicateHandler

    constructor: (@framework, @config, @eventId, @modifier, @timeOffset) ->

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
      return @_evaluateTimeExpr(timeOffset.tokens, timeOffset.unit).then( (timeMs) =>
        # Multiply with -1 (before) or 1 (after)
        timeMs *= timeOffset.mul
        env.logger.info """
          In promise timeMs: #{timeMs} (mul: #{timeOffset.mul})
        """
        eventTimeWithOffset = new Date(eventTimes[eventId].getTime() + timeMs)
        return eventTimeWithOffset
      ).catch( (err) =>
        env.logger.error "Error evaluating time expr for predicate: #{err.message}"
        env.logger.debug err
      );

    _evaluateTimeExpr: (tokens, unit) =>
      @framework.variableManager.evaluateNumericExpression(tokens).then( (time) =>
        return milliseconds.parse "#{time} #{unit}"
      )

    _getTimeTillEvent: ->
      env.logger.info "_getTimeTillEvent"
      now = @_getNow()
      refDate = new Date(now)
      if @timeOffset > 0
        refDate = new Date(refDate.getTime() + @timeOffset)
      return @_getNextEventDate(now, refDate)

    _getNextEventDate: (now, refDate) ->
      env.logger.info "_getNextEventDate #{refDate}"
      #eventTimeWithOffset = @_getEventTime(refDate)
      @_getEventTime(refDate).then( (eventTimeWithOffset) ->
        timediff = eventTimeWithOffset.getTime() - now.getTime()
        if timediff < 0
          msPerDay = 24 * 60 * 60 * 1000
          timediff += Math.ceil(-(timediff / msPerDay)) * msPerDay
        assert timediff > 0
        return timediff
      )

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
      @changeListener = (changedVar, value) =>
        env.logger.info "changeListener #{changedVar}, #{value}"
        env.logger.info("Variables: #{@variables}")
        unless changedVar.name in @variables then return
        env.logger.info("setNextTimeout()")
        setNextTimeOut()

      @variables = @framework.variableManager.extractVariables(@timeOffset.tokens)
      @framework.variableManager.on('variableValueChanged', @changeListener)

      setNextTimeOut = =>
        env.logger.info "setNextTimeOut mod: #{@modifier}"
        switch @modifier
          when 'exact'
            @_getTimeTillEvent().then( (timeTillEvent) ->
              env.logger.info("setTimeout in #{timeTillEvent}")
              @timeoutHandle = setTimeout( (=>
                setNextTimeOut()
                @emit('change', 'event')
              ), timeTillEvent)
            )
          when 'before'
            val = @getValueSync()
            if val is true
              # If its before the event then next change is the event date:
              @_getTimeTillEvent().then( (timeTillEvent) ->
                @timeoutHandle = setTimeout( (=>
                  setNextTimeOut()
                  @emit('change', false)
                ), timeTillEvent)
              )
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
              # If its before the event then next change is the event date:
              @_getTimeTillEvent().then( (timeTillEvent) ->
                @timeoutHandle = setTimeout( (=>
                  setNextTimeOut()
                  @emit('change', true)
                ), timeTillEvent)
              )
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
    getValue: -> Promise.resolve(@getValueSync())
    destroy: ->
      clearTimeout(@timeoutHandle)
      @framework.variableManager.removeListener('variableValueChanged', @changeListener)

  # ###Finally
  # Create a instance of sunrise
  sunrisePlugin = new SunrisePlugin()
  # and return it to the framework.
  return sunrisePlugin
