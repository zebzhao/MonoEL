//
//  RecordAudio.swift
//
//  This is a Swift 3.0 class
//    that uses the iOS RemoteIO Audio Unit
//    to record audio input samples,
//  (should be instantiated as a singleton object.)
//
//  Created by Ronald Nicholson on 10/21/16.  Updated 2017Feb07
//  Copyright © 2017 HotPaw Productions. All rights reserved.
//  Distribution: BSD 2-clause license
//
import Foundation
import AVFoundation
import AudioUnit
import aubio

// call startRecording() to start recording
final class RecordAudio: NSObject {
    var tempo: OpaquePointer? = nil
    var notes: OpaquePointer? = nil
    var samples: UnsafeMutablePointer<fvec_t>? = nil
    var out: UnsafeMutablePointer<fvec_t>? = nil
    let hopSize: UInt32 = 256
    let bufferSize: UInt32 = 512
    
    let gainFac: Float = 1.03
    let offFac: Float = 0.97
    let lossFac: Float = 0.99
    let offThres: Float = 0.5
    let onThres: Float = 0.6
    
    var bpm: Float = 100.0
    let bpmBufferLength = 5
    var bpmBufferIdx = 0
    var bpmBuffer = [Float](repeating: 0.0, count: 5)
    var notesBuffer = [Float](repeating: 0.0, count: 12)
    var notesOnBuffer = [Float](repeating: 0.0, count: 12)
    var notesOffBuffer = [Bool](repeating: false, count: 12)
    var audioUnit:   AudioUnit?     = nil
    
    var micPermission   =  false
    var sessionActive   =  false
    var isRecording     =  false
    
    var sampleRate : Double = 44100.0    // default audio sample rate
    
    private var hwSRate = 48000.0   // guess of device hardware sample rate
    private var micPermissionDispatchToken = 0
    private var interrupted = false     // for restart from audio interruption notification
    
    
    
    func startRecording() {
        if isRecording { return }
        
        startAudioSession()
        if sessionActive {
            startAudioUnit()
        }
    }
    
    var numberOfChannels: Int       =  2
    
    private let outputBus: UInt32   =  0
    private let inputBus: UInt32    =  1
    
    func startAudioSession() {
        if (sessionActive == false) {
            // set and activate Audio Session
            do {
                
                let audioSession = AVAudioSession.sharedInstance()
                
                if (micPermission == false) {
                    if (micPermissionDispatchToken == 0) {
                        micPermissionDispatchToken = 1
                        audioSession.requestRecordPermission({(granted: Bool)-> Void in
                            if granted {
                                self.micPermission = true
                                return
                                // check for this flag and call from UI loop if needed
                            } else {
                                gTmp0 += 1
                                // dispatch in main/UI thread an alert
                                //   informing that mic permission is not switched on
                            }
                        })
                    }
                }
                if micPermission == false { return }
                
                try? audioSession.setCategory(
                    AVAudioSession.Category.playAndRecord,
                    options: [
                        AVAudioSession.CategoryOptions.defaultToSpeaker,
                        AVAudioSession.CategoryOptions.allowBluetoothA2DP,
                        AVAudioSession.CategoryOptions.mixWithOthers])
                // choose 44100 or 48000 based on hardware rate
                // sampleRate = 44100.0
                var preferredIOBufferDuration = 0.05      // 5.8 milliseconds = 256 samples
                hwSRate = audioSession.sampleRate           // get native hardware rate
                // set session to hardware rate
                if hwSRate == 48000.0 {
                    sampleRate = 48000.0
                    preferredIOBufferDuration = 0.04
                }
                let desiredSampleRate = sampleRate
                try audioSession.setPreferredSampleRate(desiredSampleRate)
                try audioSession.setPreferredIOBufferDuration(preferredIOBufferDuration)
                
                setupAubio(samplerate: uint_t(desiredSampleRate))
                
                try audioSession.setActive(true)
                sessionActive = true
            } catch /* let error as NSError */ {
                // handle error here
            }
        }
    }
    
    let recordingCallback: AURenderCallback = { (
        inRefCon,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        frameCount,
        ioData ) -> OSStatus in
        
        let audioObject = unsafeBitCast(inRefCon, to: RecordAudio.self)
        var err: OSStatus = noErr
        
        // set mData to nil, AudioUnitRender() should be allocating buffers
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: UInt32(2),
                mDataByteSize: 2048,
                mData: nil))
        
        if let au = audioObject.audioUnit {
            err = AudioUnitRender(au,
                                  ioActionFlags,
                                  inTimeStamp,
                                  inBusNumber,
                                  frameCount,
                                  &bufferList)
        }
        
        audioObject.processMicrophoneBuffer( inputDataList: &bufferList,
                                             frameCount: UInt32(frameCount) )
        return 0
    }
    
    func processMicrophoneBuffer(inputDataList : UnsafeMutablePointer<AudioBufferList>, frameCount : UInt32) {
        guard let samples = samples, let out = out, let tempo = tempo, let notes = notes else { return }
        let count = Int(frameCount)
        var sampleCount: UInt32 = 0
        
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
        let mBuffers : AudioBuffer = inputDataPtr[0]
        
        let bufferPointer = UnsafeMutableRawPointer(mBuffers.mData)
        if let bptr = bufferPointer {
            let dataArray = bptr.assumingMemoryBound(to: Float.self)
            for i in 0..<(count/2) {
                let x = Float(dataArray[i+i  ])   // copy left  channel sample
                let y = Float(dataArray[i+i+1])   // copy right channel sample
            
                fvec_set_sample(samples, (x + y) * 0.5, sampleCount)
                sampleCount += 1
                
                if sampleCount == hopSize || i == count/2-1 {
                    aubio_tempo_do(tempo, samples, out)
                    if fvec_get_sample(out, 0) != 0 {
                        // Yay! A BEAT!!!
                        let tBpm = aubio_tempo_get_bpm(tempo)
                        bpmBuffer[bpmBufferIdx % bpmBufferLength] = tBpm
                        bpm = bpmBufferIdx <= bpmBufferLength ? tBpm : bpmBuffer.reduce(0.0, +)/Float(bpmBufferLength)
                        bpmBufferIdx += 1
                    }
                    
                    aubio_notes_do(notes, samples, out)
                    
                    let noteOff = Int(fvec_get_sample(out, 2))
                    let noteOn = Int(fvec_get_sample(out, 0))
                    if noteOff > 0 {
                        notesOffBuffer[noteOff % 12] = true
                    }
                    // did we get a note on?
                    if noteOn > 0 {
                        notesOffBuffer[noteOn % 12] = false
                        notesOnBuffer[noteOn % 12] = fvec_get_sample(out, 1)/127.0
                    }
                    
                    let trueGainFactor = gainFac + bpm*0.00035
                    
                    for index in 0...11 {
                        if notesOffBuffer[index] {
                            if notesOnBuffer[index] > offThres {
                                notesOnBuffer[index] *= offFac
                            } else {
                                notesOnBuffer[index] = 0
                                notesOffBuffer[index] = false
                            }
                        }
                        if notesOnBuffer[index] == 0 {
                            notesBuffer[index] *= lossFac
                        } else if notesOnBuffer[index] > onThres {
                            notesBuffer[index] = fmin(fmax(notesBuffer[index], 0.0038)*trueGainFactor, 1.0);
                        }
                    }
                    
                    sampleCount = 0
                }
            }
        }
    }
    
    func stopRecording() {
        tearDownAubio()
        AudioUnitUninitialize(self.audioUnit!)
        isRecording = false
    }
    
    private func startAudioUnit() {
        var err: OSStatus = noErr
        
        if self.audioUnit == nil {
            setupAudioUnit()         // setup once
        }
        guard let au = self.audioUnit
            else { return }
        
        err = AudioUnitInitialize(au)
        gTmp0 = Int(err)
        if err != noErr { return }
        err = AudioOutputUnitStart(au)  // start
        
        gTmp0 = Int(err)
        if err == noErr {
            isRecording = true
        }
    }
    
    private func setupAubio(samplerate: UInt32) {
        samples = new_fvec(hopSize)
        out = new_fvec(hopSize)
        tempo = new_aubio_tempo("default", bufferSize, hopSize, samplerate)
        notes = new_aubio_notes("default", bufferSize, hopSize, samplerate)
        aubio_tempo_set_silence(tempo, -78.0)
        aubio_notes_set_silence(notes, -78.0)
        aubio_notes_set_release_drop(notes, 18.0)
    }
    
    private func setupAudioUnit() {
        var componentDesc:  AudioComponentDescription
            = AudioComponentDescription(
                componentType:          OSType(kAudioUnitType_Output),
                componentSubType:       OSType(kAudioUnitSubType_RemoteIO),
                componentManufacturer:  OSType(kAudioUnitManufacturer_Apple),
                componentFlags:         UInt32(0),
                componentFlagsMask:     UInt32(0) )
        
        var osErr: OSStatus = noErr
        
        let component: AudioComponent! = AudioComponentFindNext(nil, &componentDesc)
        
        var tempAudioUnit: AudioUnit?
        osErr = AudioComponentInstanceNew(component, &tempAudioUnit)
        self.audioUnit = tempAudioUnit
        
        guard let au = self.audioUnit
            else { return }
        
        // Enable I/O for input.
        
        var one_ui32: UInt32 = 1
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Input,
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        
        // Set format to 32-bit Floats, linear PCM
        let nc = 2  // 2 channel stereo
        var streamFormatDesc:AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate:        Double(sampleRate),
            mFormatID:          kAudioFormatLinearPCM,
            mFormatFlags:       ( kAudioFormatFlagsNativeFloatPacked ),
            mBytesPerPacket:    UInt32(nc * MemoryLayout<UInt32>.size),
            mFramesPerPacket:   1,
            mBytesPerFrame:     UInt32(nc * MemoryLayout<UInt32>.size),
            mChannelsPerFrame:  UInt32(nc),
            mBitsPerChannel:    UInt32(8 * (MemoryLayout<UInt32>.size)),
            mReserved:          UInt32(0)
        )
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input, outputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     inputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var inputCallbackStruct
            = AURenderCallbackStruct(inputProc: recordingCallback,
                                     inputProcRefCon:
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                                     AudioUnitScope(kAudioUnitScope_Global),
                                     inputBus,
                                     &inputCallbackStruct,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        // Ask CoreAudio to allocate buffers on render.
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
                                     AudioUnitScope(kAudioUnitScope_Output),
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        gTmp0 = Int(osErr)
    }
    
    private func tearDownAubio() {
        if let tempo = tempo, let out = out, let notes = notes, let samples = samples {
            del_aubio_notes(notes)
            del_aubio_tempo(tempo)
            del_fvec(samples)
            del_fvec(out)
            self.notes = nil
            self.tempo = nil
            self.samples = nil
        }
    }
}

var gTmp0 = 0 //  temporary variable for debugger viewing
// end of class RecordAudio
