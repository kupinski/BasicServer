import Network
import Foundation



/// A TCP server that is designed to handle only a single connection
open class SingleServer {
    public var connection: NWConnection? = nil
    
    public var commands: [(string: String, numArgs: Int, command: ([String])throws->())] = []

    
    /// The port number to connect to
    public var port: Int
    
    
    /// A description of the server status.  Check `listener.status` for actual status.
    open var serverStatus = ""
    
    // Network server and connection variables
    /// The listener waiting for client connections
    private var listener: NWListener
        
    /// Is the network busy transferring data.  If so, this will halt a request for more data.
    public var networkBusy = false
        
    
    /// A ListModeServer is used to model the camera server and requires a specific camera model to attach to as well as a ``dataProvider`` that will provide the data to send when requested by the client.
    /// - Parameters:
    ///   - forCamera: The camera model to attach to
    ///   - dataProvider: How the data are provided to this server.
    public init(onPort: Int) {
        port = onPort
                
        listener = try! NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: UInt16(port)))

        listener.stateUpdateHandler = serverStateUpdate(to: )
        listener.newConnectionHandler = newConnection(to: )
        
        listener.start(queue: .main)
    }
    
    open func unknownCommand(_ command: String) {
    }
    
    open func invalidArguments(_ command: String, args: [String]) {
    }

    
    func parseNetworkData(_ message: String) {
        let commandArray = message.components(separatedBy: .newlines)
        for msg in commandArray {
            var stringArray = msg.components(separatedBy: .whitespaces)
            
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
                    invalidArguments(enteredCommand, args: arguments)
                }
                catch {
                    print("Warning: Unknown error \(error)")
                }
            } else {
                print("Warning: Unknown command \"\(enteredCommand)\" with \(numArgs) arguments: \(arguments)")
                unknownCommand(enteredCommand)
            }
        }
    }
    

    
    
    /// A new commention has been requested.  Spawn a new process to serve this client.  NOTE.  Only one client is allowed to connect to the camera.
    /// - Parameter connection: The connection object
    public func newConnection(to connection: NWConnection) {
        if (self.connection != nil) {
            print("Warning: Currently only one connection is allowed per camera server")
        } else {
            self.connection = connection
            if case let .hostPort(host: host, port: _) = connection.endpoint {
                serverStatus = "Connection from \(host) is active"
            }
            start()
        }
    }
    
    
    /// Start the new connection queue
    public func start() {
        let connectionQueue = DispatchQueue(label: "New Connection", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        
        connection!.stateUpdateHandler = connectionStateUpdate(to: )
        
        awaitCommands()
        
        connection!.start(queue: connectionQueue)
    }
    
    /// Send a string through the connection
    /// - Parameter str: The string to send
    public func sendString(_ str: String) {
        connection?.send(content: (str + "\r\n").data(using: .utf8), isComplete: false, completion: .contentProcessed( { error in
            if let error = error {
                print("Error = \(error)")
                return
            }
        }))
    }

    
    
    /// Wait for input string commands
    func awaitCommands() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 512)  { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                guard let message = String(data: data, encoding: .utf8) else {
                    fatalError("Data Sync Error.  Awaiting command.")
                }
                
                self.parseNetworkData(message)
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
    
    func connectionStateUpdate(to newState: NWConnection.State) {
        switch (newState) {
        case .waiting(let inErr):
            connectionDidFail(error: inErr)
        case .failed(let inErr):
            connectionDidFail(error: inErr)
        default:
            break
        }
    }
    
    func connectionDidFail(error: Error) {
        serverStatus = "Connection failed"
        print("Connection did fail, error: \(error)")
        stop(error: error)
    }
    
    func connectionDidEnd() {
        serverStatus = "Connection ended.  Ready for new connection."
        print("Connection ended without error")
        self.stop(error: nil)
    }
    
    /// When a connection stops, we need to cancel it and set the connection variable to nil.  This will allow the client to reconnect if needed.
    /// - Parameter error: The error
    func stop(error: Error?) {
        self.connection?.stateUpdateHandler = nil
        self.connection?.cancel()
        self.connection = nil
    }

    
    
    
    
    /// The status of the server.
    /// - Parameter state: Changed server state
    func serverStateUpdate(to state: NWListener.State) {
        switch (state) {
        case .setup:
            self.serverStatus = "Setting up Server"
        case .waiting(let error):
            self.serverStatus = "Waiting with status: \(error)"
        case .ready:
            self.serverStatus = "Ready for connections"
        case .failed(let error):
            self.serverStatus = "Failed with status: \(error)"
        case .cancelled:
            self.serverStatus = "Server cancelled"
        default:
            self.serverStatus = "Unknown state = \(state)"
        }
        print(self.serverStatus)
    }

    
}
