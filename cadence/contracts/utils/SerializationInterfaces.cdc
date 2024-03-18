/// The contract defines an interface for serialization strategies that can be used to serialize the struct or resource
/// according to a specific format.
///
access(all) contract SerializationInterfaces {
    
    /// A SerializationStrategy takes a reference to a SerializableResource or SerializableStruct and returns a
    /// serialized representation of it. The strategy is responsible for determining the structure of the serialized
    /// representation and the format of the serialized data.
    ///
    access(all)
    struct interface SerializationStrategy {
        /// Returns the types supported by the implementing strategy
        ///
        access(all) view fun getSupportedTypes(): [Type] {
            return []
        }

        /// Returns serialized representation of the given resource according to the format of the implementing strategy
        ///
        access(all) fun serializeResource(_ r: &AnyResource): String? {
            return nil
        }

        /// Returns serialized representation of the given struct according to the format of the implementing strategy
        ///
        access(all) fun serializeStruct(_ s: AnyStruct): String? {
            return nil
        }
    }
}
