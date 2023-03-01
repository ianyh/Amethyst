//
//  ApplicationEventHandler.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 2/28/23.
//  Copyright © 2023 Ian Ynda-Hummel. All rights reserved.
//

import Carbon
import Foundation

// swiftlint:disable identifier_name
@_silgen_name("GetProcessPID") @discardableResult
func GetProcessPID(_ psn: inout ProcessSerialNumber, _ pid: inout pid_t) -> OSStatus
// swiftlint:enable identifier_name

protocol ApplicationEventHandlerDelegate: AnyObject {
    func add(applicationWithPID: pid_t)
    func remove(applicationWithPID: pid_t)
}

func applicationEventHandlerUPP(_ call: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?) -> OSStatus {
    guard let data = data, let event = event else {
        return OSStatus(eventNotHandledErr)
    }

    let handler = Unmanaged<ApplicationEventHandler>.fromOpaque(data).takeUnretainedValue()
    return handler.handleEvent(event)
}

class ApplicationEventHandler {
    private enum EventType {
        case applicationLaunched
        case applicationTerminated
    }

    private enum EventError: Error {
        case failedToGetPSN
        case failedToGetPID
        case processNotFound
    }

    private struct Event {
        let ref: EventRef
        let eventType: EventType

        func pid() throws -> pid_t {
            var psn = ProcessSerialNumber()
            var error = GetEventParameter(ref, EventParamName(kEventParamProcessID), EventParamName(typeProcessSerialNumber), nil, MemoryLayout<ProcessSerialNumber>.size, nil, &psn)
            guard error == noErr else {
                log.error(error)
                throw EventError.failedToGetPSN
            }

            var pid = pid_t()
            error = GetProcessPID(&psn, &pid)

            guard error == noErr else {
                switch error {
                case OSStatus(procNotFound):
                    throw EventError.processNotFound
                default:
                    throw EventError.failedToGetPID
                }
            }

            return pid
        }
    }

    weak var delegate: ApplicationEventHandlerDelegate?

    init(delegate: ApplicationEventHandlerDelegate) {
        self.delegate = delegate
    }

    func handleEvent(_ event: EventRef) -> OSStatus {
        switch GetEventKind(event) {
        case UInt32(kEventAppLaunched):
            return processEvent(Event(ref: event, eventType: .applicationLaunched))
        case UInt32(kEventAppTerminated):
            return processEvent(Event(ref: event, eventType: .applicationTerminated))
        default:
            return OSStatus(eventNotHandledErr)
        }
    }

    private func processEvent(_ event: Event) -> OSStatus {
        do {
            let pid = try event.pid()
            switch event.eventType {
            case .applicationLaunched:
                delegate?.add(applicationWithPID: pid)
            case .applicationTerminated:
                delegate?.remove(applicationWithPID: pid)
            }
        } catch {
            log.error(error)
            return OSStatus(eventNotHandledErr)
        }

        return noErr
    }
}
