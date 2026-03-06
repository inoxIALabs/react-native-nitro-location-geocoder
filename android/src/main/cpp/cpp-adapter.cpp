#include <jni.h>
#include "NitroLocationGeocoderOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::locationgeocoder::initialize(vm);
}
