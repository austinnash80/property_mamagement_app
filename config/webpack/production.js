process.env.NODE_ENV = process.env.NODE_ENV || 'production'

const environment = require('./environment')
const webpack = require('webpack')

// Ensuring 'global' is available as the global object
environment.plugins.append(
  'Provide',
  new webpack.ProvidePlugin({
    global: require.resolve('global/window')
  })
);

module.exports = environment.toWebpackConfig()
