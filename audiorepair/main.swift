//
//  main.swift
//  audiorepair
//
//  Created by Daniel Almeida on 08/06/2022.
//

import Foundation
import AudioToolbox
import AudioUnit

enum Errors: Error {
    case FileLoadingError
    case FileCreateError
    case FileInformationRetrievalError(status: OSStatus)
}

/**
 Opens a file
 
 -  Parameter filePath: the full path to the audio file
 - Parameter permissions: the permission to open the file
 
 - Throws: Errors.FileLoadingError
 
 - Returns: an AudioFileID OpaquePointer for an existing audio file
 */
func openFile(
    filePath: String,
    permissions: AudioFilePermissions = AudioFilePermissions.readPermission
) throws -> AudioFileID {
    let fileURL = NSURL(fileURLWithPath: filePath)
    var audioFile = AudioFileID(bitPattern: 128)
    let res = AudioFileOpenURL(fileURL, permissions, 0, &audioFile)

    guard res == noErr else {
        throw Errors.FileLoadingError
    }
    
    return audioFile! as AudioFileID
}


/**
 Opens a new audio file
 
 - Parameter filePath:
 - Parameter description:
 
 - Throws: Errors.FileCreateError
 
 - Returns: a  AudioFileID OpaquePointer for a new open file
 */
func createFile(
    filePath: String,
    description: inout AudioStreamBasicDescription
) throws -> AudioFileID {
    let fileURL = NSURL(fileURLWithPath: filePath)
    var audioFile = AudioFileID(bitPattern: 128)
    
    let res = AudioFileCreateWithURL(
        fileURL,
        kAudioFileWAVEType,
        &description,
        AudioFileFlags.dontPageAlignAudioData,
        &audioFile)

    guard res == noErr else {
        throw Errors.FileCreateError
    }
    
    return audioFile! as AudioFileID
}


/**
 Gets information from a audio file in a dictionary
 
 - Parameter audioFile: the opaque pointer to the opened audio file
 
 - Throws: Errors.FileInformationRetrievalError
 
 - Returns: a dictionary with file information
 */
func getFileInformation(audioFile: AudioFileID) throws -> NSDictionary {
    var size: UInt32 =  0
    var status = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &size, nil)
    
    guard status == noErr else {
        throw Errors.FileInformationRetrievalError(status: status)
    }

    var infoDictionary = NSDictionary()
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &size, &infoDictionary)
    
    guard status == noErr else {
        throw Errors.FileInformationRetrievalError(status: status)
    }
    
    return infoDictionary
}



let inputFilePath: String = "/Users/daniel/Documentos/Rips/DUB.wav"
var audioFile: AudioFileID
var infoDictionary = NSDictionary()

do {
    try audioFile = openFile(filePath: inputFilePath)
    try infoDictionary = getFileInformation(audioFile: audioFile)
}
catch Errors.FileLoadingError{
    print ("Error opening file \(inputFilePath)")
    exit(-1)
}
catch Errors.FileInformationRetrievalError(let status) {
    print("An error occurred while getting the info dictionary property: Error code \(status).")
    exit(-1)
}

print(infoDictionary);

// read all audio  units (this isn't neededd for now
var inDesc = AudioComponentDescription(componentType: OSType(),
                                    componentSubType: OSType(),
                               componentManufacturer: OSType(),
                                      componentFlags: UInt32(0),
                                  componentFlagsMask: UInt32(0))
let numberOfAudioUnits = AudioComponentCount(&inDesc)
print ("Found \(numberOfAudioUnits) audio units")




var outputAudioFile: AudioFileID
var outputFileDescription: AudioStreamBasicDescription = AudioStreamBasicDescription()

do {
    try outputAudioFile = createFile(filePath: "/Users/daniel/output.wav", description: &outputFileDescription)
}
catch {
    print ("Error open destiny file.")
    exit(-1)
}



//

var numBytes: UInt32 = 128;
var packetDescription: AudioStreamPacketDescription =  AudioStreamPacketDescription()
var currentPacket = 0;
var ioNumPackets: UInt32 = 1;
var outBuffer: UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(numBytes), alignment: 1);

while AudioFileReadPacketData(audioFile, false, &numBytes, &packetDescription, Int64(currentPacket), &ioNumPackets, outBuffer) == noErr {
    
    AudioFileWritePackets(outputAudioFile, false, numBytes, &packetDescription, Int64(currentPacket), &ioNumPackets, outBuffer)
    currentPacket+=1
}


AudioFileClose(audioFile)
AudioFileClose(outputAudioFile)
