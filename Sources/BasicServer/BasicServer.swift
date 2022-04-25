import Network
import Foundation



/// A TCP that can handle multiple connections of type T
public class BasicServer<T: Connection> {
    /// The port number to connect to
    public var port: Int
    
    private var connectionType: T.Type
    
    /// A description of the server status.  Check `listener.status` for actual status.
    public var serverStatus = ""
    
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
        
        self.connectionType = T.self
        
        listener = try! NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: UInt16(port)))

        listener.stateUpdateHandler = serverStateUpdate(to: )
        listener.newConnectionHandler = newConnection(to: )
        
        listener.start(queue: .main)
    }
    
    
    /// A new commention has been requested.  Spawn a new process to serve this client.  NOTE.  Only one client is allowed to connect to the camera.
    /// - Parameter connection: The connection object
    public func newConnection(to connection: NWConnection) {
        print("New connection")
        let _ = T(connection)
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
