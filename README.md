# Instabug-gRPC
This is a destination for Instabug to support logging gRPC requests.

## Compatibility
There's `Instabug_gRPC_Swift` which is a Swift framework and intended to be used with Swift projects. And there's `Instabug_gRPC_Objc` which intended to be used with Objective-C projects

## Installation

Add pod `Instabug_gRPC_Swift` or pod `'Instabug-gRPC-ObjC'` to your `podfile`

## Requirements

iOS version >= 10.0
Instabug version >= 10.11.8

## Swift Example
1. Make sure you import our destination first: `import Instabug_gRPC_Swift`
2. Create Interceptor factory that confirms to the interceptor factory protocol that you have in your .grpc file
3. Make sure to return new instance of our Interceptor `InstabugClientInterceptor()` in the methods that you need us to log
4. Conform on `InstabugGRPCDataProtocol` for request and response models which requires that you expose your models as `Data`
5. You can convert your model to `Data` by conforming on `Encodable`
6. You can pass the port optional in `InstabugClientInterceptor` as `InstabugClientInterceptor(port: <#T##Int?#>)` to see it on the dashboard
 
### Sample code 

```
class ExampleClientInterceptorFactory: Echo_EchoClientInterceptorFactoryProtocol {
  // Returns an array of interceptors to use for the 'Get' RPC.
  func makeGetInterceptors() -> [ClientInterceptor<Echo_EchoRequest, Echo_EchoResponse>] {
    return [InstabugClientInterceptor()]
  }

  // Returns an array of interceptors to use for the 'Expand' RPC.
  func makeExpandInterceptors() -> [ClientInterceptor<Echo_EchoRequest, Echo_EchoResponse>] {
    return [InstabugClientInterceptor()]
  }

  // Returns an array of interceptors to use for the 'Collect' RPC.
  func makeCollectInterceptors() -> [ClientInterceptor<Echo_EchoRequest, Echo_EchoResponse>] {
    return [InstabugClientInterceptor()]
  }

  // Returns an array of interceptors to use for the 'Update' RPC.
  func makeUpdateInterceptors() -> [ClientInterceptor<Echo_EchoRequest, Echo_EchoResponse>] {
    return [InstabugClientInterceptor()]
  }
}

extension GrpcAutomation_RepeaterRequest: InstabugGRPCDataProtocol, Encodable {
    enum CodingKeys: String, CodingKey {
        case message, unknownFields
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
    }
    
    public var gRPCRequestData: Data? {
        let jsonEncoder = JSONEncoder()
        let data = try? jsonEncoder.encode(self)
        return data
    }
```

And finally pass `ExampleClientInterceptorFactory()` to your client like this


```
let client = Echo_EchoClient(channel: channel, interceptors: ExampleClientInterceptorFactory())
```

## ObjectiveC Example
1. Create an array of `GRPCInterceptorFactory`
2. Create a class that conforms to `GRPCInterceptorFactory` protocol

	```
	@interface GRPCFactory : NSObject <GRPCInterceptorFactory>
	```

3. Override `createInterceptorWithManager` in `GRPCFactory` and return `InstabugClientInterceptor `

	```
	- (nonnull GRPCInterceptor *)createInterceptorWithManager:(nonnull GRPCInterceptorManager *)interceptorManager {
	    InstabugClientInterceptor *interceptor = [[InstabugClientInterceptor alloc] initWithInterceptorManager:interceptorManager dispatchQueue:dispatch_get_main_queue()];
	    return  interceptor;
	}
	```
4. Create a new instance from `GRPCFactory` then add it to the interceptors array
5. Create a new instance of `GRPCInterceptorManager` with the `interceptorFactories` array
6. Then pass the manager to the factory instance then 
7. Finally pass `interceptorFactories` to `options.interceptorFactories`

### Sample code

```
    GRPCMutableCallOptions *options = [[GRPCMutableCallOptions alloc] init];
    
    NSMutableArray<id<GRPCInterceptorFactory>> *interceptorFactories = [NSMutableArray new];
  
    GRPCFactory *factory = [GRPCFactory new];
    [interceptorFactories addObject:factory];
    GRPCInterceptorManager *manager = [[GRPCInterceptorManager alloc] initWithFactories:interceptorFactories
                                                                    previousInterceptor:nil
                                                                            transportID:GRPCDefaultTransportImplList.core_insecure];

    [factory createInterceptorWithManager:manager];
    options.interceptorFactories = interceptorFactories;

```