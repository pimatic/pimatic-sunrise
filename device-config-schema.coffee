module.exports = {
  title: "pimatic-sunrise device config schemas"
  SunriseDevice: {
    title: "Sunrise Device"
    description: "Device to provide times for sunrise, sunset, dusk, etc."
    type: "object"
    extensions: ["xLink"]
    properties:
      latitude:
        description: "latitude, if omitted the latitude given set as part of the plugin configuration applies"
        type: "number"
        required: false
      longitude:
        description: "longitude, if omitted the latitude given set as part of the plugin configuration applies"
        type: "number"
        required: false
      timezone:
        description: "the timezone to which the times shall be transformed. No transformation if empty"
        type: "string"
        default: ""
      attributes:
        description: "attributes which shall be exposed by the device"
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