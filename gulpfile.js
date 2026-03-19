'use strict';

const build = require('@microsoft/sp-build-web');

// Allow Node 22+ (SPFx hardcodes a version range, but the build works fine)
build.rig.nodeSupportedVersionRange = '>=18.17.1 <19.0.0 || >=20.11.0 <21.0.0 || >=22.0.0';

// Suppress ESLint errors (single-file project)
build.addSuppression(/Error - \[lint\]/);

var getTasks = build.rig.getTasks;
build.rig.getTasks = function () {
  var result = getTasks.call(build.rig);
  result.set('serve', result.get('serve-deprecated'));
  return result;
};

build.initialize(require('gulp'));
