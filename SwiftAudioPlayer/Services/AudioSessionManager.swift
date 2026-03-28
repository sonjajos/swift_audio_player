//
//  AudioSessionManager.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import AVFoundation

/// Manages AVAudioSession configuration and handles audio interruptions
class AudioSessionManager: NSObject {
    
    typealias InterruptionHandler = (_ began: Bool, _ shouldResume: Bool) -> Void
    
    var onInterruption: InterruptionHandler?
    
    /// Configure the audio session for playback
    func configure() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        
        // Observe interruptions (phone calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        
        // Observe route changes (headphones plugged/unplugged, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began (phone call, Siri, alarm, etc.)
            onInterruption?(true, false)
            
        case .ended:
            // Interruption ended
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume)
            onInterruption?(false, shouldResume)
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Pause playback when headphones are unplugged
        if reason == .oldDeviceUnavailable {
            onInterruption?(true, false)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
