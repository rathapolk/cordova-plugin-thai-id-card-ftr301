# cordova-plugin-thai-id-card-ftr301
This plugin is for reading and decoding data from Thai national id card (now for iOS only). It utilizes a smart card reader library from https://github.com/FeitianSmartcardReader/R301. 

# Tested devices
* Feitian iR301-U - https://shop.ftsafe.us/products/ir301u

# Installation
```
cordova plugin add https://github.com/rathapolk/cordova-plugin-thai-id-card-ftr301.git
```
# Usage
## Get plugin object
```javascript
const idReader = window['ThaiIdCardCordovaPlugin'];
```

## List readers
```javascript
idReader.listReaders(function (readers) {
  // readers = [ 'reader name' ];
}, function (error) {
  console.error(error);
});
```

## Read data
```javascript
const options = {
  readerName: null, // if not specify, use first reader found.
  readCitizenId: true, // default true
  readPersonal: true, // default true
  readAddress: true, // default true
  readIssuedExpired: true, // default true
  readPhoto: true // default false
};

idReader.readData(options, function (data) {
  const citizenId = data['citizenId'];
  const titleTh = data['titleTh'];
  const firstNameTh = data['firstNameTh'];
  const middleNameTh = data['middleNameTh'];
  const lastNameTh = data['lastNameTh'];
  const titleEn = data['titleEn'];
  const firstNameEn = data['firstNameEn'];
  const middleNameEn = data['middleNameEn'];
  const lastNameEn = data['lastNameEn'];
  const birthDate = data['birthDate']; // format: 'yyyy-MM-dd'
  const sex = data['sex']; // '1' male, '2' female
  const issued = data['issued']; // format: 'yyyy-MM-dd'
  const expired = data['expired']; // format: 'yyyy-MM-dd'
  const addressLine = data['addressLine'];
  const houseNo = data['houseNo'];
  const village = data['village'];
  const lane = data['lane'];
  const road = data['road'];
  const subdistrict = data['subdistrict'];
  const district = data['district'];
  const province = data['province'];
  const photoBase64 = data['photoBase64'];
  ...
}, function (error) {
  console.error(error);
});
```
