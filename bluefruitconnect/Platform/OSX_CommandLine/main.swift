//
//  main.swift
//  BluefruitCommandLine
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

func main() {
    
    enum Command: String {
        case Version = "-v"
        case Version2 = "--version"
        case Help = "-h"
        case Help2 = "--help"
        case Scan = "scan"
        case Dfu = "dfu"
    }
    
    enum Parameter: String {
        case PeripheralUuid = "-uuid"
        case HexFile = "-hex"
        case IniFile = "-init"
    }
    
    // Data
    let group = dispatch_group_create()
    let queue = dispatch_queue_create("", DISPATCH_QUEUE_CONCURRENT)
    let commandLine = CommandLine()
    
    var command: Command?
    var peripheralUuid: String?
    var hexUrl: NSURL?
    var iniUrl: NSURL?
    
    let currentDirectoryUrl = NSURL(fileURLWithPath: NSFileManager.defaultManager().currentDirectoryPath)
    
    
    // Process arguments
    var arguments = Process.arguments
    arguments.removeFirst()     // remove path
    var skipNextArgument = false
    for (index, argument) in arguments.enumerate() {
        
        if !skipNextArgument {
            
            switch argument.lowercaseString {
            
            case Command.Version.rawValue, Command.Version2.rawValue:
                command = .Version
                
            case Command.Help.rawValue, Command.Help2.rawValue:
                command = .Help
                
            case Command.Scan.rawValue:
                command = .Scan
                
            case Command.Dfu.rawValue:
                command = .Dfu
                
            case Parameter.PeripheralUuid.rawValue:
                peripheralUuid = nil
                if arguments.count >= index+1 {
                    peripheralUuid = arguments[index+1]
                    skipNextArgument = true
                }
                
                if peripheralUuid == nil {
                    print("\(Parameter.PeripheralUuid.rawValue) needs a valid peripheral identifier")
                }
                
            case Parameter.HexFile.rawValue:
                hexUrl = nil
                if arguments.count >= index+1 {
                    let hexFileName = arguments[index+1]
                    hexUrl = currentDirectoryUrl.URLByAppendingPathComponent(hexFileName)
                    
                    //                DLog("hex: \(hexFileName!)")
                    skipNextArgument = true
                }
                
                if hexUrl == nil {
                    print("\(Parameter.HexFile.rawValue) needs a valid file name")
                }
                
            case Parameter.IniFile.rawValue:
                iniUrl = nil
                if arguments.count >= index+1 {
                    let iniFileName = arguments[index+1]
                    iniUrl = currentDirectoryUrl.URLByAppendingPathComponent(iniFileName)
                    skipNextArgument = true
                }
                
                if iniUrl == nil {
                    print("\(Parameter.IniFile.rawValue) needs a valid file name")
                }
                
            default:
                DLog("unknown argument: \(argument)")
                
            }
        }
        else {
            skipNextArgument = false
        }
    }
    
    // Check Bluetooth Errors
    let errorMessage = commandLine.checkBluetoothErrors()
    guard errorMessage == nil else {
        print(errorMessage)
        exit(EXIT_FAILURE)
    }
    
    
    // Execute order
    if let command = command {
        switch command {
        case .Version:
            commandLine.showVersion()

        case .Help:
            commandLine.showVersion()

        case .Scan:
            print("Scannnig...")
            commandLine.startScanning()
            let _ = readLine(stripNewline: true)
            
        case .Dfu:
            print("DFU Update")
            guard let hexUrl = hexUrl else {
                print(".hex file not defined")
                exit(EXIT_FAILURE)
            }
            
            if peripheralUuid == nil {
                print("Select a peripheral for dfu. Scanning...")
                
                commandLine.startScanningAndShowIndex(true)
                let peripheralIndexString = readLine(stripNewline: true)
                //0DLog("selected: \(peripheralIndexString)")
                if let peripheralIndexString = peripheralIndexString, peripheralIndex = Int(peripheralIndexString) where peripheralIndex>=0 && peripheralIndex < commandLine.discoveredPeripheralsIdentifiers.count {
                    peripheralUuid = commandLine.discoveredPeripheralsIdentifiers[peripheralIndex]
                    
                    print("Selected UUID: \(peripheralUuid!)")
                    commandLine.stopScanning()
                }
            }
            
            guard let peripheralUuid = peripheralUuid else {
                print("Peripheral UUID invalid")
                exit(EXIT_FAILURE)
            }
            
            print("\tuuid: \(peripheralUuid)")
            print("\thex:  \(hexUrl)")
            if let iniUrl = iniUrl {
                print("\tinit: \(iniUrl)")
            }
            
            dispatch_group_async(group, queue) {
                commandLine.dfuPeripheralWithUUIDString(peripheralUuid, hexUrl: hexUrl, iniUrl: iniUrl)
            }
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
            
        default:
            print("Unknown command: \(command.rawValue)")
            break
        }
    }
    else {
        commandLine.showHelp()
    }
    
    exit(EXIT_SUCCESS)
}


let runloop = CFRunLoopGetCurrent()
CFRunLoopPerformBlock(runloop, kCFRunLoopDefaultMode) { () -> Void in
    dispatch_async(dispatch_queue_create("main", nil)) {
        main()
        CFRunLoopStop(runloop)
    }
}
CFRunLoopRun()