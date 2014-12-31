//
//  iiSoundPlayerFadeOut.swift
//  iiFaderForAvAudioPlayer
//
//  Created by Evgenii Neumerzhitckii on 31/12/2014.
//  Copyright (c) 2014 Evgenii Neumerzhitckii. All rights reserved.
//

import Foundation
import AVFoundation

let iiFaderForAvAudioPlayer_defaultFadeIntervalSeconds = 3.0
let iiFaderForAvAudioPlayer_defaultVelocity = 2.0

@objc
public class iiFaderForAvAudioPlayer {
  let player: AVAudioPlayer
  private var timer: NSTimer?

  // The higher the number - the higher the quality of fade
  // and it will consume more CPU.
  var stepsPerSecond = 30.0

  private var fadeIntervalSeconds = iiFaderForAvAudioPlayer_defaultFadeIntervalSeconds
  private var fadeVelocity = iiFaderForAvAudioPlayer_defaultVelocity

  private var fromVolume = 0.0
  private var toVolume = 0.0

  private var currentStep = 0

  private var onFinished: ((Bool)->())? = nil

  init(player: AVAudioPlayer) {
    self.player = player
  }

  deinit {
    callOnFinished(false)
    stop()
  }

  private var fadeIn: Bool {
    return fromVolume < toVolume
  }

  func fadeIn(interval: Double = iiFaderForAvAudioPlayer_defaultFadeIntervalSeconds,
    velocity: Double = iiFaderForAvAudioPlayer_defaultVelocity, onFinished: ((Bool)->())? = nil) {

    fade(
      fromVolume: Double(player.volume), toVolume: 1,
      interval: interval, velocity: velocity, onFinished: onFinished)
  }

  func fadeOut(interval: Double = iiFaderForAvAudioPlayer_defaultFadeIntervalSeconds,
    velocity: Double = iiFaderForAvAudioPlayer_defaultVelocity, onFinished: ((Bool)->())? = nil) {

    fade(
      fromVolume: Double(player.volume), toVolume: 0,
      interval: interval, velocity: velocity, onFinished: onFinished)
  }

  func fade(#fromVolume: Double, toVolume: Double,
    interval: Double = iiFaderForAvAudioPlayer_defaultFadeIntervalSeconds,
    velocity: Double = iiFaderForAvAudioPlayer_defaultVelocity, onFinished: ((Bool)->())? = nil) {

    self.fromVolume = iiFaderForAvAudioPlayer.makeSureValueIsBetween0and1(fromVolume)
    self.toVolume = iiFaderForAvAudioPlayer.makeSureValueIsBetween0and1(toVolume)
    self.fadeIntervalSeconds = interval
    self.fadeVelocity = velocity

    callOnFinished(false)
    self.onFinished = onFinished

    player.volume = Float(self.fromVolume)

    if self.fromVolume == self.toVolume {
      callOnFinished(true)
      return
    }

    startTimer()
  }

  // Stop fading. Does not stop the sound.
  func stop() {
    stopTimer()
  }

  private func callOnFinished(finished: Bool) {
    onFinished?(finished)
    onFinished = nil
  }

  private func startTimer() {
    stopTimer()
    currentStep = 0

    timer = NSTimer.scheduledTimerWithTimeInterval(1 / stepsPerSecond, target: self,
      selector: "timerFired:", userInfo: nil, repeats: true)
  }

  private func stopTimer() {
    if let currentTimer = timer {
      currentTimer.invalidate()
      timer = nil
    }
  }

  func timerFired(timer: NSTimer) {
    if shouldStopTimer {
      player.volume = Float(toVolume)
      stopTimer()
      callOnFinished(true)
      return
    }

    let currentTimeFrom0To1 = iiFaderForAvAudioPlayer.timeFrom0To1(
      currentStep, fadeIntervalSeconds: fadeIntervalSeconds, stepsPerSecond: stepsPerSecond)

    var volumeMultiplier: Double

    var newVolume: Double = 0

    if fadeIn {
      volumeMultiplier = iiFaderForAvAudioPlayer.fadeInVolumeMultiplier(currentTimeFrom0To1,
        velocity: fadeVelocity)

      newVolume = fromVolume + (toVolume - fromVolume) * volumeMultiplier

    } else {
      volumeMultiplier = iiFaderForAvAudioPlayer.fadeOutVolumeMultiplier(currentTimeFrom0To1,
        velocity: fadeVelocity)

      newVolume = toVolume - (toVolume - fromVolume) * volumeMultiplier
    }

    player.volume = Float(newVolume)

    currentStep++
  }

  var shouldStopTimer: Bool {
    let totalSteps = fadeIntervalSeconds * stepsPerSecond
    return Double(currentStep) > totalSteps
  }

  public class func timeFrom0To1(currentStep: Int, fadeIntervalSeconds: Double,
    stepsPerSecond: Double) -> Double {

    let totalSteps = fadeIntervalSeconds * stepsPerSecond
    var result = Double(currentStep) / totalSteps

    result = makeSureValueIsBetween0and1(result)

    return result
  }

  // Graph: https://www.desmos.com/calculator/mvd9n5rrii
  public class func fadeOutVolumeMultiplier(timeFrom0To1: Double, velocity: Double) -> Double {
    var time = makeSureValueIsBetween0and1(timeFrom0To1)
    return pow(M_E, -velocity * time) * (1 - time)
  }

  public class func fadeInVolumeMultiplier(timeFrom0To1: Double, velocity: Double) -> Double {
    var time = makeSureValueIsBetween0and1(timeFrom0To1)
    return pow(M_E, velocity * (time - 1)) * time
  }

  private class func makeSureValueIsBetween0and1(value: Double) -> Double {
    if value < 0 { return 0 }
    if value > 1 { return 1 }
    return value
  }
}