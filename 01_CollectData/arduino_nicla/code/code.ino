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

BLECharacteristic motionAccGyroCharacteristic(BLE_SENSE_UUID("4001"), BLERead | BLENotify, 7 * sizeof(short));  // Array of 7x 2 Bytes, XY
BLECharacteristic motionOriGravCharacteristic(BLE_SENSE_UUID("5001"), BLERead | BLENotify, 7 * sizeof(short));  // Array of 7x 2 Bytes, XY


// String to calculate the local and device name
String name;
// counter to bind the data in both charactaristics to eachother
short time_count = 1;

SensorXYZ gyroscope(SENSOR_ID_GYRO);
SensorXYZ accelerometer(SENSOR_ID_LACC);
SensorXYZ gravity(SENSOR_ID_GRA);
SensorOrientation orientation(SENSOR_ID_ORI);

///////////// setup function //////////////
void setup() 
{
  Serial.begin(9600); // serial baudrate
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


  if (!BLE.begin()) 
  {
    Serial.println("Failled to initialized BLE!");

    while (1)
      ;
  }

  String address = BLE.address();

  Serial.print("address = ");
  Serial.println(address);

  address.toUpperCase();

  name = "NiclaSenseME";

  Serial.print("name = ");
  Serial.println(name);

  BLE.setLocalName(name.c_str());
  BLE.setDeviceName(name.c_str());
  BLE.setAdvertisedService(service);

  // Add all the previously defined Characteristics
  service.addCharacteristic(versionCharacteristic);
  service.addCharacteristic(motionAccGyroCharacteristic);
  service.addCharacteristic(motionOriGravCharacteristic);

  // Define event handlers
  BLE.setEventHandler(BLEConnected, blePeripheralConnectHandler);
  BLE.setEventHandler(BLEDisconnected, blePeripheralDisconnectHandler);

  versionCharacteristic.setValue(VERSION);

  BLE.addService(service);
  BLE.advertise();
}


///////////// loop function //////////////
// Main loop for updating characteristics
void loop() 
{
  static float dt_sec = 0.02;  // sending rate 50HZ = 1sec/50 = 0.02 sec
  static auto lastCheck = millis();

  BLEDevice central = BLE.central();
  
  
  if (millis() - lastCheck >= (dt_sec * 1000)) // check if 20msec has passed to trigger re-send
  {

    lastCheck = millis();

    if (central.connected()) 
    {
      BHY2.update();

      if (motionAccGyroCharacteristic.subscribed()) // fill in AccGyroCharacteristic
      {
        short motionValues[7] = 
        {
          time_count,
          gyroscope.x(),gyroscope.y(),gyroscope.z(),
          accelerometer.x(),accelerometer.y(),accelerometer.z()
        };

        motionAccGyroCharacteristic.writeValue(motionValues,sizeof(motionValues));
      }


      if (motionOriGravCharacteristic.subscribed())  // fill in OriGravCharacteristic
      {
        short motionValues[7] = 
        {
          time_count,
          orientation.roll(), orientation.pitch(), orientation.heading(),
          gravity.x(),gravity.y(),gravity.z()
        };

        motionOriGravCharacteristic.writeValue(motionValues, sizeof(motionValues));
      }
      
      time_count +=1;
    }
  }
}


///////////// blePeripheralConnectHandler //////////////
void blePeripheralConnectHandler(BLEDevice central) 
{
  nicla::leds.setColor(green);
  time_count = 1; // reset the counter 
}

///////////// blePeripheralDisconnectHandler //////////////
void blePeripheralDisconnectHandler(BLEDevice central) 
{
  nicla::leds.setColor(red);
  time_count = 1; // reset the counter 
}

