const { environment } = require('@rails/webpacker')

// Setting up an alias
environment.config.merge({
  resolve: {
  	extensions: ['.js', '.jsx', '.json', '.wasm'], // Default extensions
    alias: {
      '@utils': 'app/javascript/utils'
    }
  }
});

node: {
  __dirname: false,
  __filename: false,
  global: true,
}

module.exports = environment
