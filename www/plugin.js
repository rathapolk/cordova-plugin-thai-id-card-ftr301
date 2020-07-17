const exec = require('cordova/exec');

const PLUGIN_NAME = 'ThaiIdCardCordovaPlugin';

var ThaiIdCardCordovaPlugin = {
    listReaders: function(cb) {
        exec(cb, null, PLUGIN_NAME, 'listReaders');
    },
    readData: function(options, cb) {
        exec(cb, null, PLUGIN_NAME, 'readData', [options]);
    }
};

module.exports = ThaiIdCardCordovaPlugin;
