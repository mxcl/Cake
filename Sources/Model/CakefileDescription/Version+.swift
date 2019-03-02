#if !Cake
@_exported import Version
#else
import Version
#endif

extension Version: ExpressibleByFloatLiteral {
    @inlinable
    public init(_ value: FloatLiteralType) {
        self.init(floatLiteral: value)
    }

    @inlinable
    public init(floatLiteral value: FloatLiteralType) {
        self = Version("\(value).0") ?? .null
    }
}
