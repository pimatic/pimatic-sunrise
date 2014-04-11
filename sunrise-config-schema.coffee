# #my-plugin configuration options

# Declare your config option for your plugin here. 

# Defines a `node-convict` config-schema and exports it.
module.exports =
  latitude:
    doc: "latitude"
    format: Number
    default: 37.371794
  longitude:
    doc: "longitude"
    format: Number
    default: -122.03476