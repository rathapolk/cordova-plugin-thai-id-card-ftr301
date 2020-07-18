const exec = require('cordova/exec');

const PLUGIN_NAME = 'ThaiIdCardCordovaPlugin';

var ThaiIdCardCordovaPlugin = {
    listReaders: function(cb, error) {
        exec(cb, function (e) {
            if (error) {
                error(e);
            }
        }, PLUGIN_NAME, 'listReaders');
    },
    readData: function(options, cb, error) {
        exec(cb, function (e) {
            if (error) {
                error(e);
            }
        }, PLUGIN_NAME, 'readData', [options]);
    }
};

module.exports = ThaiIdCardCordovaPlugin;
