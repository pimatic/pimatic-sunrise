# #my-plugin configuration options
module.exports = {
  title: "sunrise config"
  type: "object"
  properties:
    latitude:
      description: "latitude"
      type: "number"
      default: 37.371794
    longitude:
      description: "longitude"
      type: "number"
      default: -122.03476
    timeFormat:
      description: "Change the time display format"
      type: "string"
      enum: ["default", "12h", "24h"]
      default: "default"
}