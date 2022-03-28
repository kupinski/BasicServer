//
//  File.swift
//  
//
//  Created by Matthew Kupinski on 3/28/22.
//

import Foundation
import Network



/// A connection error that may be thrown when something goes wrong with a connection.
public enum ConnectionError : Error {
    case invalidArguments(args: [String])
}


/// An individual client connection manager.  The primary variable to set is `commands` which is a Tuple of command strings, the number of arguments for the command, and the method to call when the command is received.
public protocol Connection {
    var connection: NWConnection { get set }
    
    
    /// A description of the client connection status.  Check `connection.status` for actual status.
    var connectionStatus: String { get set }
    
    /// Specify the command strings,  their number of arguments, and the command method to call
    var commands: [(string: String, numArgs: Int, command: ([String])throws->()  )] { get set }
    
    /// Create a new server connection
    /// - Parameter connection: The Network.framework connection
    init(_ connection: NWConnection)
    
    /// Parse a network message.
    /// - Parameter message: The message with white space or new lines separating out the various arguments.
    func parseNetworkData(_ message: String)
    
    /// Listen for commands and parse them.
    func awaitCommands()
    
    /// Change the status of the client connection
    /// - Parameter newState: The new state
   func connectionStateUpdate(to newState: NWConnection.State)
    
    
    /// The connection failed.  Stop everything
    /// - Parameter error: The error message
   func connectionDidFail(error: Error)
    
    /// The connection ended.  Stop everything
    func connectionDidEnd()
    
    /// When a connection stops, we need to cancel it and set the connection variable to nil.  This will allow the client to reconnect if needed.
    /// - Parameter error: The error
    func stop(error: Error?)
}



//  The default implementation.
public extension Connection {

    
    init(_ connection: NWConnection) {
        self.init(connection)
        
        self.connectionStatus = ""
        
        self.connection = connection
        
        let connectionQueue = DispatchQueue(label: "New Connection",
                                            qos: .userInitiated,
                                            attributes: [],
                                            autoreleaseFrequency: .inherit,
                                            target: nil)
        
        connection.stateUpdateHandler = connectionStateUpdate(to: )
        
        awaitCommands()
        
        connection.start(queue: connectionQueue)
    }
        
    
    func parseNetworkData(_ message: String) {
        var stringArray = message.components(separatedBy: .whitespacesAndNewlines)
        
        // First string is the command
        let enteredCommand = stringArray.remove(at: 0)
        
        // All others are arguments.  Filter out the empty ones.
        let arguments = stringArray.filter({$0 != ""})
        let numArgs = arguments.count
        
        let matchingCommand = self.commands.filter({
            ($0.string == enteredCommand) && ($0.numArgs == numArgs)
        })
        if matchingCommand.count == 1 {
            do {
                try matchingCommand[0].command(arguments)
            }
            catch ConnectionError.invalidArguments(args: arguments) {
                print("Warning: The command \"\(enteredCommand)\" was passed the following invalid arguments \(arguments)")
            }
            catch {
                print("Warning: Unknown error \(error)")
            }
        } else {
            print("Warning: Unknown command \"\(enteredCommand)\" with \(numArgs) arguments: \(arguments)")
        }
    }
    
    
    func awaitCommands() {
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512)  { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                while (!data.isEmpty) {
                    guard let message = String(data: data, encoding: .utf8) else {
                        fatalError("Data Sync Error.  Awaiting command.")
                    }
                    
                    self.parseNetworkData(message)
                }
            }
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            } else {
                self.awaitCommands()
            }
        }
    }
    
    mutating func connectionStateUpdate(to newState: NWConnection.State) {
        switch (newState) {
        case .ready:
            connectionStatus = "Ready"
        case .setup:
            connectionStatus = "Setup"
        case .cancelled:
            connectionStatus = "Cancelled"
        case .preparing:
            connectionStatus = "Preparring"
        case .waiting(let inErr):
            connectionStatus = "Waiting \(inErr)"
            connectionDidFail(error: inErr)
        case .failed(let inErr):
            connectionStatus = "Failed \(inErr)"
            connectionDidFail(error: inErr)
        default:
            break
        }
    }
    
    func connectionDidFail(error: Error) {
        print("Connection did fail, error: \(error)")
        stop(error: error)
    }
    
    private func connectionDidEnd() {
        print("Connection ended without error")
        self.stop(error: nil)
    }
    
    /// When a connection stops, we need to cancel it and set the connection variable to nil.  This will allow the client to reconnect if needed.
    /// - Parameter error: The error
    private func stop(error: Error?) {
        self.connection.stateUpdateHandler = nil
        self.connection.cancel()
    }
    
}


