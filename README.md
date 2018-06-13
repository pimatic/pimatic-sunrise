# pimatic sunrise Plugin

Events for sunrise, sunset and more.

    {
      "plugin": "sunrise",
      "latitude": 37.371794,
      "longitude": -122.03476
    }

The Plugin uses [suncalc](https://github.com/mourner/suncalc). The following events are supported:

  * `sunrise`: sunrise (top edge of the sun appears on the horizon)
  * `sunriseEnd`: sunrise ends (bottom edge of the sun touches the horizon)
  * `goldenHourEnd`: morning golden hour (soft light, best time for photography) ends
  * `solarNoon`: solar noon (sun is in the highest position)
  * `goldenHour`: evening golden hour starts
  * `sunsetStart`: sunset starts (bottom edge of the sun touches the horizon)
  * `sunset`: sunset (sun disappears below the horizon, evening civil twilight starts)
  * `dusk`: dusk (evening nautical twilight starts)
  * `nauticalDusk`: nautical dusk (evening astronomical twilight starts)
  * <s>`night`: night starts (dark enough for astronomical observations)</s>
  * <s>`nightEnd`: night ends (morning astronomical twilight starts)</s>
  * `nauticalDawn`: nautical dawn (morning nautical twilight starts)
  * `dawn`: dawn (morning nautical twilight ends, morning civil twilight starts)
  * `nadir`: nadir (darkest moment of the night, sun is in the lowest position)
  
Note: `night` and `nightEnd` have been deprecated as these events yield invalid results for several 
 locations due to a bug in the underlying suncalc package. The `night starts` and `night ends` predicates 
 are also affected. 

## Device Configuration

Optionally, you can setup a `SunriseDevice` to get sunlight times displayed for a given location. If no location is 
provided with the device configuration the location given with the plugin configuration applies. The `attributes` 
property is used to define which sunlight-related attributes shall be exposed by the device. The name given for an 
attribute is one of the sunlight event names listed above. 

If a label text is set for an attribute the text will be used as an acronym for the attribute on display. Otherwise, the 
acronym will be constructed from the event name. If the label text is an empty string no acronym will be displayed.

If you wish to obtain the times in the timezone of the location at the given coordinates you can 
additionally set the `timezone` property. This will transform the times to the given timezone and will cut off 
the timezone offsets before converting the resulting times to the localized time string. For a list of valid "TZ" 
timezone strings, see [Wikipedia - List of Timezones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). 

If the `timezone` property is absent or the property is set to an empty string no transformation will be performed. 
Additionally, it is possible to set a `utcOffset` offset time in hours relative to the `timezone`. 
This is useful for example if you wish to neglect daylight savings, i.e. you can set the `timezone`to `UTC` 
and provide the required `utcOffset` value. 

Note, by default, all times will be given in the local time zone of the system on which pimatic is installed. If you 
wish to use a different timezone, e.g. universal time to neglect daylight savings, you can set the `localTimezone` 
and `localUtcOffset` properties. However, these properties are only applicable if the `timezone` property has been set.

    {
          "id": "sunrise-1",
          "class": "SunriseDevice",
          "name": "Sunrise",
          "latitude": 52.5072111,
          "longitude": 13.1449592,
          "attributes": [
            {
              "name": "sunrise",
              "label": "Sunrise Time"
            },
            {
              "name": "sunset",
              "label": "Sunset Time"
            }
          ]
    }