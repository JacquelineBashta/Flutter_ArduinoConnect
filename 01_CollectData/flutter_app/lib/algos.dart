

int elapsedMs = 0;
DateTime startTime = DateTime.now();

double sensitivity = 0.8;
double threshold = 4000;
double lowPassX = 0;
double lowPassY = 0;
double lowPassZ = 0;
double highpassX = 0;
double highpassY = 0;
double highpassZ = 0;

int avgFreqHz = 30;
int hitCount = 0;
int hitsRatePerSec = 0;
int hitMaxPower = 0;

// kcal
// Sound alerts
// Save  / Exit

bool detectHit(List<int> accList) {
  //accList (acc_x, acc_y, acc_z)
  bool result = false;

  if (accList[0].abs() > threshold ||
      accList[1].abs() > threshold ||
      accList[2].abs() > threshold) {
    result = true;
    elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    startTime = DateTime.now();
    print("highpass $result, freq = ${1000 / elapsedMs}");
  }
  return result;
}

bool detectPeak(List<int> accList) {
  //accList (acc_x, acc_y, acc_z)
  bool result = false;
  double highpassFinal = 0;
  double sensorValueX = accList[0] / 4096.0;
  double sensorValueY = accList[1] / 4096.0;
  double sensorValueZ = accList[2] / 4096.0;

  lowPassX = ((sensitivity * sensorValueX) + ((1 - sensitivity) * lowPassX));
  highpassX = sensorValueX - lowPassX;

  lowPassY = ((sensitivity * sensorValueY) + ((1 - sensitivity) * lowPassY));
  highpassY = sensorValueY - lowPassY;

  lowPassZ = ((sensitivity * sensorValueZ) + ((1 - sensitivity) * lowPassZ));
  highpassZ = sensorValueZ - lowPassZ;

  highpassFinal = (highpassX + highpassY + highpassZ) / 3;
  highpassFinal = double.parse((highpassFinal).toStringAsFixed(2));

  if (highpassFinal > 0.0) {
    result = true;
    elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    startTime = DateTime.now();
    print("highpass $highpassFinal, freq = ${1000 / elapsedMs}");
  }
  return result;
}


