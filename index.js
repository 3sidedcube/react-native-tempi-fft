'use strict';

import React from "react";

import ReactNative, {
  NativeModules,
  NativeAppEventEmitter,
  DeviceEventEmitter,
  Platform
} from "react-native";

var TempiAudioManager = NativeModules.TempiAudioManager;

var AudioAnalyser = {
  startAnalysing: function(options) {

    if (this.progressSubscription) this.progressSubscription.remove();

    this.progressSubscription = NativeAppEventEmitter.addListener('analysisAvailable',
      (data) => {
        if (this.onProgress) {
          this.onProgress(data);
        }
      }
    );

    var defaultOptions = {
      SampleRate: 44100.0,
      Channels: 2,
      FourierParameters: {

      }
    };

    var recordingOptions = {...defaultOptions, ...options};

    if (Platform.OS === 'ios') {
      TempiAudioManager.startAnalysingWithSampleRate(
        recordingOptions.SampleRate,
        recordingOptions.Channels,
        recordingOptions.FourierParameters
      );
    } else {
      console.log("Analysing currently unsupported on Android")
    }
  },
  stopAnalysing: function() {
    return TempiAudioManager.stopAnalysing();
  },
  removeListeners: function() {
    if (this.progressSubscription) this.progressSubscription.remove();
    if (this.finishedSubscription) this.finishedSubscription.remove();
  },
};

module.exports = AudioAnalyser;
