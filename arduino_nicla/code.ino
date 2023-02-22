/*

  attitude.roll,
  attitude.pitch,
  attitude.yaw,
  gravity.x,
  gravity.y,
  gravity.z,
  rotationRate.x,
  rotationRate.y,
  rotationRate.z,
  userAcceleration.x,
  userAcceleration.y,
  userAcceleration.z

*/
#include "Arduino.h"
#include "Arduino_BHY2.h"
#include "ArduinoBLE.h"
#include "Nicla_System.h"

#define BLE_SENSE_UUID(val) ("19b10000-" val "-537e-4f6c-d104768a1214")

const int VERSION = 0x00000000;

BLEService service(BLE_SENSE_UUID("0000"));

BLEUnsignedIntCharacteristic versionCharacteristic(BLE_SENSE_UUID("1001"), BLERead);

BLECharacteristic motionAccGyroCharacteristic(BLE_SENSE_UUID("4001"), BLERead | BLENotify, 7 * sizeof(short));  // Array of 6x 2 Bytes, XY
BLECharacteristic motionOriGravCharacteristic(BLE_SENSE_UUID("5001"), BLERead | BLENotify, 7 * sizeof(short));  // Array of 6x 2 Bytes, XY


// String to calculate the local and device name
String name;
short time_count = 1;

SensorXYZ gyroscope(SENSOR_ID_GYRO);
SensorXYZ accelerometer(SENSOR_ID_LACC);
SensorXYZ gravity(SENSOR_ID_GRA);
SensorOrientation orientation(SENSOR_ID_ORI);

void setup() {
  Serial.begin(115200);
  //BHY2.debug(Serial);

  Serial.println("Start");

  nicla::begin();
  nicla::leds.begin();
  nicla::leds.setColor(red);

  //Sensors initialization
  BHY2.begin(NICLA_STANDALONE);
  gyroscope.begin();
  accelerometer.begin();
  gravity.begin();
  orientation.begin();

  if (!BLE.begin()) {
    Serial.println("Failled to initialized BLE!");

    while (1)
      ;
  }

  String address = BLE.address();

  Serial.print("address = ");
  Serial.println(address);

  address.toUpperCase();

  name = "NiclaSenseME";
  // name += address[address.length() - 5];
  // name += address[address.length() - 4];
  // name += address[address.length() - 2];
  // name += address[address.length() - 1];

  Serial.print("name = ");
  Serial.println(name);

  BLE.setLocalName(name.c_str());
  BLE.setDeviceName(name.c_str());
  BLE.setAdvertisedService(service);

  // Add all the previously defined Characteristics
  service.addCharacteristic(versionCharacteristic);
  service.addCharacteristic(motionAccGyroCharacteristic);
  service.addCharacteristic(motionOriGravCharacteristic);


  // Disconnect event handler
  BLE.setEventHandler(BLEConnected, blePeripheralConnectHandler);
  BLE.setEventHandler(BLEDisconnected, blePeripheralDisconnectHandler);

  versionCharacteristic.setValue(VERSION);

  BLE.addService(service);
  BLE.advertise();
}

void loop() {
  static float dt_sec = 0.02;
  static auto lastCheck = millis();

  BLEDevice central = BLE.central();
  
  
  if (millis() - lastCheck >= (dt_sec * 1000)) {

    lastCheck = millis();

    if (central.connected()) {

      BHY2.update();
      

      if (motionAccGyroCharacteristic.subscribed()) {

        short motionValues[7] = {
          time_count,
          gyroscope.x(),gyroscope.y(),gyroscope.z(),
          accelerometer.x(),accelerometer.y(),accelerometer.z()
        };


        motionAccGyroCharacteristic.writeValue(motionValues,sizeof(motionValues));

      }

      if (motionOriGravCharacteristic.subscribed()) {

        short motionValues[7] = {
          time_count,
          orientation.pitch(), orientation.roll() ,orientation.heading(),
          gravity.x(),gravity.y(),gravity.z()
        };

        
        motionOriGravCharacteristic.writeValue(motionValues, sizeof(motionValues));
      }
      
      time_count +=1;

    }
  }
}

void blePeripheralConnectHandler(BLEDevice central) {
  nicla::leds.setColor(green);
  time_count = 1;
}

void blePeripheralDisconnectHandler(BLEDevice central) {
  nicla::leds.setColor(red);
  time_count = 1;
}

