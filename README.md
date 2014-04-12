pimatic sunrise Plugin
=======================

Events for sunrise, sunset and more.

    {
      "plugin": "sunrise",
      "latitude": 37.371794,
      "longitude": -122.03476
    }

The Plugin uses [suncalc](https://github.com/mourner/suncalc). All Events:

  * `sunrise`: sunrise (top edge of the sun appears on the horizon)
  * `sunriseEnd`: sunrise ends (bottom edge of the sun touches the horizon)
  * `goldenHourEnd`: morning golden hour (soft light, best time for photography) ends
  * `solarNoon`: solar noon (sun is in the highest position)
  * `goldenHour`: evening golden hour starts
  * `sunsetStart`: sunset starts (bottom edge of the sun touches the horizon)
  * `sunset`: sunset (sun disappears below the horizon, evening civil twilight starts)
  * `dusk`: dusk (evening nautical twilight starts)
  * `nauticalDusk`: nautical dusk (evening astronomical twilight starts)
  * `night`: night starts (dark enough for astronomical observations)
  * `nightEnd`: night ends (morning astronomical twilight starts)
  * `nauticalDawn`: nautical dawn (morning nautical twilight starts)
  * `dawn`: dawn (morning nautical twilight ends, morning civil twilight starts)
  * `nadir`: nadir (darkest moment of the night, sun is in the lowest position)
