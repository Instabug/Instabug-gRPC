# Instabug-gRPC
This is a destination for Instabug to support logging gRPC requests.

## Compatibility
Note that Instabug_gRPC_Swift is a Swift framework and intended to be used with Swift projects for now.

## Installation

Add pod `Instabug_gRPC_Swift` to your `podfile`

## Requirements

iOS version >= 10.0


## Example
1. Make sure you import our destination first: `import Instabug_gRPC_Swift`
2. Create Interceptor factory that confirms to the interceptor factory protocol that you have in your .grpc file
3. Make sure to return new instance of our Interceptor `InstabugClientInterceptor()` in the methods that you need us to log
 

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

```

And finally pass `ExampleClientInterceptorFactory()` to your client like this

```
let client = Echo_EchoClient(channel: channel, interceptors: ExampleClientInterceptorFactory())

```
