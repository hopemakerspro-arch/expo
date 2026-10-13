import Photos
import ExpoModulesCore

class AssetFieldPredicateBuilder {
  static func buildPredicate(assetField: AssetField, value: Int, symbol: String) -> NSPredicate {
    if assetField == .CREATION_TIME || assetField == .MODIFICATION_TIME {
      let date = Date(milliseconds: value)
      return NSPredicate(format: "\(assetField.photosKey()) \(symbol) %@", argumentArray: [date])
    }
    return NSPredicate(format: "\(assetField.photosKey()) \(symbol) %@", argumentArray: [value])
  }

  static func buildPredicate(assetField: AssetField, value: MediaTypeNext, symbol: String) -> NSPredicate {
    let nsValue = value.toPHAssetMediaType().rawValue
    return NSPredicate(format: "\(assetField.photosKey()) \(symbol) %@", argumentArray: [nsValue])
  }

  static func buildPredicate(assetField: AssetField, values: [Int], symbol: String) -> NSPredicate {
    if assetField == .CREATION_TIME || assetField == .MODIFICATION_TIME {
      let dates = values.map { Date(timeIntervalSince1970: TimeInterval($0)) }
      return NSPredicate(format: "\(assetField.photosKey()) \(symbol) %@", argumentArray: [dates])
    }
    return NSPredicate(format: "\(assetField.photosKey()) \(symbol) %@", argumentArray: [values])
  }

  static func buildPredicate(assetField: AssetField, values: [MediaTypeNext], symbol: String) -> NSPredicate {
    let nsValues = values.map { $0.toPHAssetMediaType().rawValue }
    return NSPredicate(format: "\(assetField.photosKey()) \(symbol) %@", argumentArray: [nsValues])
  }

  static func buildPredicate(assetField: AssetField, value: Bool, symbol: String) -> NSPredicate {
    return NSPredicate(format: "\(assetField.photosKey()) \(symbol) %@", argumentArray: [NSNumber(value: value)])
  }

  static func buildPredicate(assetField: AssetField, values: [MediaSubtypeNext]) -> NSPredicate {
    let mask = values.reduce(PHAssetMediaSubtype()) { $0.union($1.toPHAssetMediaSubtype()) }
    return NSPredicate(format: "(\(assetField.photosKey()) & %@) != 0", argumentArray: [NSNumber(value: mask.rawValue)])
  }

  static func buildPredicate(assetField: AssetField, value: EitherOfFour<MediaTypeNext, Int, Bool, MediaSubtypeNext>, symbol: String) throws -> NSPredicate {
    if let subtype: MediaSubtypeNext = value.get() {
      return buildPredicate(assetField: assetField, values: [subtype])
    }
    if let boolVal: Bool = value.get() {
      return buildPredicate(assetField: assetField, value: boolVal, symbol: symbol)
    }
    if let intVal: Int = value.get() {
      return buildPredicate(assetField: assetField, value: intVal, symbol: symbol)
    }
    if let mediaVal: MediaTypeNext = value.get() {
      return buildPredicate(assetField: assetField, value: mediaVal, symbol: symbol)
    }
    throw PredicateBuilderException("Unsupported Either type for \(assetField)")
  }

  static func buildPredicate(assetField: AssetField, values: EitherOfFour<[MediaTypeNext], [Int], [Bool], [MediaSubtypeNext]>, symbol: String) throws -> NSPredicate {
    if let subtypes: [MediaSubtypeNext] = values.get() {
      return buildPredicate(assetField: assetField, values: subtypes)
    }
    if let boolValues: [Bool] = values.get() {
      let nsValues = boolValues.map { NSNumber(value: $0) }
      return NSPredicate(format: "\(assetField.photosKey()) \(symbol) %@", argumentArray: [nsValues])
    }
    if let intValues: [Int] = values.get() {
      return buildPredicate(assetField: assetField, values: intValues, symbol: symbol)
    }
    if let mediaValues: [MediaTypeNext] = values.get() {
      return buildPredicate(assetField: assetField, values: mediaValues, symbol: symbol)
    }
    throw PredicateBuilderException("Unsupported Either type for \(assetField)")
  }
}
