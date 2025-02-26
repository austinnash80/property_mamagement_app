module.exports = function (api) {
  api.cache(true);
  return {
    presets: ["@babel/preset-env"],
    plugins: [
      "macros",
      ["@babel/plugin-transform-private-methods", { loose: true }],
      ["@babel/plugin-transform-private-property-in-object", { loose: true }],
    ],
  };
};
