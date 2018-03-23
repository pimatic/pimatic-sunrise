module.exports = {
  title: "pimatic-sunrise device config schemas"
  SunriseDevice: {
    title: "Sunrise Device"
    description: "Device to provide times for sunrise, sunset, dusk, etc."
    type: "object"
    extensions: ["xLink"]
    properties:
      latitude:
        description: "Latitude, if omitted the latitude given set as part of the plugin configuration applies"
        type: "number"
        required: false
      longitude:
        description: "Longitude, if omitted the latitude given set as part of the plugin configuration applies"
        type: "number"
        required: false
      localTimezone:
        description: "The local time zone to be applied. If empty the timezone derived from the system will be used"
        type: "string"
        default: ""
      localUtcOffset:
        description: "Local timezone offset to be added localTimezone. Useful if target timezone is UTC"
        type: "number"
        default: 0
      timezone:
        description: "The target timezone to which the times shall be transformed. No transformation if empty"
        type: "string"
        default: ""
      utcOffset:
        description: "Target timezone offset to be added timezone. Useful if timezone is UTC"
        type: "number"
        default: 0
      attributes:
        description: "Attributes which shall be exposed by the device"
        type: "array"
        default: [
          {
            name: "sunrise"
            label: "Sunrise"
          }
          {
            name: "sunset"
            label: "Sunset"
          }
        ]
        format: "table"
        items:
          type: "object"
          properties:
            name:
              enum: [
                "sunrise", "sunriseEnd", "goldenHourEnd", "solarNoon", "goldenHour", "sunsetStart", "sunset", "dusk",
                "nauticalDusk", "night", "nadir", "nightEnd", "nauticalDawn", "dawn"
              ]
              description: "sun-related time attribute"
            label:
              type: "string"
              description: "The attribute label text to be displayed. The name will be displayed if not set"
              required: false
  }
}