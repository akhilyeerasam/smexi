const path = require('path');

module.exports = {
  "mode": "none",
  "entry": "./src/index.js",
  "output": {
    "path": __dirname + '/dist',
    "filename": "bundle.js"
  },
  watch: false,
  devtool: 'inline-nosources-cheap-module-source-map',
  devServer: {
    contentBase: path.join(__dirname, 'dist')
  },
  "module": {
    "rules": [
      {
        "test": /\.css$/,
        "use": [
          "style-loader",
          "css-loader"
        ]
      },
      {
        "test": /\.js$/,
        "enforce": 'pre',
        "exclude": /node_modules/,
        "use": {
          "loader": "babel-loader",
          "options": {
            "presets": [
              "@babel/preset-env",
            ]
          }
        }
      },
    ]
  },
};