import Testing
import Photos
import ExpoModulesCore

@testable import ExpoMediaLibrary

@Suite("AssetFieldPredicateBuilder")
struct AssetFieldPredicateBuilderTests {
  @Test(arguments: [AssetField.WIDTH, .CREATION_TIME], Input.allCases)
  func `single value compares the photos key with the converted value`(field: AssetField, input: Input) throws {
    let predicate = try AssetFieldPredicateBuilder.buildPredicate(
      assetField: field,
      value: EitherOfFour<MediaTypeNext, Int, Bool, MediaSubtypeNext>(input.value),
      symbol: "="
    )

    let expected: NSObject = switch (field, input) {
    case (.CREATION_TIME, .int(let milliseconds)):
      NSDate(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    default:
      input.expected
    }
    let comparison = try #require(predicate as? NSComparisonPredicate)
    #expect(comparison.leftExpression.keyPath == field.photosKey())
    #expect(comparison.predicateOperatorType == .equalTo)
    #expect(comparison.rightExpression.constantValue as? NSObject == expected)
  }

  @Test(arguments: [AssetField.WIDTH, .CREATION_TIME], Input.allCases)
  func `array value checks the photos key against the converted values`(field: AssetField, input: Input) throws {
    let predicate = try AssetFieldPredicateBuilder.buildPredicate(
      assetField: field,
      values: EitherOfFour<[MediaTypeNext], [Int], [Bool], [MediaSubtypeNext]>([input.value]),
      symbol: "IN"
    )

    let expected: NSObject = switch (field, input) {
    case (.CREATION_TIME, .int(let seconds)):
      NSDate(timeIntervalSince1970: TimeInterval(seconds))
    default:
      input.expected
    }
    let comparison = try #require(predicate as? NSComparisonPredicate)
    #expect(comparison.leftExpression.keyPath == field.photosKey())
    #expect(comparison.predicateOperatorType == .in)
    #expect(comparison.rightExpression.constantValue as? NSObject == NSArray(object: expected))
  }

  @Test(arguments: MediaSubtypeNext.allCases)
  func `single subtype checks that the photos key contains the subtype flag`(subtype: MediaSubtypeNext) throws {
    let predicate = try AssetFieldPredicateBuilder.buildPredicate(
      assetField: .MEDIA_SUBTYPE,
      value: EitherOfFour<MediaTypeNext, Int, Bool, MediaSubtypeNext>(subtype),
      symbol: "="
    )

    let comparison = try #require(predicate as? NSComparisonPredicate)
    #expect(comparison.leftExpression.function == "bitwiseAnd:with:")
    #expect(comparison.leftExpression.arguments?.first?.keyPath == "mediaSubtypes")
    #expect(comparison.leftExpression.arguments?.last?.constantValue as? NSObject == NSNumber(value: subtype.toPHAssetMediaSubtype().rawValue))
    #expect(comparison.predicateOperatorType == .notEqualTo)
    #expect(comparison.rightExpression.constantValue as? NSObject == NSNumber(value: 0))
  }

  @Test(arguments: MediaSubtypeNext.allCases)
  func `subtype array checks that the photos key contains any of the subtype flags`(subtype: MediaSubtypeNext) throws {
    let predicate = try AssetFieldPredicateBuilder.buildPredicate(
      assetField: .MEDIA_SUBTYPE,
      values: EitherOfFour<[MediaTypeNext], [Int], [Bool], [MediaSubtypeNext]>([subtype, MediaSubtypeNext.livePhoto]),
      symbol: "IN"
    )

    let mask = subtype.toPHAssetMediaSubtype().union(.photoLive)
    let comparison = try #require(predicate as? NSComparisonPredicate)
    #expect(comparison.leftExpression.function == "bitwiseAnd:with:")
    #expect(comparison.leftExpression.arguments?.first?.keyPath == "mediaSubtypes")
    #expect(comparison.leftExpression.arguments?.last?.constantValue as? NSObject == NSNumber(value: mask.rawValue))
    #expect(comparison.predicateOperatorType == .notEqualTo)
    #expect(comparison.rightExpression.constantValue as? NSObject == NSNumber(value: 0))
  }
}

enum Input: @unchecked Sendable {
  case bool(Bool)
  case int(Int)
  case mediaType(MediaTypeNext)

  static let allCases: [Input] = [.bool(true), .bool(false), .int(0), .int(1500)] + MediaTypeNext.allCases.map(Input.mediaType)

  var value: Any {
    switch self {
    case .bool(let value): return value
    case .int(let value): return value
    case .mediaType(let value): return value
    }
  }

  var expected: NSObject {
    switch self {
    case .bool(let value): return NSNumber(value: value)
    case .int(let value): return NSNumber(value: value)
    case .mediaType(let value): return NSNumber(value: value.toPHAssetMediaType().rawValue)
    }
  }
}
