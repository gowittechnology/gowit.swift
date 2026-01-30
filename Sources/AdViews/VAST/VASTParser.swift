import Foundation

// MARK: - VAST Parser

/// Parser for VAST 4.2 XML responses
public final class VASTParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    
    /// Maximum depth for following Wrapper redirects
    public static let defaultMaxWrapperDepth = 5
    
    /// Timeout for network requests
    public static let defaultTimeout: TimeInterval = 30
    
    private var response: VASTResponse?
    private var currentAd: VASTAd?
    private var currentInLine: VASTInLine?
    private var currentWrapper: VASTWrapper?
    private var currentCreative: VASTCreative?
    private var currentLinear: VASTLinear?
    private var currentMediaFile: VASTMediaFile?
    private var currentVideoClicks: VASTVideoClicks?
    private var currentTrackingEvent: VASTTrackingEvent?
    private var currentAdSystem: VASTAdSystem?
    private var currentImpression: VASTImpression?
    private var currentViewableImpression: VASTViewableImpression?
    
    private var elementStack: [String] = []
    private var currentContent: String = ""
    private var currentAttributes: [String: String] = [:]
    
    // Temporary storage during parsing
    private var ads: [VASTAd] = []
    private var impressions: [VASTImpression] = []
    private var errors: [String] = []
    private var creatives: [VASTCreative] = []
    private var mediaFiles: [VASTMediaFile] = []
    private var trackingEvents: [VASTTrackingEvent] = []
    private var clickTracking: [String] = []
    private var customClick: [String] = []
    private var viewable: [String] = []
    private var notViewable: [String] = []
    private var viewUndetermined: [String] = []
    
    // Product extension parsing
    private var products: [VASTProduct] = []
    private var currentProductAdvertiserID: String?
    private var currentProductBrand: String?
    private var currentProductImageURL: String?
    private var currentProductName: String?
    private var currentProductPdpURL: String?
    private var currentProductPrice: Double?
    private var currentProductRating: Double?
    private var currentProductSku: String?
    private var currentProductStockCount: Int?
    private var isParsingExtensionProduct = false
    
    private var vastVersion: String = "4.2"
    private var clickThrough: String?
    private var vastAdTagURI: String?
    private var adTitle: String?
    
    // Ad element attributes - stored when Ad starts
    private var currentAdId: String?
    private var currentAdSequence: Int?
    
    // Creative element attributes - stored when Creative starts
    private var currentCreativeId: String?
    private var currentCreativeSequence: Int?
    private var currentCreativeAdId: String?
    
    // Linear element attributes - stored when Linear starts
    private var currentSkipOffset: String?
    
    private var parseError: Error?
    
    // MARK: - Public API
    
    /// Parse VAST XML data
    /// - Parameter data: XML data to parse
    /// - Returns: Parsed VAST response
    /// - Throws: VASTError if parsing fails
    public func parse(data: Data) throws -> VASTResponse {
        reset()
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        let success = parser.parse()
        
        if let error = parseError {
            throw error
        }
        
        if !success {
            throw VASTError.parsingError("Failed to parse VAST XML")
        }
        
        guard let response = response else {
            throw VASTError.parsingError("No VAST response found")
        }
        
        if response.isEmpty {
            throw VASTError.noAdsFound
        }
        
        return response
    }
    
    /// Fetch and parse VAST from URL, following wrappers
    /// - Parameters:
    ///   - url: VAST tag URL
    ///   - maxWrapperDepth: Maximum wrapper redirects to follow
    ///   - timeout: Request timeout
    /// - Returns: Resolved VAST response with InLine ad
    public func fetchAndParse(
        url: URL,
        maxWrapperDepth: Int = defaultMaxWrapperDepth,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> VASTResponse {
        return try await fetchAndParse(url: url, currentDepth: 0, maxWrapperDepth: maxWrapperDepth, timeout: timeout)
    }
    
    // MARK: - Private Methods
    
    private func fetchAndParse(
        url: URL,
        currentDepth: Int,
        maxWrapperDepth: Int,
        timeout: TimeInterval
    ) async throws -> VASTResponse {
        if currentDepth > maxWrapperDepth {
            throw VASTError.wrapperDepthExceeded(maxWrapperDepth)
        }
        
        let data = try await fetchData(from: url, timeout: timeout)
        let response = try parse(data: data)
        
        // Check if we need to follow a wrapper
        if let ad = response.firstAd, let wrapper = ad.wrapper {
            guard let wrapperURL = URL(string: wrapper.vastAdTagURI) else {
                throw VASTError.invalidURL(wrapper.vastAdTagURI)
            }
            
            // Recursively fetch the wrapped VAST
            let wrappedResponse = try await fetchAndParse(
                url: wrapperURL,
                currentDepth: currentDepth + 1,
                maxWrapperDepth: maxWrapperDepth,
                timeout: timeout
            )
            
            // Merge wrapper tracking with the resolved ad
            return mergeWrapperWithInLine(wrapper: wrapper, wrappedResponse: wrappedResponse, originalAd: ad)
        }
        
        return response
    }
    
    private func fetchData(from url: URL, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VASTError.networkError("Invalid response type")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw VASTError.networkError("HTTP error: \(httpResponse.statusCode)")
            }
            
            return data
        } catch let error as VASTError {
            throw error
        } catch {
            throw VASTError.networkError(error.localizedDescription)
        }
    }
    
    private func mergeWrapperWithInLine(wrapper: VASTWrapper, wrappedResponse: VASTResponse, originalAd: VASTAd) -> VASTResponse {
        guard let wrappedAd = wrappedResponse.firstAd,
              let inLine = wrappedAd.inLine else {
            return wrappedResponse
        }
        
        // Merge impressions
        var mergedImpressions = wrapper.impressions
        mergedImpressions.append(contentsOf: inLine.impressions)
        
        // Merge errors
        var mergedErrors = wrapper.errors
        mergedErrors.append(contentsOf: inLine.errors)
        
        // Merge viewable impressions
        var mergedViewable: [String] = []
        var mergedNotViewable: [String] = []
        var mergedViewUndetermined: [String] = []
        
        if let wrapperVI = wrapper.viewableImpression {
            mergedViewable.append(contentsOf: wrapperVI.viewable)
            mergedNotViewable.append(contentsOf: wrapperVI.notViewable)
            mergedViewUndetermined.append(contentsOf: wrapperVI.viewUndetermined)
        }
        
        if let inLineVI = inLine.viewableImpression {
            mergedViewable.append(contentsOf: inLineVI.viewable)
            mergedNotViewable.append(contentsOf: inLineVI.notViewable)
            mergedViewUndetermined.append(contentsOf: inLineVI.viewUndetermined)
        }
        
        let mergedViewableImpression: VASTViewableImpression?
        if !mergedViewable.isEmpty || !mergedNotViewable.isEmpty || !mergedViewUndetermined.isEmpty {
            mergedViewableImpression = VASTViewableImpression(
                viewable: mergedViewable,
                notViewable: mergedNotViewable,
                viewUndetermined: mergedViewUndetermined
            )
        } else {
            mergedViewableImpression = nil
        }
        
        // Merge creatives (tracking events)
        var mergedCreatives = inLine.creatives
        for wrapperCreative in wrapper.creatives {
            if let wrapperLinear = wrapperCreative.linear {
                for (index, creative) in mergedCreatives.enumerated() {
                    if let linear = creative.linear {
                        // Merge tracking events
                        var mergedTracking = linear.trackingEvents
                        mergedTracking.append(contentsOf: wrapperLinear.trackingEvents)
                        
                        // Merge click tracking
                        var mergedClickTracking = linear.videoClicks?.clickTracking ?? []
                        mergedClickTracking.append(contentsOf: wrapperLinear.videoClicks?.clickTracking ?? [])
                        
                        let mergedVideoClicks = VASTVideoClicks(
                            clickThrough: linear.videoClicks?.clickThrough,
                            clickTracking: mergedClickTracking,
                            customClick: linear.videoClicks?.customClick ?? []
                        )
                        
                        let mergedLinear = VASTLinear(
                            duration: linear.duration,
                            mediaFiles: linear.mediaFiles,
                            videoClicks: mergedVideoClicks,
                            trackingEvents: mergedTracking,
                            skipOffset: linear.skipOffset
                        )
                        
                        mergedCreatives[index] = VASTCreative(
                            id: creative.id,
                            sequence: creative.sequence,
                            adId: creative.adId,
                            linear: mergedLinear
                        )
                    }
                }
            }
        }
        
        let mergedInLine = VASTInLine(
            adSystem: inLine.adSystem ?? wrapper.adSystem,
            adTitle: inLine.adTitle,
            impressions: mergedImpressions,
            errors: mergedErrors,
            viewableImpression: mergedViewableImpression,
            creatives: mergedCreatives
        )
        
        let mergedAd = VASTAd(
            id: originalAd.id,
            sequence: originalAd.sequence,
            inLine: mergedInLine,
            wrapper: nil
        )
        
        return VASTResponse(version: wrappedResponse.version, ads: [mergedAd])
    }
    
    private func reset() {
        response = nil
        currentAd = nil
        currentInLine = nil
        currentWrapper = nil
        currentCreative = nil
        currentLinear = nil
        currentMediaFile = nil
        currentVideoClicks = nil
        currentTrackingEvent = nil
        currentAdSystem = nil
        currentImpression = nil
        currentViewableImpression = nil
        
        elementStack = []
        currentContent = ""
        currentAttributes = [:]
        
        ads = []
        impressions = []
        errors = []
        creatives = []
        mediaFiles = []
        trackingEvents = []
        clickTracking = []
        customClick = []
        viewable = []
        notViewable = []
        viewUndetermined = []
        
        vastVersion = "4.2"
        clickThrough = nil
        vastAdTagURI = nil
        adTitle = nil
        
        // Reset product parsing state
        products = []
        currentProductAdvertiserID = nil
        currentProductBrand = nil
        currentProductImageURL = nil
        currentProductName = nil
        currentProductPdpURL = nil
        currentProductPrice = nil
        currentProductRating = nil
        currentProductSku = nil
        currentProductStockCount = nil
        isParsingExtensionProduct = false
        
        // Reset Ad element attributes
        currentAdId = nil
        currentAdSequence = nil
        
        // Reset Creative element attributes
        currentCreativeId = nil
        currentCreativeSequence = nil
        currentCreativeAdId = nil
        
        // Reset Linear element attributes
        currentSkipOffset = nil
        
        parseError = nil
    }
    
    // MARK: - XMLParserDelegate
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        elementStack.append(elementName)
        currentContent = ""
        currentAttributes = attributeDict
        
        switch elementName {
        case "VAST":
            vastVersion = attributeDict["version"] ?? "4.2"
            
        case "Ad":
            // Start a new ad - save attributes
            currentAdId = attributeDict["id"] ?? UUID().uuidString
            currentAdSequence = Int(attributeDict["sequence"] ?? "")
            impressions = []
            errors = []
            creatives = []
            clickThrough = nil
            vastAdTagURI = nil
            adTitle = nil
            
        case "InLine":
            impressions = []
            errors = []
            creatives = []
            products = []
            
        case "Wrapper":
            impressions = []
            errors = []
            creatives = []
            
        case "Creative":
            // Save Creative attributes
            currentCreativeId = attributeDict["id"]
            currentCreativeSequence = Int(attributeDict["sequence"] ?? "")
            currentCreativeAdId = attributeDict["adId"]
            trackingEvents = []
            mediaFiles = []
            clickTracking = []
            customClick = []
            
        case "Linear":
            // Save Linear attributes
            currentSkipOffset = attributeDict["skipoffset"]
            trackingEvents = []
            mediaFiles = []
            clickTracking = []
            customClick = []
            clickThrough = nil
            
        case "VideoClicks":
            clickTracking = []
            customClick = []
            clickThrough = nil
            
        case "ViewableImpression":
            viewable = []
            notViewable = []
            viewUndetermined = []
            
        case "Extension":
            if attributeDict["type"] == "product" {
                isParsingExtensionProduct = true
            }
            
        case "Product":
            if isParsingExtensionProduct {
                // Reset current product properties
                currentProductAdvertiserID = nil
                currentProductBrand = nil
                currentProductImageURL = nil
                currentProductName = nil
                currentProductPdpURL = nil
                currentProductPrice = nil
                currentProductRating = nil
                currentProductSku = nil
                currentProductStockCount = nil
            }
            
        default:
            break
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentContent += string
    }
    
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            currentContent += string
        }
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let content = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch elementName {
        case "VAST":
            response = VASTResponse(version: vastVersion, ads: ads)
            
        case "Ad":
            let id = currentAdId ?? UUID().uuidString
            let sequence = currentAdSequence
            
            if let inLine = currentInLine {
                let ad = VASTAd(id: id, sequence: sequence, inLine: inLine, wrapper: nil)
                ads.append(ad)
            } else if let wrapper = currentWrapper {
                let ad = VASTAd(id: id, sequence: sequence, inLine: nil, wrapper: wrapper)
                ads.append(ad)
            }
            
            currentInLine = nil
            currentWrapper = nil
            currentAdId = nil
            currentAdSequence = nil
            
        case "InLine":
            currentInLine = VASTInLine(
                adSystem: currentAdSystem,
                adTitle: adTitle,
                impressions: impressions,
                errors: errors,
                viewableImpression: currentViewableImpression,
                creatives: creatives,
                extensions: products
            )
            currentAdSystem = nil
            currentViewableImpression = nil
            
        case "Wrapper":
            currentWrapper = VASTWrapper(
                adSystem: currentAdSystem,
                vastAdTagURI: vastAdTagURI ?? "",
                impressions: impressions,
                errors: errors,
                viewableImpression: currentViewableImpression,
                creatives: creatives
            )
            currentAdSystem = nil
            currentViewableImpression = nil
            
        case "AdSystem":
            let version = currentAttributes["version"]
            currentAdSystem = VASTAdSystem(name: content, version: version)
            
        case "AdTitle":
            adTitle = content
            
        case "Impression":
            let id = currentAttributes["id"]
            let impression = VASTImpression(id: id, url: content)
            impressions.append(impression)
            
        case "Error":
            if !content.isEmpty {
                errors.append(content)
            }
            
        case "VASTAdTagURI":
            vastAdTagURI = content
            
        case "ViewableImpression":
            let id = currentAttributes["id"]
            currentViewableImpression = VASTViewableImpression(
                id: id,
                viewable: viewable,
                notViewable: notViewable,
                viewUndetermined: viewUndetermined
            )
            
        case "Viewable":
            if !content.isEmpty {
                viewable.append(content)
            }
            
        case "NotViewable":
            if !content.isEmpty {
                notViewable.append(content)
            }
            
        case "ViewUndetermined":
            if !content.isEmpty {
                viewUndetermined.append(content)
            }
            
        case "Creative":
            let creative = VASTCreative(
                id: currentCreativeId,
                sequence: currentCreativeSequence,
                adId: currentCreativeAdId,
                linear: currentLinear
            )
            creatives.append(creative)
            currentLinear = nil
            currentCreativeId = nil
            currentCreativeSequence = nil
            currentCreativeAdId = nil
            
        case "Linear":
            let skipOffset = currentSkipOffset.flatMap { parseDuration($0) }
            
            let videoClicks = VASTVideoClicks(
                clickThrough: clickThrough,
                clickTracking: clickTracking,
                customClick: customClick
            )
            
            currentLinear = VASTLinear(
                duration: currentLinear?.duration,
                mediaFiles: mediaFiles,
                videoClicks: videoClicks,
                trackingEvents: trackingEvents,
                skipOffset: skipOffset
            )
            
        case "Duration":
            if let duration = parseDuration(content) {
                currentLinear = VASTLinear(
                    duration: duration,
                    mediaFiles: mediaFiles,
                    videoClicks: nil,
                    trackingEvents: trackingEvents,
                    skipOffset: nil
                )
            }
            
        case "MediaFile":
            let mediaFile = VASTMediaFile(
                url: content,
                delivery: currentAttributes["delivery"],
                type: currentAttributes["type"],
                width: Int(currentAttributes["width"] ?? ""),
                height: Int(currentAttributes["height"] ?? ""),
                codec: currentAttributes["codec"],
                bitrate: Int(currentAttributes["bitrate"] ?? ""),
                minBitrate: Int(currentAttributes["minBitrate"] ?? ""),
                maxBitrate: Int(currentAttributes["maxBitrate"] ?? ""),
                scalable: currentAttributes["scalable"].map { $0.lowercased() == "true" },
                maintainAspectRatio: currentAttributes["maintainAspectRatio"].map { $0.lowercased() == "true" }
            )
            mediaFiles.append(mediaFile)
            
        case "ClickThrough":
            clickThrough = content
            
        case "ClickTracking":
            if !content.isEmpty {
                clickTracking.append(content)
            }
            
        case "CustomClick":
            if !content.isEmpty {
                customClick.append(content)
            }
            
        case "Tracking":
            if let eventStr = currentAttributes["event"],
               let event = VASTTrackingEventType(rawValue: eventStr) {
                let offsetStr = currentAttributes["offset"]
                let offset = offsetStr.flatMap { parseDuration($0) }
                let tracking = VASTTrackingEvent(event: event, url: content, offset: offset)
                trackingEvents.append(tracking)
            }
            
        // MARK: Product Extension Fields
        case "AdvertiserID":
            if isParsingExtensionProduct {
                currentProductAdvertiserID = content
            }
            
        case "Brand":
            if isParsingExtensionProduct {
                currentProductBrand = content
            }
            
        case "ImageURL":
            if isParsingExtensionProduct {
                currentProductImageURL = content
            }
            
        case "Name":
            if isParsingExtensionProduct {
                currentProductName = content
            }
            
        case "PdpURL":
            if isParsingExtensionProduct {
                currentProductPdpURL = content
            }
            
        case "Price":
            if isParsingExtensionProduct {
                currentProductPrice = Double(content)
            }
            
        case "Rating":
            if isParsingExtensionProduct {
                currentProductRating = Double(content)
            }
            
        case "Sku":
            if isParsingExtensionProduct {
                currentProductSku = content
            }
            
        case "StockCount":
            if isParsingExtensionProduct {
                currentProductStockCount = Int(content)
            }
            
        case "Product":
            if isParsingExtensionProduct {
                let product = VASTProduct(
                    advertiserID: currentProductAdvertiserID,
                    brand: currentProductBrand,
                    imageURL: currentProductImageURL,
                    name: currentProductName,
                    pdpURL: currentProductPdpURL,
                    price: currentProductPrice,
                    rating: currentProductRating,
                    sku: currentProductSku,
                    stockCount: currentProductStockCount
                )
                products.append(product)
            }
            
        case "Extension":
            isParsingExtensionProduct = false
            
        default:
            break
        }
        
        elementStack.removeLast()
        currentContent = ""
        currentAttributes = [:]
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = VASTError.parsingError(parseError.localizedDescription)
    }
    
    // MARK: - Helpers
    
    /// Parse duration string in format HH:MM:SS or HH:MM:SS.mmm
    private func parseDuration(_ string: String) -> TimeInterval? {
        let components = string.components(separatedBy: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]) else { return nil }
        
        // Handle seconds with potential milliseconds
        let secondsStr = components[2]
        guard let seconds = Double(secondsStr) else { return nil }
        
        return hours * 3600 + minutes * 60 + seconds
    }
}
